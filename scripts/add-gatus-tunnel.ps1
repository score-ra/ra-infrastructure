# Add Gatus (dash.selfwize.com) to Cloudflare Tunnel
# Run as Administrator

$configPath = "C:\Program Files (x86)\cloudflared\config.yml"

# Read current config
$content = Get-Content $configPath -Raw

# Check if dash.selfwize.com already exists
if ($content -match "dash\.selfwize\.com") {
    Write-Host "dash.selfwize.com already configured in tunnel" -ForegroundColor Yellow
} else {
    # Add the new ingress rule before the catch-all
    $newRule = @"
  - hostname: dash.selfwize.com
    service: http://localhost:8083
"@

    # Insert before the app.selfwize.com entry (or before catch-all if not present)
    if ($content -match "hostname: app\.selfwize\.com") {
        $content = $content -replace "(  - hostname: app\.selfwize\.com)", "$newRule`n`$1"
    } else {
        # Insert before catch-all
        $content = $content -replace "(  - service: http_status:404)", "$newRule`n`$1"
    }

    # Write updated config
    $content | Set-Content $configPath -NoNewline
    Write-Host "Added dash.selfwize.com -> http://localhost:8083" -ForegroundColor Green
}

# Restart the cloudflared service
Write-Host "`nRestarting cloudflared service..." -ForegroundColor Cyan
Restart-Service cloudflared

# Wait for service to start
Start-Sleep -Seconds 3

# Check service status
$service = Get-Service cloudflared
Write-Host "Service status: $($service.Status)" -ForegroundColor $(if ($service.Status -eq 'Running') { 'Green' } else { 'Red' })

Write-Host "`nTest the endpoint:" -ForegroundColor Cyan
Write-Host "  https://dash.selfwize.com" -ForegroundColor White
