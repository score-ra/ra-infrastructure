# Infrastructure Self-Check

## Overview

The `inv system selfcheck` command provides comprehensive health monitoring for all infrastructure services managed by ra-infrastructure. This command is designed to verify operational status after system reboots, deployments, or when troubleshooting service issues.

## Quick Start

```powershell
# Run comprehensive self-check
inv system selfcheck

# Run with verbose output
inv system selfcheck --verbose

# Check a specific endpoint
inv system check-endpoint https://status.selfwize.com
```

## What Gets Checked

### 1. Docker Infrastructure
- **Docker Daemon** - Verifies Docker is responsive
- **PostgreSQL Container** (inventory-db) - Critical ⚠️
- **MySQL Container** (homeautomation-db) - Critical ⚠️
- **pgAdmin Container** (inventory-pgadmin)
- **Traefik Reverse Proxy** (traefik)
- **Gatus Status Monitor** (ra-status)
- **Selfwize Dashboard** (selfwize-dashboard)

### 2. Database Services
- **PostgreSQL** - Connection test to inventory database - Critical ⚠️
- **MySQL** - Connection test to homeautomation database - Critical ⚠️

### 3. Cloudflare Tunnel
- **cloudflared Service** - Windows service status - Critical ⚠️

### 4. External Endpoints (*.selfwize.com)
- **Status Monitor** (status.selfwize.com)
- **Asset Inventory** (stuff.selfwize.com) - Cloudflare Access protected
- **Health Records** (wellness.selfwize.com) - Cloudflare Access protected
- **Home Assistant** (home.selfwize.com) - Cloudflare Access protected
- **Blue Iris** (cameras.selfwize.com) - Cloudflare Access protected
- **Family Contacts** (family.selfwize.com) - Cloudflare Access protected
- **Daily Events** (events.selfwize.com) - Cloudflare Access protected

### 5. Selfwize Dashboard
- **Dashboard Availability** (dash.selfwize.com)
- **Service Card Detection** - Verifies all expected services are visible

## Exit Codes

| Code | Status | Description |
|------|--------|-------------|
| 0 | Success | All services operational |
| 1 | Failure | One or more critical services unavailable |

Critical services are marked with ⚠️ above. Non-critical service failures result in warnings but don't cause the check to fail.

## Example Output

```
+------------------------------------------+
| ra-infrastructure Self-Check             |
| Verifying all infrastructure services... |
+------------------------------------------+

Docker Infrastructure
  Docker Daemon         OK    daemon responsive
  PostgreSQL            OK    running
  MySQL                 OK    running
  pgAdmin               OK    running
  Traefik               OK    running
  Gatus                 OK    running
  Dashboard             OK    running

Database Services
  PostgreSQL (inventory)     OK    connected (15ms)
  MySQL (homeautomation)     OK    alive

Cloudflare Tunnel
  cloudflared service    OK    service running

External Endpoints (*.selfwize.com)
  Status Monitor         OK    HTTP 200 (203ms)
  Asset Inventory        OK    HTTP 403 (auth required)
  Health Records         OK    HTTP 403 (auth required)
  Home Assistant        OK    HTTP 200 (490ms)
  Blue Iris             OK    HTTP 200 (312ms)
  Family Contacts       OK    HTTP 200 (177ms)
  Daily Events          OK    HTTP 200 (105ms)

Selfwize Dashboard
  dash.selfwize.com     OK    HTTP 200, 9/9 services (234ms)

+--------------------------------------+
| ALL SYSTEMS OPERATIONAL              |
| All infrastructure services healthy. |
+--------------------------------------+
```

## Post-Reboot Verification

After any system reboot or power outage, run the self-check to verify:

```powershell
# Wait 2-3 minutes after boot for services to start
Start-Sleep -Seconds 180

# Run self-check
inv system selfcheck

# If failures detected, check Docker
.\scripts\check-docker-health.ps1

# If Docker is unhealthy, attempt recovery
.\scripts\check-docker-health.ps1 -AutoRestart
```

## Troubleshooting

### Docker Daemon Timeout

**Symptom:** `Docker Daemon - CRITICAL - daemon timeout`

**Solution:**
```powershell
# Check if Docker Desktop is running
Get-Process "Docker Desktop" -ErrorAction SilentlyContinue

# If not running, start it
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Wait for Docker to initialize
Start-Sleep -Seconds 60

# Re-run self-check
inv system selfcheck
```

### Database Connection Failed

**Symptom:** `PostgreSQL (inventory) - CRITICAL - connection failed`

**Solution:**
```powershell
# Check container is running
docker ps | findstr inventory-db

# Check container logs
docker logs inventory-db --tail 50

# Restart container if needed
docker restart inventory-db

# Wait for database to be ready
Start-Sleep -Seconds 10

# Re-run self-check
inv system selfcheck
```

### Cloudflared Service Not Running

**Symptom:** `cloudflared service - CRITICAL - service stopped`

**Solution:**
```powershell
# Check service status
Get-Service cloudflared

# Start service if stopped
Start-Service cloudflared

# Verify tunnel is working
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel info selfwize-dev

# Re-run self-check
inv system selfcheck
```

### External Endpoints Failing

**Symptom:** `Asset Inventory - WARN - connection failed`

**Solution:**
1. Verify cloudflared service is running (see above)
2. Check Traefik reverse proxy:
   ```powershell
   docker logs traefik --tail 50
   ```
3. Test endpoint directly:
   ```powershell
   inv system check-endpoint https://stuff.selfwize.com
   ```
4. Check Cloudflare dashboard for tunnel status

### Selfwize Dashboard Service Detection Failed

**Symptom:** `dash.selfwize.com - WARN - only 3/9 services`

**Possible Causes:**
- Dashboard container not fully started
- Configuration file missing services
- External dependencies (ra-life-tracker apps) not running

**Solution:**
```powershell
# Check dashboard container logs
docker logs selfwize-dashboard

# Restart dashboard
docker restart selfwize-dashboard

# Wait for startup
Start-Sleep -Seconds 15

# Re-run self-check
inv system selfcheck
```

## Automation

### Task Scheduler

Create a scheduled task to run self-check on boot:

```powershell
# Create task to run 5 minutes after boot
$action = New-ScheduledTaskAction -Execute "inv" -Argument "system selfcheck" -WorkingDirectory "C:\Users\ranand\workspace\personal\software\ra-infrastructure"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay (New-TimeSpan -Minutes 5)
$principal = New-ScheduledTaskPrincipal -UserId "ranand" -LogonType Interactive

Register-ScheduledTask -TaskName "RA-Infrastructure-SelfCheck" `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Description "Run infrastructure self-check after system boot"
```

### PowerShell Script

Create a wrapper script for automated checks:

```powershell
# check-infrastructure.ps1

param(
    [switch]$AutoRecover
)

Write-Host "Running infrastructure self-check..." -ForegroundColor Cyan

# Run self-check
inv system selfcheck

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nSelf-check FAILED!" -ForegroundColor Red

    if ($AutoRecover) {
        Write-Host "Attempting auto-recovery..." -ForegroundColor Yellow

        # Attempt Docker recovery
        .\scripts\check-docker-health.ps1 -AutoRestart

        # Wait and retry
        Start-Sleep -Seconds 30
        inv system selfcheck

        if ($LASTEXITCODE -eq 0) {
            Write-Host "`nRecovery SUCCESSFUL" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "`nRecovery FAILED - manual intervention required" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "`nRun with -AutoRecover to attempt automatic recovery" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "`nAll systems operational" -ForegroundColor Green
    exit 0
}
```

## Integration with Monitoring

The self-check command integrates with existing monitoring:

- **Gatus** - Continuous monitoring of endpoints (30-60s intervals)
- **Self-Check** - On-demand comprehensive validation
- **check-docker-health.ps1** - Docker-specific health and recovery

Use self-check for:
- Post-reboot verification
- Pre-deployment validation
- Troubleshooting sessions
- Manual health audits

Use Gatus for:
- Real-time monitoring
- Email alerts on failures
- Historical uptime tracking
- Service status dashboard

## Related Documentation

- [Docker Troubleshooting](../start-here.md#docker-troubleshooting--recovery)
- [Cloudflare Tunnel Setup](CLOUDFLARE-TUNNEL-SETUP.md)
- [Disaster Recovery Runbook](DR-RUNBOOK.md)
- [Gatus Monitoring](../gatus/README.md)
- [Service Monitoring PRD](prds/PRD-007-service-monitoring-dashboard.md)

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-04 | Initial release with comprehensive infrastructure checks |
