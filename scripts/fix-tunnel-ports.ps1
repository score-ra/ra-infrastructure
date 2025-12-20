# Fix Cloudflared Tunnel Ports
# Run as Administrator!

$configPath = "C:\Program Files (x86)\cloudflared\config.yml"

Write-Host "Updating cloudflared config..." -ForegroundColor Cyan

# Read current config
$content = Get-Content $configPath -Raw

# Update ports
$content = $content -replace 'localhost:3001', 'localhost:8082'
$content = $content -replace 'localhost:3002', 'localhost:9090'

# Write back
$content | Set-Content $configPath -Force

Write-Host "Config updated. New mappings:" -ForegroundColor Green
Write-Host "  stuff.selfwize.com -> localhost:8082 (Snipe-IT)"
Write-Host "  wellness.selfwize.com -> localhost:9090 (Fasten Health)"

# Restart service
Write-Host "`nRestarting cloudflared service..." -ForegroundColor Cyan
Restart-Service cloudflared

# Wait for service to start
Start-Sleep -Seconds 3

# Verify
$status = Get-Service cloudflared
Write-Host "Service status: $($status.Status)" -ForegroundColor $(if ($status.Status -eq 'Running') {'Green'} else {'Red'})

Write-Host "`nTest the site now: https://stuff.selfwize.com" -ForegroundColor Yellow
