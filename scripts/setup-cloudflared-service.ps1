# Setup Cloudflared Windows Service
# Run this script as Administrator

$tunnelId = "1f014ff9-68ae-4033-bacf-e058b91d2df4"
$installDir = "C:\Program Files (x86)\cloudflared"
$userDir = "$env:USERPROFILE\.cloudflared"

Write-Host "=== Cloudflared Service Setup ===" -ForegroundColor Cyan

# Step 1: Copy credentials
Write-Host "`n[1/5] Copying credentials..." -ForegroundColor Yellow
Copy-Item "$userDir\$tunnelId.json" "$installDir\" -Force
Write-Host "  Done" -ForegroundColor Green

# Step 2: Create config
Write-Host "`n[2/5] Creating config..." -ForegroundColor Yellow
$config = @"
tunnel: $tunnelId
credentials-file: $installDir\$tunnelId.json

ingress:
  - hostname: stuff.selfwize.com
    service: http://localhost:3001
  - hostname: wellness.selfwize.com
    service: http://localhost:3002
  - hostname: app.selfwize.com
    service: http://localhost:3000
  - hostname: api.selfwize.com
    service: http://localhost:8080
  - service: http_status:404
"@
$config | Set-Content "$installDir\config.yml" -Force
Write-Host "  Done" -ForegroundColor Green

# Step 3: Reinstall service
Write-Host "`n[3/5] Installing service..." -ForegroundColor Yellow
& "$installDir\cloudflared.exe" service uninstall 2>$null
Start-Sleep -Seconds 2
& "$installDir\cloudflared.exe" service install
Write-Host "  Done" -ForegroundColor Green

# Step 4: Fix service registry to use config file
Write-Host "`n[4/5] Configuring service registry..." -ForegroundColor Yellow
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\cloudflared"
Set-ItemProperty $regPath -Name ImagePath -Value "`"$installDir\cloudflared.exe`" --config `"$installDir\config.yml`" tunnel run"
Write-Host "  Done" -ForegroundColor Green

# Step 5: Start service
Write-Host "`n[5/5] Starting service..." -ForegroundColor Yellow
Start-Service cloudflared
Start-Sleep -Seconds 3
$svc = Get-Service cloudflared
Write-Host "  Status: $($svc.Status)" -ForegroundColor $(if ($svc.Status -eq 'Running') { 'Green' } else { 'Red' })

# Summary
Write-Host "`n=== Complete ===" -ForegroundColor Cyan
Write-Host "Config: $installDir\config.yml"
Write-Host "Credentials: $installDir\$tunnelId.json"
