# install-cloudflared.ps1
# Installs and configures Cloudflare Tunnel (cloudflared) on Windows
# Run as Administrator

#Requires -RunAsAdministrator

param(
    [switch]$SkipInstall,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Cloudflared Installation Script
================================

Usage:
    .\install-cloudflared.ps1              # Full install
    .\install-cloudflared.ps1 -SkipInstall # Skip winget, just configure

This script will:
1. Install cloudflared via winget
2. Guide you through authentication
3. Create a tunnel
4. Set up DNS routes for selfwize.com subdomains
5. Install as Windows service (with registry fix)

Subdomains configured:
- stuff.selfwize.com    -> localhost:3001 (IT/Asset Inventory)
- wellness.selfwize.com -> localhost:3002 (Medical/Health)
- app.selfwize.com      -> localhost:3000 (Dashboard)
- api.selfwize.com      -> localhost:8080 (API)

"@
    exit 0
}

$ErrorActionPreference = "Stop"
$tunnelName = "selfwize-dev"
$domain = "selfwize.com"
$installDir = "C:\Program Files (x86)\cloudflared"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Cloudflare Tunnel Setup" -ForegroundColor Cyan
Write-Host " Domain: $domain" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Install cloudflared
if (-not $SkipInstall) {
    Write-Host "[1/7] Installing cloudflared..." -ForegroundColor Yellow

    # Check multiple possible locations
    $cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
    if (-not $cloudflared) {
        $cloudflared = Get-Command "$installDir\cloudflared.exe" -ErrorAction SilentlyContinue
    }

    if ($cloudflared) {
        Write-Host "  cloudflared already installed: $($cloudflared.Source)" -ForegroundColor Green
        & $cloudflared.Source --version
    } else {
        Write-Host "  Installing via winget..." -ForegroundColor Gray
        winget install Cloudflare.cloudflared --accept-source-agreements --accept-package-agreements

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        Write-Host "  Installed successfully!" -ForegroundColor Green
    }
} else {
    Write-Host "[1/7] Skipping installation..." -ForegroundColor Gray
}

# Get cloudflared path
$cloudflaredExe = "$installDir\cloudflared.exe"
if (-not (Test-Path $cloudflaredExe)) {
    $cloudflaredExe = (Get-Command cloudflared -ErrorAction SilentlyContinue).Source
}
if (-not $cloudflaredExe) {
    Write-Host "ERROR: cloudflared not found!" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: Authenticate
Write-Host "[2/7] Authenticating with Cloudflare..." -ForegroundColor Yellow

$certPath = "$env:USERPROFILE\.cloudflared\cert.pem"
if (Test-Path $certPath) {
    Write-Host "  Already authenticated (cert.pem exists)" -ForegroundColor Green
    $reauth = Read-Host "  Re-authenticate? (y/N)"
    if ($reauth -eq 'y') {
        & $cloudflaredExe tunnel login
    }
} else {
    Write-Host "  Opening browser for authentication..." -ForegroundColor Gray
    Write-Host "  Select '$domain' when prompted." -ForegroundColor Gray
    & $cloudflaredExe tunnel login
}

Write-Host ""

# Step 3: Create tunnel
Write-Host "[3/7] Creating tunnel..." -ForegroundColor Yellow

$existingTunnel = & $cloudflaredExe tunnel list --output json 2>$null | ConvertFrom-Json | Where-Object { $_.name -eq $tunnelName }

if ($existingTunnel) {
    Write-Host "  Tunnel '$tunnelName' already exists: $($existingTunnel.id)" -ForegroundColor Green
    $tunnelId = $existingTunnel.id
} else {
    Write-Host "  Creating tunnel '$tunnelName'..." -ForegroundColor Gray
    $output = & $cloudflaredExe tunnel create $tunnelName 2>&1
    Write-Host $output

    # Get the tunnel ID
    $tunnelInfo = & $cloudflaredExe tunnel list --output json | ConvertFrom-Json | Where-Object { $_.name -eq $tunnelName }
    $tunnelId = $tunnelInfo.id
    Write-Host "  Tunnel created with ID: $tunnelId" -ForegroundColor Green
}

Write-Host ""

# Step 4: Create DNS routes
Write-Host "[4/7] Creating DNS routes..." -ForegroundColor Yellow

$subdomains = @("stuff", "wellness", "app", "api")
foreach ($sub in $subdomains) {
    $hostname = "$sub.$domain"
    Write-Host "  Routing $hostname..." -ForegroundColor Gray
    & $cloudflaredExe tunnel route dns $tunnelName $hostname 2>&1 | Out-Null
}
Write-Host "  DNS routes created" -ForegroundColor Green

Write-Host ""

# Step 5: Create config files
Write-Host "[5/7] Creating configuration..." -ForegroundColor Yellow

$userConfigDir = "$env:USERPROFILE\.cloudflared"
$userCredentials = "$userConfigDir\$tunnelId.json"

# Config for user (manual run)
$userConfigContent = @"
# Cloudflare Tunnel Configuration
# Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

tunnel: $tunnelId
credentials-file: $userCredentials

ingress:
  - hostname: stuff.$domain
    service: http://localhost:3001
  - hostname: wellness.$domain
    service: http://localhost:3002
  - hostname: app.$domain
    service: http://localhost:3000
  - hostname: api.$domain
    service: http://localhost:8080
  - service: http_status:404
"@

$userConfigContent | Out-File -FilePath "$userConfigDir\config.yml" -Encoding utf8 -Force
Write-Host "  User config: $userConfigDir\config.yml" -ForegroundColor Green

# Config for service (uses Program Files)
$serviceCredentials = "$installDir\$tunnelId.json"
$serviceConfigContent = @"
# Cloudflare Tunnel Configuration (Windows Service)
# Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

tunnel: $tunnelId
credentials-file: $serviceCredentials

ingress:
  - hostname: stuff.$domain
    service: http://localhost:3001
  - hostname: wellness.$domain
    service: http://localhost:3002
  - hostname: app.$domain
    service: http://localhost:3000
  - hostname: api.$domain
    service: http://localhost:8080
  - service: http_status:404
"@

# Copy credentials and config to Program Files
Copy-Item $userCredentials "$installDir\" -Force
$serviceConfigContent | Out-File -FilePath "$installDir\config.yml" -Encoding utf8 -Force
Write-Host "  Service config: $installDir\config.yml" -ForegroundColor Green

Write-Host ""

# Step 6: Validate
Write-Host "[6/7] Validating configuration..." -ForegroundColor Yellow

& $cloudflaredExe tunnel ingress validate
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Configuration is valid!" -ForegroundColor Green
} else {
    Write-Host "  Configuration has errors!" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 7: Install service with registry fix
Write-Host "[7/7] Installing Windows service..." -ForegroundColor Yellow

# Uninstall existing service if present
& $cloudflaredExe service uninstall 2>$null
Start-Sleep -Seconds 2

# Install service
& $cloudflaredExe service install
Start-Sleep -Seconds 2

# Fix registry to use config file (IMPORTANT!)
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\cloudflared"
Set-ItemProperty $regPath -Name ImagePath -Value "`"$cloudflaredExe`" --config `"$installDir\config.yml`" tunnel run"
Write-Host "  Registry updated to use config file" -ForegroundColor Green

# Start service
Start-Service cloudflared
Start-Sleep -Seconds 3
$svc = Get-Service cloudflared
Write-Host "  Service status: $($svc.Status)" -ForegroundColor $(if ($svc.Status -eq 'Running') { 'Green' } else { 'Red' })

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Setup Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tunnel ID: $tunnelId" -ForegroundColor White
Write-Host ""
Write-Host "URLs configured:" -ForegroundColor Yellow
Write-Host "  https://stuff.$domain    -> localhost:3001" -ForegroundColor Cyan
Write-Host "  https://wellness.$domain -> localhost:3002" -ForegroundColor Cyan
Write-Host "  https://app.$domain      -> localhost:3000" -ForegroundColor Cyan
Write-Host "  https://api.$domain      -> localhost:8080" -ForegroundColor Cyan
Write-Host ""
Write-Host "Service commands:" -ForegroundColor Yellow
Write-Host "  Get-Service cloudflared" -ForegroundColor Gray
Write-Host "  Restart-Service cloudflared" -ForegroundColor Gray
Write-Host "  Stop-Service cloudflared" -ForegroundColor Gray
Write-Host ""
Write-Host "Next: Set up Cloudflare Access (authentication):" -ForegroundColor Yellow
Write-Host "  https://one.dash.cloudflare.com" -ForegroundColor Cyan
Write-Host ""
