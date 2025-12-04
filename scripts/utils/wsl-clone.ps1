<#
.SYNOPSIS
    Clones a WSL instance from an exported tarball with automatic git backup.

.PARAMETER NewInstance
    Name for the new WSL instance.

.PARAMETER ExportPath
    Path to the exported WSL tarball.

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
    .\wsl-clone.ps1 -NewInstance "agentic" -ExportPath "D:\wsl\debian.tar" `
        -InstallBasePath "D:\wsl\instances" -BackupDir "/mnt/d/wsl/backups" `
        -SourceDir '$HOME/code'

.EXAMPLE
    # Run directly from GitHub:
    $params = @{
        NewInstance     = "agentic"
        ExportPath      = "D:\wsl\exports\debian-basic.tar"
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
    [Parameter(Mandatory)][string]$ExportPath,
    [Parameter(Mandatory)][string]$InstallBasePath,
    [Parameter(Mandatory)][string]$BackupDir,
    [Parameter(Mandatory)][string]$SourceDir,
    [string]$User = "root",
    [int]$BackupIntervalMinutes = 10,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$InstallPath = Join-Path $InstallBasePath $NewInstance

# Validate export file exists
if (-not (Test-Path $ExportPath)) {
    throw "Export file not found: $ExportPath"
}

# Create install directory
New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

# Handle existing instance
$existing = wsl --list --quiet 2>$null | Where-Object { $_ -eq $NewInstance }
if ($existing) {
    if (-not $Force) {
        $confirm = Read-Host "Instance '$NewInstance' exists. Unregister? (y/N)"
        if ($confirm -notmatch '^[yY]$') { throw "Cancelled" }
    }
    Write-Host "Unregistering existing instance..." -ForegroundColor Yellow
    wsl --unregister $NewInstance | Out-Null
}

# Import WSL instance
Write-Host "Importing WSL instance '$NewInstance'..." -ForegroundColor Cyan
wsl --import $NewInstance $InstallPath $ExportPath --version 2
if ($LASTEXITCODE -ne 0) { throw "Failed to import WSL instance" }

# Set default user for the instance
if ($User -ne "root") {
    Write-Host "Setting default user to '$User'..." -ForegroundColor Cyan
    # Create /etc/wsl.conf to set default user
    $wslConf = "[user]`ndefault=$User"
    wsl -d $NewInstance -- bash -c "echo -e '$wslConf' > /etc/wsl.conf"
}

# Get user's home directory
$userHome = if ($User -eq "root") { "/root" } else { "/home/$User" }

# Create workspace
Write-Host "Creating workspace..." -ForegroundColor Cyan
wsl -d $NewInstance -u $User -- bash -c "mkdir -p '$SourceDir'"

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
Write-Host "`nStart with: wsl -d $NewInstance" -ForegroundColor Cyan
