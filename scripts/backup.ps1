#Requires -Version 5.1
<#
.SYNOPSIS
    Backup script for ra-infrastructure database.

.DESCRIPTION
    Creates database backups with local storage and optional Google Drive upload.
    - Daily backups: Local storage with 7-day retention
    - Weekly backups: Uploads to Google Drive with 4-week retention

.PARAMETER Type
    Backup type: 'daily' or 'weekly'. Required.

.PARAMETER Verify
    Run integrity check after backup by restoring to temp database.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER BackupDir
    Override default backup directory (D:\Backups\ra-infrastructure).

.EXAMPLE
    .\backup.ps1 -Type daily

.EXAMPLE
    .\backup.ps1 -Type daily -Verify

.EXAMPLE
    .\backup.ps1 -Type weekly
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("daily", "weekly")]
    [string]$Type,

    [switch]$Verify,
    [switch]$Force,

    [string]$BackupDir = "D:\Backups\ra-infrastructure"
)

$ErrorActionPreference = "Stop"
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:LogDir = Join-Path $script:RepoRoot "logs"
$script:LogFile = Join-Path $script:LogDir "backup.log"
$script:ConfigFile = Join-Path $script:RepoRoot "config\monitoring.env"

# Database settings
$script:DbContainer = "inventory-db"
$script:DbName = "inventory"
$script:DbUser = "inventory"

# Retention settings
$script:DailyRetentionDays = 7
$script:WeeklyRetentionWeeks = 4

# rclone settings
$script:RcloneRemote = "gdrive"
$script:RcloneRemotePath = "ra-infrastructure-backup"

# Ensure directories exist
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

#region Email Functions

function Get-EmailConfig {
    if (-not (Test-Path $script:ConfigFile)) {
        return $null
    }

    $config = @{}
    Get-Content $script:ConfigFile | ForEach-Object {
        if ($_ -match "^([^#=]+)=(.*)$") {
            $config[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }

    return $config
}

function Send-BackupAlert {
    param(
        [string]$Subject,
        [string]$Body
    )

    $config = Get-EmailConfig
    if (-not $config) {
        Write-Log "Cannot send email - no config file" -Level WARNING
        return
    }

    try {
        $smtpServer = $config.SMTP_HOST
        $smtpPort = [int]$config.SMTP_PORT
        $smtpUser = $config.SMTP_USER
        $smtpPassword = $config.SMTP_PASSWORD
        $alertEmail = $config.ALERT_EMAIL

        if (-not ($smtpServer -and $smtpUser -and $smtpPassword -and $alertEmail)) {
            Write-Log "Incomplete email configuration" -Level WARNING
            return
        }

        $securePassword = ConvertTo-SecureString $smtpPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($smtpUser, $securePassword)

        $mailParams = @{
            From       = $smtpUser
            To         = $alertEmail
            Subject    = $subject
            Body       = $body
            SmtpServer = $smtpServer
            Port       = $smtpPort
            UseSsl     = $true
            Credential = $credential
        }

        Send-MailMessage @mailParams
        Write-Log "Alert email sent" -Level SUCCESS
    }
    catch {
        Write-Log "Failed to send email: $_" -Level ERROR
    }
}

#endregion

#region Backup Functions

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." -Level INFO

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

    # Check backup directory
    if (-not (Test-Path $BackupDir)) {
        Write-Log "Creating backup directory: $BackupDir" -Level INFO
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }

    $dailyDir = Join-Path $BackupDir "daily"
    if (-not (Test-Path $dailyDir)) {
        New-Item -ItemType Directory -Path $dailyDir -Force | Out-Null
    }

    # For weekly, check rclone
    if ($Type -eq "weekly") {
        try {
            $rcloneVersion = rclone version 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "rclone is not installed" -Level ERROR
                return $false
            }

            # Check if remote is configured
            $remotes = rclone listremotes 2>&1
            if ($remotes -notlike "*${script:RcloneRemote}:*") {
                Write-Log "rclone remote '$script:RcloneRemote' not configured" -Level ERROR
                Write-Log "Run 'rclone config' to set up Google Drive" -Level INFO
                return $false
            }
        }
        catch {
            Write-Log "rclone check failed: $_" -Level ERROR
            return $false
        }
    }

    Write-Log "Prerequisites check passed" -Level SUCCESS
    return $true
}

function New-DatabaseBackup {
    $date = Get-Date -Format "yyyy-MM-dd"
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $dailyDir = Join-Path $BackupDir "daily"
    $backupFile = Join-Path $dailyDir "${script:DbName}_${date}.dump"
    $compressedFile = "${backupFile}.gz"

    Write-Log "Creating database backup..." -Level INFO
    Write-Log "Output: $compressedFile" -Level INFO

    try {
        # Create pg_dump
        $startTime = Get-Date

        # Use pg_dump with custom format
        docker exec $script:DbContainer pg_dump -U $script:DbUser -Fc $script:DbName > $backupFile

        if ($LASTEXITCODE -ne 0) {
            Write-Log "pg_dump failed" -Level ERROR
            return $null
        }

        # Check file was created and has content
        if (-not (Test-Path $backupFile) -or (Get-Item $backupFile).Length -eq 0) {
            Write-Log "Backup file is empty or not created" -Level ERROR
            return $null
        }

        $dumpSize = (Get-Item $backupFile).Length
        Write-Log "Dump created: $([math]::Round($dumpSize / 1MB, 2)) MB" -Level INFO

        # Compress with PowerShell (gzip alternative)
        Write-Log "Compressing backup..." -Level INFO

        # Use .NET compression
        $inputStream = [System.IO.File]::OpenRead($backupFile)
        $outputStream = [System.IO.File]::Create($compressedFile)
        $gzipStream = New-Object System.IO.Compression.GZipStream($outputStream, [System.IO.Compression.CompressionMode]::Compress)

        $inputStream.CopyTo($gzipStream)

        $gzipStream.Close()
        $outputStream.Close()
        $inputStream.Close()

        # Remove uncompressed file
        Remove-Item $backupFile -Force

        $compressedSize = (Get-Item $compressedFile).Length
        $duration = ((Get-Date) - $startTime).TotalSeconds

        Write-Log "Backup completed in $([math]::Round($duration, 1)) seconds" -Level SUCCESS
        Write-Log "Compressed size: $([math]::Round($compressedSize / 1MB, 2)) MB" -Level INFO

        return $compressedFile
    }
    catch {
        Write-Log "Backup failed: $_" -Level ERROR

        # Cleanup partial files
        if (Test-Path $backupFile) { Remove-Item $backupFile -Force }
        if (Test-Path $compressedFile) { Remove-Item $compressedFile -Force }

        return $null
    }
}

function Test-BackupIntegrity {
    param([string]$BackupFile)

    if (-not $Verify) {
        return $true
    }

    Write-Log "Verifying backup integrity..." -Level INFO

    $tempDb = "verify_backup_temp"

    try {
        # Decompress to temp file
        $tempDump = [System.IO.Path]::GetTempFileName()

        $inputStream = [System.IO.File]::OpenRead($BackupFile)
        $outputStream = [System.IO.File]::Create($tempDump)
        $gzipStream = New-Object System.IO.Compression.GZipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)

        $gzipStream.CopyTo($outputStream)

        $outputStream.Close()
        $gzipStream.Close()
        $inputStream.Close()

        # Create temp database
        docker exec $script:DbContainer psql -U $script:DbUser -d postgres -c "DROP DATABASE IF EXISTS $tempDb" 2>&1 | Out-Null
        docker exec $script:DbContainer psql -U $script:DbUser -d postgres -c "CREATE DATABASE $tempDb" 2>&1 | Out-Null

        # Restore to temp database
        Get-Content $tempDump -Raw | docker exec -i $script:DbContainer pg_restore -U $script:DbUser -d $tempDb 2>&1 | Out-Null

        # Verify by running a query
        $result = docker exec $script:DbContainer psql -U $script:DbUser -d $tempDb -c "SELECT COUNT(*) FROM organizations" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Backup verification passed" -Level SUCCESS
            $verified = $true
        }
        else {
            Write-Log "Backup verification failed - could not query restored data" -Level ERROR
            $verified = $false
        }

        # Cleanup
        docker exec $script:DbContainer psql -U $script:DbUser -d postgres -c "DROP DATABASE IF EXISTS $tempDb" 2>&1 | Out-Null
        Remove-Item $tempDump -Force

        return $verified
    }
    catch {
        Write-Log "Verification failed: $_" -Level ERROR

        # Cleanup on error
        docker exec $script:DbContainer psql -U $script:DbUser -d postgres -c "DROP DATABASE IF EXISTS $tempDb" 2>&1 | Out-Null
        if (Test-Path $tempDump) { Remove-Item $tempDump -Force }

        return $false
    }
}

function Remove-OldLocalBackups {
    Write-Log "Cleaning up old local backups (retention: $script:DailyRetentionDays days)..." -Level INFO

    $dailyDir = Join-Path $BackupDir "daily"
    $cutoffDate = (Get-Date).AddDays(-$script:DailyRetentionDays)

    $oldFiles = Get-ChildItem -Path $dailyDir -Filter "*.dump.gz" |
    Where-Object { $_.LastWriteTime -lt $cutoffDate }

    if ($oldFiles) {
        foreach ($file in $oldFiles) {
            Write-Log "Removing: $($file.Name)" -Level INFO
            Remove-Item $file.FullName -Force
        }
        Write-Log "Removed $($oldFiles.Count) old backup(s)" -Level SUCCESS
    }
    else {
        Write-Log "No old backups to remove" -Level INFO
    }
}

function Send-ToGoogleDrive {
    param([string]$BackupFile)

    Write-Log "Uploading to Google Drive..." -Level INFO

    $fileName = Split-Path $BackupFile -Leaf
    $weeklyName = $fileName -replace "\.dump\.gz$", "_weekly.dump.gz"
    $remotePath = "${script:RcloneRemote}:${script:RcloneRemotePath}/$weeklyName"

    try {
        $startTime = Get-Date

        rclone copy $BackupFile "${script:RcloneRemote}:${script:RcloneRemotePath}/" --progress 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Log "rclone upload failed" -Level ERROR
            return $false
        }

        # Rename to weekly
        rclone moveto "${script:RcloneRemote}:${script:RcloneRemotePath}/$fileName" $remotePath 2>&1

        $duration = ((Get-Date) - $startTime).TotalSeconds
        Write-Log "Upload completed in $([math]::Round($duration, 1)) seconds" -Level SUCCESS

        return $true
    }
    catch {
        Write-Log "Upload failed: $_" -Level ERROR
        return $false
    }
}

function Remove-OldRemoteBackups {
    Write-Log "Cleaning up old remote backups (retention: $script:WeeklyRetentionWeeks weeks)..." -Level INFO

    try {
        $cutoffDate = (Get-Date).AddDays(-($script:WeeklyRetentionWeeks * 7))

        # List remote files
        $remoteFiles = rclone lsjson "${script:RcloneRemote}:${script:RcloneRemotePath}/" 2>&1 | ConvertFrom-Json

        foreach ($file in $remoteFiles) {
            $fileDate = [DateTime]::Parse($file.ModTime)
            if ($fileDate -lt $cutoffDate) {
                Write-Log "Removing remote: $($file.Name)" -Level INFO
                rclone delete "${script:RcloneRemote}:${script:RcloneRemotePath}/$($file.Name)" 2>&1
            }
        }

        Write-Log "Remote cleanup completed" -Level SUCCESS
    }
    catch {
        Write-Log "Remote cleanup failed: $_" -Level WARNING
    }
}

#endregion

#region Main

function Invoke-DailyBackup {
    Write-Log "Starting DAILY backup..." -Level INFO

    # Create backup
    $backupFile = New-DatabaseBackup
    if (-not $backupFile) {
        return $false
    }

    # Verify if requested
    if ($Verify) {
        $verified = Test-BackupIntegrity -BackupFile $backupFile
        if (-not $verified) {
            return $false
        }
    }

    # Cleanup old backups
    Remove-OldLocalBackups

    return $true
}

function Invoke-WeeklyBackup {
    Write-Log "Starting WEEKLY backup..." -Level INFO

    # First run daily backup
    $dailySuccess = Invoke-DailyBackup
    if (-not $dailySuccess) {
        return $false
    }

    # Get the backup file we just created
    $dailyDir = Join-Path $BackupDir "daily"
    $latestBackup = Get-ChildItem -Path $dailyDir -Filter "*.dump.gz" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

    if (-not $latestBackup) {
        Write-Log "No backup file found to upload" -Level ERROR
        return $false
    }

    # Upload to Google Drive
    $uploaded = Send-ToGoogleDrive -BackupFile $latestBackup.FullName
    if (-not $uploaded) {
        return $false
    }

    # Cleanup old remote backups
    Remove-OldRemoteBackups

    return $true
}

function Main {
    $startTime = Get-Date

    Write-Host ""
    Write-Host "=" * 50
    Write-Host "  ra-infrastructure Backup"
    Write-Host "  Type: $Type"
    Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "=" * 50
    Write-Host ""

    Write-Log "=" * 50 -Level INFO
    Write-Log "Backup started - Type: $Type" -Level INFO

    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        $body = @"
Backup Failed

Type: $Type
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Error: Prerequisites check failed

Please check:
1. Docker is running
2. Container '$script:DbContainer' is running
3. rclone is configured (for weekly backups)

--
ra-infrastructure Backup
"@
        Send-BackupAlert -Subject "[ALERT] ra-infrastructure - Backup Failed" -Body $body
        exit 1
    }

    # Run backup
    $success = switch ($Type) {
        "daily" { Invoke-DailyBackup }
        "weekly" { Invoke-WeeklyBackup }
    }

    $duration = ((Get-Date) - $startTime).TotalSeconds

    if ($success) {
        Write-Log "Backup completed successfully in $([math]::Round($duration, 1)) seconds" -Level SUCCESS
        exit 0
    }
    else {
        Write-Log "Backup failed after $([math]::Round($duration, 1)) seconds" -Level ERROR

        $body = @"
Backup Failed

Type: $Type
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Duration: $([math]::Round($duration, 1)) seconds

Check logs at: $script:LogFile

--
ra-infrastructure Backup
"@
        Send-BackupAlert -Subject "[ALERT] ra-infrastructure - Backup Failed" -Body $body
        exit 1
    }
}

Main

#endregion
