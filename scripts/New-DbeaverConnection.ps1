<#
.SYNOPSIS
    Creates DBeaver connection CSV files for database import.

.DESCRIPTION
    Generates CSV files compatible with DBeaver's Custom import wizard.
    Each database type (PostgreSQL, MySQL) requires a separate CSV file
    since DBeaver requires driver selection before import.

.PARAMETER Name
    Display name for the connection in DBeaver.

.PARAMETER Type
    Database type: postgresql or mysql

.PARAMETER Host
    Database server hostname or IP address.

.PARAMETER Port
    Database server port. Defaults to 5432 (PostgreSQL) or 3306 (MySQL).

.PARAMETER Database
    Database/schema name to connect to.

.PARAMETER User
    Database username.

.PARAMETER Password
    Database password.

.PARAMETER OutputFile
    Output CSV file path. If not specified, appends to the appropriate
    type-specific file in config/dbeaver/.

.EXAMPLE
    .\New-DbeaverConnection.ps1 -Name "MyApp DB" -Type postgresql -Host localhost -Database myapp -User myuser -Password secret

.EXAMPLE
    .\New-DbeaverConnection.ps1 -Name "Analytics" -Type mysql -Host 192.168.1.100 -Database analytics -User analyst -Password pass123
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [ValidateSet("postgresql", "mysql")]
    [string]$Type,

    [Parameter(Mandatory = $true)]
    [string]$Host,

    [Parameter(Mandatory = $false)]
    [int]$Port,

    [Parameter(Mandatory = $true)]
    [string]$Database,

    [Parameter(Mandatory = $true)]
    [string]$User,

    [Parameter(Mandatory = $true)]
    [string]$Password,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile
)

$ErrorActionPreference = "Stop"

# Set default port based on database type
if (-not $Port) {
    $Port = switch ($Type) {
        "postgresql" { 5432 }
        "mysql" { 3306 }
    }
}

# Build JDBC URL based on type
$url = switch ($Type) {
    "postgresql" {
        "jdbc:postgresql://${Host}:${Port}/${Database}"
    }
    "mysql" {
        "jdbc:mysql://${Host}:${Port}/${Database}?allowPublicKeyRetrieval=true&useSSL=false"
    }
}

# Determine output file
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$configDir = Join-Path $repoRoot "config\dbeaver"

if (-not $OutputFile) {
    $OutputFile = Join-Path $configDir "${Type}-connections.csv"
}

# Ensure config directory exists
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

# Create CSV line
$csvLine = "$Name,$Host,$Port,$Database,$User,$Password,$url"

# Check if file exists
if (Test-Path $OutputFile) {
    # Check if connection with same name already exists
    $existing = Get-Content $OutputFile | Where-Object { $_ -match "^$([regex]::Escape($Name))," }
    if ($existing) {
        Write-Warning "Connection '$Name' already exists in $OutputFile"
        Write-Warning "Existing: $existing"
        $response = Read-Host "Replace? (y/N)"
        if ($response -eq 'y') {
            $content = Get-Content $OutputFile | Where-Object { $_ -notmatch "^$([regex]::Escape($Name))," }
            $content += $csvLine
            $content | Set-Content $OutputFile
            Write-Host "Updated connection '$Name' in $OutputFile" -ForegroundColor Green
        }
        else {
            Write-Host "Skipped." -ForegroundColor Yellow
        }
        return
    }

    # Append to existing file
    Add-Content -Path $OutputFile -Value $csvLine
    Write-Host "Added connection '$Name' to $OutputFile" -ForegroundColor Green
}
else {
    # Create new file with header
    $header = "name,host,port,database,user,password,url"
    @($header, $csvLine) | Set-Content $OutputFile
    Write-Host "Created $OutputFile with connection '$Name'" -ForegroundColor Green
}

Write-Host ""
Write-Host "To import in DBeaver:" -ForegroundColor Cyan
Write-Host "  1. File -> Import -> DBeaver -> Custom"
Write-Host "  2. Select driver: $Type"
Write-Host "  3. Select file: $OutputFile"
Write-Host "  4. Map columns and finish"
