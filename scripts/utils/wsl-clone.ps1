<#
.SYNOPSIS
    Clones a WSL instance from the base Debian distribution with automatic git backup.

.PARAMETER NewInstance
    Name for the new WSL instance.

.PARAMETER InstallBasePath
    Base path where the instance will be installed.

.PARAMETER BackupDir
    WSL path where backups will be stored.

.PARAMETER SourceDir
    WSL path to backup (git repos).

.PARAMETER User
    WSL user to run commands as and set up cron for (default: root).

.PARAMETER BackupIntervalMinutes
    Backup cron interval in minutes (default: 10).

.PARAMETER Force
    Unregister existing instance without prompting.

.EXAMPLE
    .\wsl-clone.ps1 -NewInstance "agentic" `
        -InstallBasePath "D:\wsl\instances" -BackupDir "/mnt/d/wsl/backups" `
        -SourceDir '$HOME/code'

.EXAMPLE
    # Run directly from GitHub:
    $params = @{
        NewInstance     = "agentic"
        InstallBasePath = "D:\wsl\instances"
        BackupDir       = "/mnt/d/wsl/backups"
        SourceDir       = '/home/devuser/code'
        User            = "devuser"
    }
    $url = "https://raw.githubusercontent.com/devdnn/mystarters/main/scripts/utils/wsl-clone.ps1"
    & ([scriptblock]::Create((Invoke-WebRequest -Uri $url -UseBasicParsing).Content)) @params
#>

param(
    [Parameter(Mandatory)][string]$NewInstance,
    [Parameter(Mandatory)][string]$InstallBasePath,
    [Parameter(Mandatory)][string]$BackupDir,
    [Parameter(Mandatory)][string]$SourceDir,
    [string]$User = "root",
    [int]$BackupIntervalMinutes = 10,
    [switch]$Force,
    [switch]$UseSudo
)

$ErrorActionPreference = 'Stop'

function Get-EscapedBashArg {
    param([string]$Arg)
    return $Arg -replace "'", "'\\''"
}

function Test-ValidUsername {
    param([string]$Username)
    return $Username -match '^[a-z_][a-z0-9_-]*[$]?$'
}

$InstallPath = Join-Path $InstallBasePath $NewInstance

if (-not (Test-ValidUsername $User)) {
    throw "Invalid username '$User'. Must match pattern ^[a-z_][a-z0-9_-]*[$]?$"
}

if ($NewInstance -notmatch '^[a-zA-Z0-9_-]+$') {
    throw "Invalid instance name '$NewInstance'. Must contain only alphanumeric characters, hyphens, and underscores."
}

$safeUser = Get-EscapedBashArg $User
$safeSourceDir = Get-EscapedBashArg $SourceDir
$safeBackupDir = Get-EscapedBashArg $BackupDir

# Default UseSudo to true when running as a non-root user
if (-not $PSBoundParameters.ContainsKey('UseSudo')) {
    $UseSudo = $User -ne "root"
}

# Get list of existing distributions (handling potential null-byte or encoding issues)
$distros = wsl --list --quiet 2>$null | ForEach-Object { $_.Trim().Replace("`0", "") } | Where-Object { $_ -ne "" }

# Ensure Debian is installed
$debianInstalled = $distros | Where-Object { $_ -ieq "Debian" }
if (-not $debianInstalled) {
    Write-Host "Debian distribution is not installed in WSL. Installing it now..." -ForegroundColor Yellow
    wsl --install -d Debian

    # Refresh list and verify
    Start-Sleep -Seconds 5
    $distros = wsl --list --quiet 2>$null | ForEach-Object { $_.Trim().Replace("`0", "") } | Where-Object { $_ -ne "" }
    $debianInstalled = $distros | Where-Object { $_ -ieq "Debian" }
    if (-not $debianInstalled) {
        throw "Failed to install Debian distribution. Please install manually: wsl --install -d Debian"
    }
}

# Validate InstallBasePath is writable
try {
    $testFile = Join-Path $InstallPath ".write_test"
    New-Item -ItemType File -Path $testFile -Force | Out-Null
    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
} catch {
    throw "Cannot write to InstallBasePath '$InstallBasePath': $_"
}

# Create install directory
New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

# Handle existing instance
$existing = $distros | Where-Object { $_ -ieq $NewInstance }
if ($existing) {
    if (-not $Force) {
        $confirm = Read-Host "Instance '$NewInstance' exists. Unregister? (y/N)"
        if ($confirm -notmatch '^[yY]$') { throw "Cancelled" }
    }
    Write-Host "Unregistering existing instance..." -ForegroundColor Yellow
    wsl --unregister $NewInstance
    if ($LASTEXITCODE -ne 0) { throw "Failed to unregister instance '$NewInstance'" }
}

# Export base Debian to a temporary tar file
$tempTar = Join-Path $env:TEMP "$([Guid]::NewGuid().ToString()).tar"
Write-Host "Exporting base Debian instance to temporary tarball..." -ForegroundColor Cyan
wsl --export Debian $tempTar
if ($LASTEXITCODE -ne 0) {
    Remove-Item $tempTar -ErrorAction SilentlyContinue
    throw "Failed to export base Debian instance"
}

# Import WSL instance from the temporary tarball
Write-Host "Importing WSL instance '$NewInstance'..." -ForegroundColor Cyan
wsl --import $NewInstance $InstallPath $tempTar --version 2
$importStatus = $LASTEXITCODE
Remove-Item $tempTar -ErrorAction SilentlyContinue
if ($importStatus -ne 0) { throw "Failed to import WSL instance" }

# Ensure required packages (sudo, git, cron) are installed
Write-Host "Ensuring sudo, git, and cron are installed in '$NewInstance'..." -ForegroundColor Cyan
wsl -d $NewInstance -u root -- bash -c "apt-get update && apt-get install -y sudo git cron"
if ($LASTEXITCODE -ne 0) { throw "Failed to install required packages (sudo, git, cron)" }

# Handle user configuration
if ($User -ne "root") {
    Write-Host "Checking if user '$User' exists in the instance..." -ForegroundColor Cyan
    $userExists = wsl -d $NewInstance -u root -- bash -c "id -u '$safeUser'" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $userExists) {
        Write-Host "User '$User' does not exist. Creating user..." -ForegroundColor Cyan
        wsl -d $NewInstance -u root -- bash -c "useradd -m -s /bin/bash '$safeUser' && usermod -aG sudo '$safeUser'"
        if ($LASTEXITCODE -ne 0) { throw "Failed to create user '$User'" }

        # Prompt for password (hidden input) and set it for the new user
        Write-Host "Enter password for user '$User':" -ForegroundColor Yellow
        $securePassword = Read-Host -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

        Write-Host "Setting password..." -ForegroundColor Cyan
        $encryptedPassword = $plainPassword | openssl passwd -stdin
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($encryptedPassword)) {
            $plainPassword = $null
            throw "Failed to encrypt password"
        }
        wsl -d $NewInstance -u root -- bash -c "echo '$safeUser:$encryptedPassword' | chpasswd -e"
        $plainPassword = $null
        if ($LASTEXITCODE -ne 0) { throw "Failed to set password for user '$User'" }

        # Configure sudo for automated setup - restrict to specific commands needed by install-tools.sh
        # install-tools.sh needs: apt-get, curl, git, brew, npm, bash (for nvm)
        $sudoersLine = "$User ALL=(ALL) NOPASSWD:/usr/bin/apt-get,/usr/bin/curl,/usr/bin/git,/usr/bin/bash,/usr/bin/sh"
        wsl -d $NewInstance -u root -- bash -c "echo '$($sudoersLine -replace '\$','\\\$')' > /etc/sudoers.d/$safeUser && chmod 0440 /etc/sudoers.d/$safeUser"
        if ($LASTEXITCODE -ne 0) { throw "Failed to configure sudo for user '$User'" }
    }
}

# Get user's home directory
$userHome = if ($User -eq "root") { "/root" } else { "/home/$User" }
$safeUserHome = Get-EscapedBashArg $userHome

# Create /etc/wsl.conf to set default user, preferences, and enable systemd
Write-Host "Configuring WSL instance..." -ForegroundColor Cyan
$wslConfContent = @"
[user]
default=$User

[interop]
appendWindowsPath=false

[automount]
enabled=true
options="metadata"

[boot]
systemd=true
"@

$wslConfTemp = [IO.Path]::GetTempFileName()
$wslConfContent | Set-Content $wslConfTemp -NoNewline -Encoding UTF8
$wslConfWslPath = (wsl wslpath -u $wslConfTemp).Trim()
wsl -d $NewInstance -u root -- bash -c "cp '$wslConfWslPath' /etc/wsl.conf && chmod 0644 /etc/wsl.conf"
Remove-Item $wslConfTemp -Force -ErrorAction SilentlyContinue
if ($LASTEXITCODE -ne 0) { throw "Failed to configure wsl.conf" }

# Create workspace
Write-Host "Creating workspace..." -ForegroundColor Cyan
wsl -d $NewInstance -u $User -- bash -c "mkdir -p '$safeSourceDir'"

# Copy and run install-tools.sh
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$installToolsSrc = Join-Path $scriptDir "install-tools.sh"
if (Test-Path $installToolsSrc) {
    Write-Host "Installing development tools (nvm, Node, npm packages, PowerShell, zsh)..." -ForegroundColor Cyan
    $tempFile = [IO.Path]::GetTempFileName()
    Copy-Item $installToolsSrc $tempFile -Force
    $wslTemp = (wsl wslpath -u $tempFile).Trim()
    $safeWslTemp = Get-EscapedBashArg $wslTemp
    $safeInstallToolsDest = Get-EscapedBashArg "$userHome/install-tools.sh"
    wsl -d $NewInstance -u $User -- bash -c "cp '$safeWslTemp' '$safeInstallToolsDest' && chmod +x '$safeInstallToolsDest'"
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -ne 0) { throw "Failed to copy install-tools.sh" }

    $oldErrorPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    Write-Host "Running install-tools.sh (this may take a few minutes)..." -ForegroundColor Cyan
    $sudoFlag = if ($UseSudo) { "1" } else { "0" }
    $installOutput = wsl -d $NewInstance -u $User -- bash -c "USE_SUDO='$sudoFlag' '$safeInstallToolsDest'" 2>&1
    $installExitCode = $LASTEXITCODE
    $ErrorActionPreference = $oldErrorPref

    if ($installExitCode -ne 0) {
        Write-Host "WARNING: install-tools.sh exited with code $installExitCode" -ForegroundColor Yellow
        Write-Host $installOutput -ForegroundColor Yellow
    } else {
        Write-Host "Tool installation complete." -ForegroundColor Green
    }
} else {
    Write-Host "Skipping tool installation: install-tools.sh not found at '$installToolsSrc'" -ForegroundColor Yellow
}

# Create and install backup script
$backupScript = @"
#!/bin/bash
BACKUP_DIR='$safeBackupDir'
SRC_DIR='$safeSourceDir'
mkdir -p "`$BACKUP_DIR"
for repo in "`$SRC_DIR"/*; do
    [ -d "`$repo/.git" ] && git -C "`$repo" bundle create "`$BACKUP_DIR/`$(basename `$repo).bundle" --all 2>/dev/null
done
"@

Write-Host "Installing backup script..." -ForegroundColor Cyan
$tempFile = [IO.Path]::GetTempFileName()
$backupScript | Set-Content $tempFile -NoNewline -Encoding UTF8
$wslTemp = (wsl wslpath -u $tempFile).Trim()
$safeWslTemp = Get-EscapedBashArg $wslTemp
$safeBackupScriptDest = Get-EscapedBashArg "$userHome/backup_repos.sh"
wsl -d $NewInstance -u $User -- bash -c "cp '$safeWslTemp' '$safeBackupScriptDest' && chmod +x '$safeBackupScriptDest'"
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
if ($LASTEXITCODE -ne 0) { throw "Failed to install backup script" }

# Configure cron
Write-Host "Configuring cron job for user '$User'..." -ForegroundColor Cyan
$cronEntry = "*/$BackupIntervalMinutes * * * * $safeUserHome/backup_repos.sh"
$safeCronEntry = Get-EscapedBashArg $cronEntry
wsl -d $NewInstance -u $User -- bash -c "(crontab -l 2>/dev/null | grep -v backup_repos.sh; echo '$safeCronEntry') | crontab -"
if ($LASTEXITCODE -ne 0) { throw "Failed to configure cron job" }

# Done
Write-Host "`nSetup complete!" -ForegroundColor Green
Write-Host "  Instance:  $NewInstance"
Write-Host "  User:      $User"
Write-Host "  Workspace: $SourceDir"
Write-Host "  Backups:   $BackupDir (every $BackupIntervalMinutes min)"
Write-Host "`nStart with: wsl -d $NewInstance --cd ~" -ForegroundColor Cyan
