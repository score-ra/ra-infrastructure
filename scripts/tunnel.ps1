# tunnel.ps1
# Manage Cloudflare Tunnel for ra-infrastructure
# Usage: .\tunnel.ps1 <command>

param(
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "run", "test", "info", "help")]
    [string]$Command = "help"
)

$tunnelName = "ra-services"

function Show-Help {
    Write-Host @"
Cloudflare Tunnel Management
============================

Usage: .\tunnel.ps1 <command>

Commands:
    start    - Start the tunnel Windows service
    stop     - Stop the tunnel Windows service
    restart  - Restart the tunnel Windows service
    status   - Show tunnel and service status
    logs     - View recent tunnel logs
    run      - Run tunnel manually (for testing, Ctrl+C to stop)
    test     - Validate configuration
    info     - Show tunnel information
    help     - Show this help message

Service Installation (run as Admin):
    cloudflared service install    # Install as Windows service
    cloudflared service uninstall  # Remove Windows service

"@
}

function Get-TunnelStatus {
    Write-Host "Tunnel Status" -ForegroundColor Cyan
    Write-Host "=============" -ForegroundColor Cyan
    Write-Host ""

    # Check if cloudflared is installed
    $cf = Get-Command cloudflared -ErrorAction SilentlyContinue
    if (-not $cf) {
        Write-Host "cloudflared: NOT INSTALLED" -ForegroundColor Red
        Write-Host "  Run: .\scripts\install-cloudflared.ps1" -ForegroundColor Gray
        return
    }
    Write-Host "cloudflared: Installed" -ForegroundColor Green
    cloudflared --version

    Write-Host ""

    # Check tunnel exists
    $tunnels = cloudflared tunnel list --output json 2>$null | ConvertFrom-Json
    $tunnel = $tunnels | Where-Object { $_.name -eq $tunnelName }

    if ($tunnel) {
        Write-Host "Tunnel '$tunnelName': EXISTS" -ForegroundColor Green
        Write-Host "  ID: $($tunnel.id)" -ForegroundColor Gray
        Write-Host "  Created: $($tunnel.created_at)" -ForegroundColor Gray
    } else {
        Write-Host "Tunnel '$tunnelName': NOT FOUND" -ForegroundColor Yellow
        Write-Host "  Run: .\scripts\install-cloudflared.ps1" -ForegroundColor Gray
    }

    Write-Host ""

    # Check Windows service
    $service = Get-Service cloudflared -ErrorAction SilentlyContinue
    if ($service) {
        $color = if ($service.Status -eq "Running") { "Green" } else { "Yellow" }
        Write-Host "Windows Service: $($service.Status)" -ForegroundColor $color
    } else {
        Write-Host "Windows Service: NOT INSTALLED" -ForegroundColor Yellow
        Write-Host "  Run (as Admin): cloudflared service install" -ForegroundColor Gray
    }

    Write-Host ""

    # Check config
    $configPath = "$env:USERPROFILE\.cloudflared\config.yml"
    if (Test-Path $configPath) {
        Write-Host "Config: $configPath" -ForegroundColor Green
    } else {
        Write-Host "Config: NOT FOUND" -ForegroundColor Yellow
        Write-Host "  Run: .\scripts\install-cloudflared.ps1" -ForegroundColor Gray
    }
}

function Start-Tunnel {
    $service = Get-Service cloudflared -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Host "Windows service not installed." -ForegroundColor Yellow
        Write-Host "Install with: cloudflared service install" -ForegroundColor Gray
        Write-Host "Or run manually with: .\tunnel.ps1 run" -ForegroundColor Gray
        return
    }

    if ($service.Status -eq "Running") {
        Write-Host "Tunnel service is already running." -ForegroundColor Green
        return
    }

    Write-Host "Starting tunnel service..." -ForegroundColor Yellow
    Start-Service cloudflared
    Start-Sleep -Seconds 2
    $service = Get-Service cloudflared
    Write-Host "Service status: $($service.Status)" -ForegroundColor Green
}

function Stop-Tunnel {
    $service = Get-Service cloudflared -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Host "Windows service not installed." -ForegroundColor Yellow
        return
    }

    if ($service.Status -eq "Stopped") {
        Write-Host "Tunnel service is already stopped." -ForegroundColor Yellow
        return
    }

    Write-Host "Stopping tunnel service..." -ForegroundColor Yellow
    Stop-Service cloudflared
    Write-Host "Service stopped." -ForegroundColor Green
}

function Restart-Tunnel {
    $service = Get-Service cloudflared -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Host "Windows service not installed." -ForegroundColor Yellow
        return
    }

    Write-Host "Restarting tunnel service..." -ForegroundColor Yellow
    Restart-Service cloudflared
    Start-Sleep -Seconds 2
    $service = Get-Service cloudflared
    Write-Host "Service status: $($service.Status)" -ForegroundColor Green
}

function Show-Logs {
    Write-Host "Recent Tunnel Logs" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    Write-Host ""

    try {
        $events = Get-WinEvent -LogName Application -FilterXPath "*[System[Provider[@Name='cloudflared']]]" -MaxEvents 30 -ErrorAction SilentlyContinue
        if ($events) {
            foreach ($event in $events) {
                $time = $event.TimeCreated.ToString("HH:mm:ss")
                $msg = $event.Message -replace "`r`n", " "
                if ($msg.Length -gt 100) { $msg = $msg.Substring(0, 100) + "..." }
                Write-Host "[$time] $msg" -ForegroundColor Gray
            }
        } else {
            Write-Host "No cloudflared events found in Application log." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Try running manually to see output:" -ForegroundColor Gray
            Write-Host "  cloudflared tunnel run $tunnelName" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Could not read logs: $_" -ForegroundColor Yellow
    }
}

function Run-Manual {
    Write-Host "Running tunnel manually (Ctrl+C to stop)..." -ForegroundColor Yellow
    Write-Host ""
    cloudflared tunnel run $tunnelName
}

function Test-Config {
    Write-Host "Validating tunnel configuration..." -ForegroundColor Yellow
    Write-Host ""
    cloudflared tunnel ingress validate
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Configuration is valid!" -ForegroundColor Green
    }
}

function Show-Info {
    Write-Host "Tunnel Information" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    Write-Host ""
    cloudflared tunnel info $tunnelName
}

# Main
switch ($Command) {
    "start"   { Start-Tunnel }
    "stop"    { Stop-Tunnel }
    "restart" { Restart-Tunnel }
    "status"  { Get-TunnelStatus }
    "logs"    { Show-Logs }
    "run"     { Run-Manual }
    "test"    { Test-Config }
    "info"    { Show-Info }
    "help"    { Show-Help }
    default   { Show-Help }
}
