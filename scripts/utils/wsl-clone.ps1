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
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$InstallPath = Join-Path $InstallBasePath $NewInstance

# Get list of existing distributions (handling potential null-byte or encoding issues)
$distros = wsl --list --quiet 2>$null | ForEach-Object { $_.Trim().Replace("`0", "") } | Where-Object { $_ -ne "" }

# Ensure Debian is installed
$debianInstalled = $distros | Where-Object { $_ -ieq "Debian" }
if (-not $debianInstalled) {
    Write-Host "Debian distribution is not installed in WSL. Installing it now..." -ForegroundColor Yellow
    wsl --install -d Debian
    
    # Refresh list and verify
    $distros = wsl --list --quiet 2>$null | ForEach-Object { $_.Trim().Replace("`0", "") } | Where-Object { $_ -ne "" }
    $debianInstalled = $distros | Where-Object { $_ -ieq "Debian" }
    if (-not $debianInstalled) {
        throw "Failed to install Debian distribution. Please install it manually using 'wsl --install -d Debian' and try again."
    }
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
    wsl --unregister $NewInstance | Out-Null
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
if ($LASTEXITCODE -ne 0) { throw "Failed to install required packages (sudo, git, cron) in the new instance" }

# Handle user configuration
if ($User -ne "root") {
    Write-Host "Checking if user '$User' exists in the instance..." -ForegroundColor Cyan
    $userExists = wsl -d $NewInstance -u root -- bash -c "id -u $User" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $userExists) {
        Write-Host "User '$User' does not exist. Creating user and configuring passwordless sudo..." -ForegroundColor Cyan
        wsl -d $NewInstance -u root -- bash -c "useradd -m -s /bin/bash $User && usermod -aG sudo $User"
        if ($LASTEXITCODE -ne 0) { throw "Failed to create user '$User'" }
        
        $sudoersLine = "$User ALL=(ALL) NOPASSWD:ALL"
        wsl -d $NewInstance -u root -- bash -c "echo '$sudoersLine' > /etc/sudoers.d/$User && chmod 0440 /etc/sudoers.d/$User"
        if ($LASTEXITCODE -ne 0) { throw "Failed to configure sudo for user '$User'" }
    }
}

# Get user's home directory
$userHome = if ($User -eq "root") { "/root" } else { "/home/$User" }

# Create /etc/wsl.conf to set default user, preferences, and enable systemd
Write-Host "Configuring WSL instance..." -ForegroundColor Cyan
$wslConf = @"
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
wsl -d $NewInstance -u root -- bash -c "cat > /etc/wsl.conf << 'EOF'
$wslConf
EOF"

# Create workspace
Write-Host "Creating workspace..." -ForegroundColor Cyan
wsl -d $NewInstance -u $User -- bash -c "mkdir -p '$SourceDir'"

# Copy and run install-tools.sh
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$installToolsSrc = Join-Path $scriptDir "install-tools.sh"
if (Test-Path $installToolsSrc) {
    Write-Host "Installing development tools (nvm, Node, npm packages, PowerShell, zsh)..." -ForegroundColor Cyan
    $tempFile = [IO.Path]::GetTempFileName()
    Copy-Item $installToolsSrc $tempFile -Force
    $wslTemp = (wsl wslpath -u "'$tempFile'").Trim()
    wsl -d $NewInstance -u $User -- bash -c "cp $wslTemp $userHome/install-tools.sh && chmod +x $userHome/install-tools.sh"
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    $oldErrorPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    Write-Host "Running install-tools.sh (this may take a few minutes)..." -ForegroundColor Cyan
    wsl -d $NewInstance -u $User -- bash -c "$userHome/install-tools.sh"
    $ErrorActionPreference = $oldErrorPref
    Write-Host "Tool installation complete." -ForegroundColor Green
} else {
    Write-Host "Skipping tool installation: install-tools.sh not found at '$installToolsSrc'" -ForegroundColor Yellow
}

# Create and install backup script
$backupScript = @"
#!/bin/bash
BACKUP_DIR="$BackupDir"
SRC_DIR="$SourceDir"
mkdir -p "`$BACKUP_DIR"
for repo in "`$SRC_DIR"/*; do
    [ -d "`$repo/.git" ] && git -C "`$repo" bundle create "`$BACKUP_DIR/`$(basename `$repo).bundle" --all 2>/dev/null
done
"@

Write-Host "Installing backup script..." -ForegroundColor Cyan
$tempFile = [IO.Path]::GetTempFileName()
$backupScript | Set-Content $tempFile -NoNewline
$wslTemp = (wsl wslpath -u "'$tempFile'").Trim()
wsl -d $NewInstance -u $User -- bash -c "cp $wslTemp $userHome/backup_repos.sh && chmod +x $userHome/backup_repos.sh"
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

# Configure cron
Write-Host "Configuring cron job for user '$User'..." -ForegroundColor Cyan
$cronCmd = "(crontab -l 2>/dev/null | grep -v backup_repos.sh; echo '*/$BackupIntervalMinutes * * * * $userHome/backup_repos.sh') | crontab -"
wsl -d $NewInstance -u $User -- bash -c $cronCmd

# Done
Write-Host "`nSetup complete!" -ForegroundColor Green
Write-Host "  Instance:  $NewInstance"
Write-Host "  User:      $User"
Write-Host "  Workspace: $SourceDir"
Write-Host "  Backups:   $BackupDir (every $BackupIntervalMinutes min)"
Write-Host "`nStart with: wsl -d $NewInstance --cd ~" -ForegroundColor Cyan
