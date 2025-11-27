#Requires -Version 5.1
<#
.SYNOPSIS
    Restore script for ra-infrastructure database.

.DESCRIPTION
    Restores a database backup from a .dump or .dump.gz file.
    Creates a safety backup before restoring unless skipped.

.PARAMETER BackupFile
    Path to the backup file (.dump or .dump.gz). Required.

.PARAMETER Force
    Skip confirmation prompt.

.PARAMETER SkipSafetyBackup
    Skip creating a backup of the current database before restore.

.EXAMPLE
    .\restore.ps1 -BackupFile "D:\Backups\ra-infrastructure\daily\inventory_2025-11-27.dump.gz"

.EXAMPLE
    .\restore.ps1 -BackupFile "backup.dump.gz" -Force

.EXAMPLE
    .\restore.ps1 -BackupFile "backup.dump.gz" -SkipSafetyBackup
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupFile,

    [switch]$Force,
    [switch]$SkipSafetyBackup
)

$ErrorActionPreference = "Stop"
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:LogDir = Join-Path $script:RepoRoot "logs"
$script:LogFile = Join-Path $script:LogDir "restore.log"
$script:DockerComposePath = Join-Path $script:RepoRoot "docker\docker-compose.yml"

# Database settings
$script:DbContainer = "inventory-db"
$script:DbName = "inventory"
$script:DbUser = "inventory"

# Ensure logs directory exists
if (-not (Test-Path $script:LogDir)) {
    New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
}

#region Logging Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    Add-Content -Path $script:LogFile -Value $logEntry

    $colors = @{
        "INFO"    = "Cyan"
        "SUCCESS" = "Green"
        "WARNING" = "Yellow"
        "ERROR"   = "Red"
    }

    $symbols = @{
        "INFO"    = "[*]"
        "SUCCESS" = "[+]"
        "WARNING" = "[!]"
        "ERROR"   = "[X]"
    }

    Write-Host "$($symbols[$Level]) $Message" -ForegroundColor $colors[$Level]
}

#endregion

#region Restore Functions

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." -Level INFO

    # Check backup file exists
    if (-not (Test-Path $BackupFile)) {
        Write-Log "Backup file not found: $BackupFile" -Level ERROR
        return $false
    }

    # Validate file extension
    $extension = [System.IO.Path]::GetExtension($BackupFile)
    if ($extension -notin @(".dump", ".gz")) {
        Write-Log "Invalid backup file format. Expected .dump or .dump.gz" -Level ERROR
        return $false
    }

    # Check Docker is running
    try {
        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Docker is not running" -Level ERROR
            return $false
        }
    }
    catch {
        Write-Log "Docker is not installed or not in PATH" -Level ERROR
        return $false
    }

    # Check container is running
    $state = docker inspect --format='{{.State.Running}}' $script:DbContainer 2>&1
    if ($LASTEXITCODE -ne 0 -or $state -ne "true") {
        Write-Log "Container '$script:DbContainer' is not running" -Level ERROR
        return $false
    }

    Write-Log "Prerequisites check passed" -Level SUCCESS
    return $true
}

function Get-UserConfirmation {
    if ($Force) {
        return $true
    }

    Write-Host ""
    Write-Host "WARNING: This will replace all data in the '$script:DbName' database!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Backup file: $BackupFile"
    Write-Host "Database: $script:DbName"
    Write-Host ""

    $response = Read-Host "Are you sure you want to continue? (yes/no)"

    return $response -eq "yes"
}

function New-SafetyBackup {
    if ($SkipSafetyBackup) {
        Write-Log "Skipping safety backup (SkipSafetyBackup flag set)" -Level WARNING
        return $true
    }

    Write-Log "Creating safety backup of current database..." -Level INFO

    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $safetyBackupDir = Join-Path $script:LogDir "safety-backups"
    $safetyBackupFile = Join-Path $safetyBackupDir "pre-restore_${timestamp}.dump"

    if (-not (Test-Path $safetyBackupDir)) {
        New-Item -ItemType Directory -Path $safetyBackupDir -Force | Out-Null
    }

    try {
        docker exec $script:DbContainer pg_dump -U $script:DbUser -Fc $script:DbName > $safetyBackupFile

        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $safetyBackupFile) -or (Get-Item $safetyBackupFile).Length -eq 0) {
            Write-Log "Failed to create safety backup" -Level ERROR
            return $false
        }

        $size = [math]::Round((Get-Item $safetyBackupFile).Length / 1MB, 2)
        Write-Log "Safety backup created: $safetyBackupFile ($size MB)" -Level SUCCESS

        return $true
    }
    catch {
        Write-Log "Safety backup failed: $_" -Level ERROR
        return $false
    }
}

function Expand-BackupFile {
    param([string]$FilePath)

    $extension = [System.IO.Path]::GetExtension($FilePath)

    if ($extension -eq ".dump") {
        Write-Log "Backup file is uncompressed" -Level INFO
        return $FilePath
    }

    Write-Log "Decompressing backup file..." -Level INFO

    $outputPath = [System.IO.Path]::GetTempFileName() + ".dump"

    try {
        $inputStream = [System.IO.File]::OpenRead($FilePath)
        $outputStream = [System.IO.File]::Create($outputPath)
        $gzipStream = New-Object System.IO.Compression.GZipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)

        $gzipStream.CopyTo($outputStream)

        $outputStream.Close()
        $gzipStream.Close()
        $inputStream.Close()

        $size = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
        Write-Log "Decompressed to temp file ($size MB)" -Level SUCCESS

        return $outputPath
    }
    catch {
        Write-Log "Decompression failed: $_" -Level ERROR
        return $null
    }
}

function Stop-DependentServices {
    Write-Log "Stopping dependent services..." -Level INFO

    try {
        # Stop pgAdmin (if running)
        docker stop inventory-pgadmin 2>&1 | Out-Null
        Write-Log "Stopped pgAdmin" -Level INFO
    }
    catch {
        Write-Log "pgAdmin not running or stop failed (continuing)" -Level WARNING
    }

    return $true
}

function Start-DependentServices {
    Write-Log "Starting dependent services..." -Level INFO

    try {
        docker-compose -f $script:DockerComposePath up -d 2>&1 | Out-Null
        Write-Log "Services started" -Level SUCCESS
    }
    catch {
        Write-Log "Failed to start services: $_" -Level WARNING
    }
}

function Invoke-DatabaseRestore {
    param([string]$DumpFile)

    Write-Log "Restoring database..." -Level INFO

    try {
        $startTime = Get-Date

        # Use pg_restore with clean option to drop existing objects
        Get-Content $DumpFile -Raw | docker exec -i $script:DbContainer pg_restore -U $script:DbUser -d $script:DbName -c --if-exists 2>&1

        # pg_restore may return warnings that aren't fatal
        # Check if the database is accessible
        $testResult = docker exec $script:DbContainer psql -U $script:DbUser -d $script:DbName -c "SELECT COUNT(*) FROM organizations" 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Restore may have failed - cannot query database" -Level ERROR
            return $false
        }

        $duration = ((Get-Date) - $startTime).TotalSeconds
        Write-Log "Database restored in $([math]::Round($duration, 1)) seconds" -Level SUCCESS

        return $true
    }
    catch {
        Write-Log "Restore failed: $_" -Level ERROR
        return $false
    }
}

function Test-RestoredDatabase {
    Write-Log "Verifying restored database..." -Level INFO

    try {
        # Run some basic queries to verify
        $tables = @("organizations", "sites", "zones", "devices", "networks")

        foreach ($table in $tables) {
            $count = docker exec $script:DbContainer psql -U $script:DbUser -d $script:DbName -t -c "SELECT COUNT(*) FROM $table" 2>&1

            if ($LASTEXITCODE -ne 0) {
                Write-Log "Failed to query table: $table" -Level ERROR
                return $false
            }

            $count = $count.Trim()
            Write-Log "  $table : $count records" -Level INFO
        }

        Write-Log "Database verification passed" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Verification failed: $_" -Level ERROR
        return $false
    }
}

#endregion

#region Main

function Main {
    $startTime = Get-Date

    Write-Host ""
    Write-Host "=" * 50
    Write-Host "  ra-infrastructure Database Restore"
    Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "=" * 50
    Write-Host ""

    Write-Log "=" * 50 -Level INFO
    Write-Log "Restore started" -Level INFO
    Write-Log "Backup file: $BackupFile" -Level INFO

    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        exit 1
    }

    # Get user confirmation
    if (-not (Get-UserConfirmation)) {
        Write-Log "Restore cancelled by user" -Level WARNING
        exit 0
    }

    # Create safety backup
    if (-not (New-SafetyBackup)) {
        Write-Log "Aborting restore - safety backup failed" -Level ERROR
        exit 1
    }

    # Decompress if needed
    $dumpFile = Expand-BackupFile -FilePath $BackupFile
    if (-not $dumpFile) {
        exit 1
    }

    $tempFile = $dumpFile -ne $BackupFile

    try {
        # Stop dependent services
        Stop-DependentServices

        # Perform restore
        $success = Invoke-DatabaseRestore -DumpFile $dumpFile

        if (-not $success) {
            Write-Log "RESTORE FAILED!" -Level ERROR
            Write-Log "Your original data should still be intact" -Level WARNING
            Write-Log "If needed, restore from safety backup in: logs\safety-backups\" -Level INFO
            exit 1
        }

        # Verify restoration
        Test-RestoredDatabase

        # Start services
        Start-DependentServices
    }
    finally {
        # Cleanup temp file
        if ($tempFile -and (Test-Path $dumpFile)) {
            Remove-Item $dumpFile -Force
        }
    }

    $duration = ((Get-Date) - $startTime).TotalSeconds
    Write-Log "Restore completed in $([math]::Round($duration, 1)) seconds" -Level SUCCESS

    Write-Host ""
    Write-Host "Restore completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Verify with:"
    Write-Host "  inv db stats"
    Write-Host "  inv org list"
    Write-Host ""
}

Main

#endregion
