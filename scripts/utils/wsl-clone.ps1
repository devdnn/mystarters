<#
.SYNOPSIS
Clones a WSL instance from an exported tarball.

.DESCRIPTION
This script imports a new WSL instance from a specified tarball, sets up a workspace,
installs a backup script, and configures a cron job for automatic bac
.PARAMETER NewInstance
The desired name for the new WSL instance.

.PARAMETER ExportPath
Path to the exported WSL tarball.

.PARAMETER InstallBasePath
Base path where the new instance will be installed.

.PARAMETER BackupDir
Directory inside WSL (or mounted Windows path) where backups will be stored.

.PARAMETER SourceDir
Directory inside WSL to backup.

.USAGE
# Copy# Copy and paste this block into PowerShell to run the script:
ptUrl = "https://raw.githubusercontent.com/devdnn/mystarters/main/scripts/utils/wsl-clone.ps1" # Replace with actual raw URL if different

Invoke-Expression (Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing).Content `
    -NewInstance "sample" `
    -ExportPath "D:\Dev\wsl\exports\debian-basic.tar" `
    -InstallBasePath "D:\Dev\wsl\current" `
    -BackupDir "/mnt/d/Dev/wsl/wsl-git-backups" `
    -SourceDir '$HOME/wrkspc/_code'
#>
param(
    [s    [Parameter(Mandatory=$true)]
    [string]$NewInstance,

    [Parameter(Mandatory=$true)]
    [string]$ExportPath,

    [Parameter(Mandatory=$true)]
    [string]$InstallBasePath,

    [Parameter(Mandatory=$true)]
    [string]$BackupDir,

    [Parameter(Mandatory=$true)]
    [string]$SourceDir
ariables
$InstallPath    = Join-Path -Path $InstallBasePath -ChildPath $NewInstance
$BackupScript   = @"
#!/bin/bash
BACKUP_DIR="$BackupDir"
SRC_DIR="$SourceDir"

mkdir -p "`$BACKUP_DIR"

for repo in "`$SRC_DIR"/*; do
  if [ -d "`$repo/.git" ]; then
    reponame=`$(basename "`$repo")
    git -C "`$repo" bundle create "`$BACKUP_DIR/`$reponame.bundle" --all
  fi
done
"@

# 1. Import new WSL instance from exported tarball
Write-Host "Importing WSL instance '$NewInstance'..."
if (wsl --list --quiet | Select-String -Pattern "^$NewInstance$") {
    Write-Host "Instance '$NewInstance' already exists. Unregistering..."
    wsl --unregister $NewInstance 2>$null
}
wsl --import $NewInstance $InstallPath $ExportPath --version 2

# 2. Create workspace folder inside WSL
Write-Host "Creating workspace folder..."
wsl -d $NewInstance -- bash -c "mkdir -p $SourceDir"

# 3. Drop backup script into WSL
Write-Host "Installing backup script..."
# Note: This uses echo inside bash. Ensure $BackupScript does not contain unescaped single quotes.
wsl -d $NewInstance -- bash -c "echo '$BackupScript' > ~/backup_repos.sh && chmod +x ~/backup_repos.sh"

# 4. Add cron job inside WSL (every 10 minutes)
Write-Host "Configuring cron job..."
wsl -d $NewInstance -- bash -c "(crontab -l 2>/dev/null; echo '*/10 * * * * \$HOME/backup_repos.sh') | crontab -"

Write-Host "Setup complete! Your WSL clone is ready with auto-backup cron."
Setup complete! Your WSL clone is ready with auto-backup cron."