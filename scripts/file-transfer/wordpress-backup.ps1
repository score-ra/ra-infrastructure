# WordPress Site Backup Script for Symphony Core
# Downloads complete WordPress site from GoHighLevel/Rocket hosting

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("full", "wp-content", "config", "uploads")]
    [string]$BackupType = "full",

    [Parameter(Mandatory=$false)]
    [string]$LocalPath = ".\wordpress-backups",

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [switch]$Compress
)

# Import WinSCP module or assembly
try {
    Import-Module WinSCP -ErrorAction Stop
    Write-Host "✓ WinSCP module loaded successfully" -ForegroundColor Green
} catch {
    try {
        Add-Type -Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll" -ErrorAction Stop
        Write-Host "✓ WinSCP assembly loaded successfully" -ForegroundColor Green
    } catch {
        Write-Error "WinSCP not found. Please install WinSCP first."
        exit 1
    }
}

# Load WordPress environment configuration
$envConfigPath = ".\environments\wordpress\.env"
if (-not (Test-Path $envConfigPath)) {
    Write-Error "WordPress environment configuration not found: $envConfigPath"
    exit 1
}

# Parse environment file
$envConfig = @{}
Get-Content $envConfigPath | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$') {
        $envConfig[$matches[1].Trim()] = $matches[2].Trim()
    }
}

# Ensure local backup directory exists
if (-not (Test-Path $LocalPath)) {
    New-Item -ItemType Directory -Path $LocalPath -Force | Out-Null
    Write-Host "✓ Created backup directory: $LocalPath" -ForegroundColor Green
}

Write-Host "🌐 Symphony Core WordPress Backup" -ForegroundColor Cyan
Write-Host "Host: $($envConfig['DEPLOY_HOST'])" -ForegroundColor Yellow
Write-Host "Site: $($envConfig['SITE_URL'])" -ForegroundColor Yellow
Write-Host "Backup Type: $BackupType" -ForegroundColor Yellow
Write-Host "Local Path: $LocalPath" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host "DRY RUN MODE - No files will be downloaded" -ForegroundColor Magenta
}

# Setup WinSCP session options for FTP
$sessionOptions = New-Object WinSCP.SessionOptions -Property @{
    Protocol = [WinSCP.Protocol]::Ftp
    HostName = $envConfig["DEPLOY_HOST"]
    UserName = $envConfig["DEPLOY_USER"]
    Password = $envConfig["DEPLOY_PASSWORD"]
    PortNumber = [int]$envConfig["DEPLOY_PORT"]
    FtpMode = [WinSCP.FtpMode]::Passive
}

Write-Host "🔌 Connecting to WordPress server..." -ForegroundColor Cyan

try {
    $session = New-Object WinSCP.Session

    if (-not $DryRun) {
        $session.Open($sessionOptions)
        Write-Host "✓ Connected to $($envConfig['DEPLOY_HOST'])" -ForegroundColor Green

        # Check if we're in the right directory
        $remoteFiles = $session.ListDirectory("/")
        Write-Host "📁 Remote root directory contents:" -ForegroundColor Gray
        foreach ($file in $remoteFiles.Files) {
            if ($file.Name -ne "." -and $file.Name -ne "..") {
                Write-Host "  $($file.Name) $(if($file.IsDirectory){'[DIR]'}else{$file.Length + ' bytes'})" -ForegroundColor Gray
            }
        }
    }

    # Generate timestamp for backup
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    # Define backup tasks based on type
    $backupTasks = @()

    switch ($BackupType) {
        "full" {
            $backupTasks += @{
                RemotePath = "/public_html"
                LocalPath = "$LocalPath\wordpress-site-$timestamp"
                Description = "Complete WordPress site"
                Recursive = $true
            }
        }
        "wp-content" {
            $backupTasks += @{
                RemotePath = "/public_html/wp-content"
                LocalPath = "$LocalPath\wp-content-$timestamp"
                Description = "WordPress content directory"
                Recursive = $true
            }
        }
        "config" {
            $backupTasks += @{
                RemotePath = "/public_html/wp-config.php"
                LocalPath = "$LocalPath\wp-config-$timestamp.php"
                Description = "WordPress configuration file"
                Recursive = $false
            }
        }
        "uploads" {
            $backupTasks += @{
                RemotePath = "/public_html/wp-content/uploads"
                LocalPath = "$LocalPath\wp-uploads-$timestamp"
                Description = "WordPress uploads directory"
                Recursive = $true
            }
        }
    }

    # Execute backup tasks
    foreach ($task in $backupTasks) {
        Write-Host "`n📦 Backing up: $($task.Description)" -ForegroundColor Cyan

        if ($DryRun) {
            Write-Host "   Would download: $($task.RemotePath) -> $($task.LocalPath)" -ForegroundColor Magenta
            continue
        }

        # Check if remote path exists
        if (-not $session.FileExists($task.RemotePath)) {
            Write-Host "   ⚠ Remote path not found: $($task.RemotePath)" -ForegroundColor Yellow
            continue
        }

        try {
            Write-Host "   🔄 Downloading from $($task.RemotePath)..." -ForegroundColor Yellow

            # Configure transfer options
            $transferOptions = New-Object WinSCP.TransferOptions
            $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
            $transferOptions.ResumeSupport.State = [WinSCP.TransferResumeSupportState]::On

            # Exclude cache and temporary files for WordPress
            if ($task.RemotePath.Contains("wp-content")) {
                $transferOptions.FileMask = "*|*.log;*.tmp;cache/;*cache*/"
            }

            $transferResult = $session.GetFiles($task.RemotePath, $task.LocalPath, $false, $transferOptions)

            if ($transferResult.IsSuccess) {
                Write-Host "   ✓ Download completed successfully" -ForegroundColor Green

                # Display transfer statistics
                $totalSize = ($transferResult.Transfers | Measure-Object Length -Sum).Sum
                $fileCount = $transferResult.Transfers.Count
                Write-Host "   📊 Files: $fileCount, Total size: $([math]::Round($totalSize/1MB, 2)) MB" -ForegroundColor Gray

                # List some of the transferred files
                Write-Host "   📄 Sample files:" -ForegroundColor Gray
                $transferResult.Transfers | Select-Object -First 5 | ForEach-Object {
                    Write-Host "     $($_.FileName)" -ForegroundColor Gray
                }
                if ($transferResult.Transfers.Count -gt 5) {
                    Write-Host "     ... and $($transferResult.Transfers.Count - 5) more files" -ForegroundColor Gray
                }

            } else {
                Write-Host "   ✗ Download failed" -ForegroundColor Red
                foreach ($failure in $transferResult.Failures) {
                    Write-Host "     Error: $($failure.Message)" -ForegroundColor Red
                }
            }

        } catch {
            Write-Host "   ✗ Backup error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "`n🎉 WordPress backup completed successfully!" -ForegroundColor Green

} catch {
    Write-Error "WordPress backup failed: $($_.Exception.Message)"
    exit 1
} finally {
    if ($session) {
        $session.Dispose()
    }
}

# Log backup operation
$logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - WordPress backup ($BackupType) completed - $LocalPath"
$logPath = "$LocalPath\backup-history.log"
Add-Content -Path $logPath -Value $logEntry

Write-Host "`n📝 Backup logged to: $logPath" -ForegroundColor Gray