# Run as Administrator
Stop-Service cloudflared

$config = @"
tunnel: 1f014ff9-68ae-4033-bacf-e058b91d2df4
credentials-file: C:\Program Files (x86)\cloudflared\1f014ff9-68ae-4033-bacf-e058b91d2df4.json

ingress:
  - hostname: stuff.selfwize.com
    service: http://localhost:8082
  - hostname: wellness.selfwize.com
    service: https://localhost:9090
    originRequest:
      noTLSVerify: true
  - hostname: app.selfwize.com
    service: http://localhost:3000
  - hostname: api.selfwize.com
    service: http://localhost:8080
  - service: http_status:404
"@

$config | Set-Content "C:\Program Files (x86)\cloudflared\config.yml" -Force
Start-Service cloudflared
Get-Service cloudflared
Write-Host "Done! Test https://wellness.selfwize.com" -ForegroundColor Green
