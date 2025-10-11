<#
.SYNOPSIS
    Updates Windows Shell Folders registry to set Downloads folder to default Windows location.

.DESCRIPTION
    This script updates the Downloads folder registry entry from OneDrive location
    to the default Windows user profile location: C:\Users\{USERNAME}\Downloads

.NOTES
    Windows Explorer will be restarted to apply changes
#>

param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

# Get current user
$username = $env:USERNAME
$defaultDownloads = "C:\Users\$username\Downloads"

# Registry paths
$shellFoldersPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
$userShellFoldersPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"

Write-ColorOutput "`nUpdating Downloads Folder Registry Settings" "Cyan"
Write-ColorOutput "============================================`n" "Cyan"

# Check current values
Write-ColorOutput "Current registry values:" "Yellow"
try {
    $currentShellFolder = Get-ItemProperty -Path $shellFoldersPath -Name "{374DE290-123F-4565-9164-39C4925E467B}" -ErrorAction SilentlyContinue
    $currentUserShellFolder = Get-ItemProperty -Path $userShellFoldersPath -Name "{374DE290-123F-4565-9164-39C4925E467B}" -ErrorAction SilentlyContinue

    Write-Host "  Shell Folders: $($currentShellFolder.'{374DE290-123F-4565-9164-39C4925E467B}')"
    Write-Host "  User Shell Folders: $($currentUserShellFolder.'{374DE290-123F-4565-9164-39C4925E467B}')"
} catch {
    Write-ColorOutput "  Unable to read current values" "Red"
}

Write-ColorOutput "`nNew value:" "Yellow"
Write-Host "  $defaultDownloads`n"

if ($WhatIf) {
    Write-ColorOutput "WhatIf: Would update registry entries" "Yellow"
    exit 0
}

# Create Downloads folder if it doesn't exist
if (-not (Test-Path $defaultDownloads)) {
    Write-ColorOutput "Creating Downloads folder: $defaultDownloads" "Green"
    try {
        New-Item -Path $defaultDownloads -ItemType Directory -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-ColorOutput "Note: Could not create folder (it will be created automatically): $_" "Yellow"
    }
}

# Update registry
try {
    Write-ColorOutput "Updating registry..." "Green"

    # Update Shell Folders
    Set-ItemProperty -Path $shellFoldersPath -Name "{374DE290-123F-4565-9164-39C4925E467B}" -Value $defaultDownloads

    # Update User Shell Folders
    Set-ItemProperty -Path $userShellFoldersPath -Name "{374DE290-123F-4565-9164-39C4925E467B}" -Value $defaultDownloads

    Write-ColorOutput "Registry updated successfully" "Green"

    # Restart Explorer to apply changes
    Write-ColorOutput "`nRestarting Windows Explorer..." "Yellow"
    Stop-Process -Name explorer -Force
    Start-Sleep -Seconds 2
    Start-Process explorer

    Write-ColorOutput "`nDownloads folder successfully updated to: $defaultDownloads" "Green"
    Write-ColorOutput "Please verify the change in File Explorer" "Cyan"

} catch {
    Write-ColorOutput "Error updating registry: $_" "Red"
    exit 1
}
