# WordPress Site Backup Script for Symphony Core
param(
    [string]$BackupType = "full",
    [string]$LocalPath = ".\wordpress-backups",
    [switch]$DryRun
)

# Import WinSCP assembly
try {
    Add-Type -Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll" -ErrorAction Stop
    Write-Host "✓ WinSCP assembly loaded successfully" -ForegroundColor Green
} catch {
    Write-Error "WinSCP not found. Please install WinSCP first."
    exit 1
}

# Load configuration from env file
$configFile = Join-Path $PSScriptRoot "..\..\config\wordpress-ftp.env"
$envConfig = @{}

if (Test-Path $configFile) {
    Get-Content $configFile | ForEach-Object {
        if ($_ -match "^([^#=]+)=(.*)$") {
            $envConfig[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
} else {
    Write-Error "Configuration file not found: $configFile"
    Write-Error "Copy config/wordpress-ftp.env.template to config/wordpress-ftp.env and fill in values"
    exit 1
}

# Validate required config values
$requiredKeys = @("DEPLOY_HOST", "DEPLOY_PORT", "DEPLOY_USER", "DEPLOY_PASSWORD", "SITE_URL")
foreach ($key in $requiredKeys) {
    if (-not $envConfig.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($envConfig[$key])) {
        Write-Error "Missing required configuration: $key"
        exit 1
    }
}

# Create backup directory
if (-not (Test-Path $LocalPath)) {
    New-Item -ItemType Directory -Path $LocalPath -Force | Out-Null
    Write-Host "✓ Created backup directory: $LocalPath" -ForegroundColor Green
}

Write-Host "🌐 Symphony Core WordPress Backup" -ForegroundColor Cyan
Write-Host "Host: $($envConfig.DEPLOY_HOST)" -ForegroundColor Yellow
Write-Host "Site: $($envConfig.SITE_URL)" -ForegroundColor Yellow
Write-Host "Backup Type: $BackupType" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host "DRY RUN MODE - No files will be downloaded" -ForegroundColor Magenta
}

# Setup WinSCP session
$sessionOptions = New-Object WinSCP.SessionOptions -Property @{
    Protocol = [WinSCP.Protocol]::Ftp
    HostName = $envConfig.DEPLOY_HOST
    UserName = $envConfig.DEPLOY_USER
    Password = $envConfig.DEPLOY_PASSWORD
    PortNumber = [int]$envConfig.DEPLOY_PORT
    FtpMode = [WinSCP.FtpMode]::Passive
}

Write-Host "🔌 Connecting to WordPress server..." -ForegroundColor Cyan

try {
    $session = New-Object WinSCP.Session

    if (-not $DryRun) {
        $session.Open($sessionOptions)
        Write-Host "✓ Connected to $($envConfig.DEPLOY_HOST)" -ForegroundColor Green

        # List root directory
        Write-Host "📁 Remote directory contents:" -ForegroundColor Gray
        $remoteFiles = $session.ListDirectory("/")
        foreach ($file in $remoteFiles.Files) {
            if ($file.Name -ne "." -and $file.Name -ne "..") {
                $type = if ($file.IsDirectory) { "[DIR]" } else { "$($file.Length) bytes" }
                Write-Host "  $($file.Name) - $type" -ForegroundColor Gray
            }
        }
    }

    # Generate timestamp
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    # Define what to backup
    $remotePath = "/public_html"
    $localBackupPath = "$LocalPath\wordpress-site-$timestamp"

    Write-Host "`n📦 Backing up: Complete WordPress site" -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "   Would download: $remotePath -> $localBackupPath" -ForegroundColor Magenta
    } else {
        # Check if remote path exists
        if ($session.FileExists($remotePath)) {
            Write-Host "   🔄 Downloading from $remotePath..." -ForegroundColor Yellow

            # Configure transfer options
            $transferOptions = New-Object WinSCP.TransferOptions
            $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
            $transferOptions.FileMask = "*|*.log;*.tmp;cache/;*cache*/"

            $transferResult = $session.GetFiles($remotePath, $localBackupPath, $false, $transferOptions)

            if ($transferResult.IsSuccess) {
                Write-Host "   ✓ Download completed successfully" -ForegroundColor Green
                $fileCount = $transferResult.Transfers.Count
                Write-Host "   📊 Downloaded $fileCount files" -ForegroundColor Gray
            } else {
                Write-Host "   ✗ Download failed" -ForegroundColor Red
                foreach ($failure in $transferResult.Failures) {
                    Write-Host "     Error: $($failure.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "   ⚠ Remote path not found: $remotePath" -ForegroundColor Yellow
        }
    }

    Write-Host "`n🎉 WordPress backup completed!" -ForegroundColor Green

} catch {
    Write-Error "WordPress backup failed: $($_.Exception.Message)"
    exit 1
} finally {
    if ($session) {
        $session.Dispose()
    }
}

Write-Host "📝 Backup logged to: $LocalPath\backup-history.log" -ForegroundColor Gray