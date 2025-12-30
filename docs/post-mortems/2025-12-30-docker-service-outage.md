# Post-Mortem: Docker Desktop Service Outage

**Date:** December 30, 2025
**Duration:** ~4+ hours (5:00 AM system boot until ~9:30 AM when resolved)
**Severity:** High (all infrastructure services unavailable)
**Author:** Claude Code Assistant

---

## Executive Summary

All Docker-based infrastructure services became unavailable after a system reboot. Docker Desktop application was running, but the backend service (`com.docker.service`) failed to start, leaving 11 containers in a stopped state. External services (Snipe-IT, Fasten Health, Homarr, Gatus) were inaccessible via Cloudflare Tunnel.

---

## Timeline of Events

| Time | Event |
|------|-------|
| 05:00:31 | Windows system rebooted |
| 05:00:45 | Docker Desktop.exe launched (auto-start via registry) |
| 05:01:00 | `com.docker.service` failed to start (Manual startup type) |
| 05:01:xx | Docker Desktop UI running but daemon unresponsive |
| ~09:25 | User reported Docker UI unable to start, services down |
| 09:26 | Investigation began - `docker ps` returned connection error |
| 09:27 | Identified `com.docker.service` in Stopped state |
| 09:28 | Restarted Docker Desktop application |
| 09:29 | Docker daemon initialized, all 11 containers auto-started |
| 09:30 | All services verified operational |

---

## Root Cause Analysis

### Primary Cause: Docker Service Startup Type Misconfiguration

The `com.docker.service` Windows service is configured with **Manual** startup type:

```
Name                Status  StartType
----                ------  ---------
com.docker.service  Stopped Manual
```

When Windows rebooted:
1. Docker Desktop.exe was launched via `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
2. The Docker Desktop application UI started successfully
3. However, `com.docker.service` (the backend) did not start because it's set to Manual
4. Docker Desktop UI was in a "starting" state indefinitely, waiting for a backend that never initialized

### Contributing Factors

1. **Race condition on startup:** Docker Desktop app expects the service to be available but doesn't reliably start it
2. **No startup dependency enforcement:** Docker Desktop doesn't declare a dependency on `com.docker.service`
3. **Silent failure:** No error notification to the user that Docker wasn't fully operational
4. **No health monitoring:** No automated alerting when Docker services go down

---

## Technical Details

### System Information

- **Platform:** Windows (win32)
- **Docker Desktop Version:** 29.1.3
- **Docker Compose Version:** v2.40.3-desktop.1
- **Last Boot:** December 30, 2025 05:00:31 AM

### Services Affected

| Container | Port | Impact |
|-----------|------|--------|
| inventory-db (PostgreSQL) | 5432 | Database unavailable |
| inventory-pgadmin | 5050 | UI unavailable |
| homeautomation-db (MySQL) | 3306 | Database unavailable |
| snipeit-app | 8082 | Asset management down |
| snipeit-db | internal | Database unavailable |
| fasten-prod | 9090 | Health records unavailable |
| gatus (ra-status) | 8083 | Monitoring unavailable |
| homarr | 7575 | Dashboard unavailable |
| traefik | 80, 8080 | Reverse proxy down |
| gramps-web | 5000 | Genealogy app unavailable |
| event-log-db | 5433 | Event database unavailable |

### External Impact

All Cloudflare Tunnel endpoints were unreachable:
- stuff.selfwize.com (Snipe-IT)
- wellness.selfwize.com (Fasten Health)
- dash.selfwize.com (Homarr)
- status.selfwize.com (Gatus)
- home.selfwize.com (Homeseer)
- cameras.selfwize.com (Blue Iris)

Note: Homeseer and Blue Iris may have been partially available since they run natively, but were inaccessible via the tunnel due to Traefik being down.

---

## Impact Assessment

| Category | Impact |
|----------|--------|
| Downtime | ~4.5 hours |
| Data Loss | None (containers restarted with persistent volumes) |
| External Access | All tunnel endpoints unreachable |
| User Impact | Unable to access any self-hosted services |
| Monitoring | No alerts generated (Gatus was also down) |

---

## Resolution Steps

1. Identified Docker daemon not responding:
   ```
   docker ps
   # Error: failed to connect to docker API at npipe:////./pipe/dockerDesktopLinuxEngine
   ```

2. Confirmed `com.docker.service` was stopped:
   ```powershell
   Get-Service -Name 'com.docker.service'
   # Status: Stopped
   ```

3. Restarted Docker Desktop application:
   ```powershell
   Stop-Process -Name 'Docker Desktop' -Force
   Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
   ```

4. Waited for initialization (~30 seconds) and verified:
   ```
   docker ps
   # All 11 containers running
   ```

---

## Lessons Learned

### 1. Docker Service Should Be Automatic

The `com.docker.service` should start automatically with Windows to ensure Docker is fully operational after reboots.

### 2. Monitoring Cannot Monitor Itself

Gatus (our monitoring solution) runs in Docker. When Docker is down, we lose visibility into all services including Docker itself. This creates a blind spot.

### 3. No External Health Check

There was no external notification that services were down. The user discovered the outage manually.

### 4. Container Restart Policies Are Ineffective Without Docker

All containers have `restart: unless-stopped` policies, but these only work when the Docker daemon is running.

---

## Preventive Measures

### Immediate Actions

#### 1. Change Docker Service to Automatic Startup (Requires Admin)

```powershell
# Run as Administrator
Set-Service -Name 'com.docker.service' -StartupType Automatic
```

#### 2. Configure Docker Desktop for Reliability

Open Docker Desktop Settings:
- General > "Start Docker Desktop when you sign in" (already enabled)
- General > Ensure WSL 2 backend is stable

### Short-Term Actions

#### 3. Create Docker Health Check Script

Create `scripts/check-docker-health.ps1`:
```powershell
# Quick Docker health check
$dockerOk = $false
try {
    $result = docker ps 2>&1
    if ($LASTEXITCODE -eq 0) { $dockerOk = $true }
} catch {}

if (-not $dockerOk) {
    Write-Warning "Docker is not responding - attempting restart"
    Stop-Process -Name 'Docker Desktop' -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
    Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
    Start-Sleep -Seconds 60
    docker ps
}
```

#### 4. Add Windows Task Scheduler Watchdog

Create a scheduled task that runs every 5 minutes to verify Docker is operational and restart if needed.

### Long-Term Actions

#### 5. External Uptime Monitoring

Set up an external monitoring service (e.g., UptimeRobot, Healthchecks.io) to monitor public endpoints:
- status.selfwize.com (Gatus health endpoint)
- stuff.selfwize.com (Snipe-IT)

This provides alerting even when internal monitoring is down.

#### 6. Document Startup Dependencies

Update `start-here.md` with:
- Required service startup order
- Health check commands
- Recovery procedures

#### 7. Consider Systemd-Style Process Manager

For critical services, consider running a lightweight process manager that can restart Docker Desktop if it crashes.

---

## Checklist: Post-Reboot Verification

Add to operational runbook:

- [ ] Verify Docker daemon is responsive: `docker ps`
- [ ] Verify all expected containers are running (11 containers)
- [ ] Verify external endpoints are accessible
- [ ] Verify Gatus is showing all services healthy
- [ ] Check `com.docker.service` is Running

---

## Recommendations Summary

| Priority | Action | Owner | Status |
|----------|--------|-------|--------|
| P0 | Set `com.docker.service` to Automatic | User (Admin required) | **DONE** (2025-12-30) |
| P1 | Create Docker health check script | Repo | **DONE** - `scripts/check-docker-health.ps1` |
| P1 | Add to scheduled tasks as watchdog | User | Optional |
| P2 | Set up external uptime monitoring | User | Optional |
| P2 | Update start-here.md with recovery steps | Repo | **DONE** |
| P3 | Research process manager options | User | Future |

**GitHub Issue:** [#2](https://github.com/score-ra/ra-infrastructure/issues/2) - Closed 2025-12-30

---

## Appendix A: Quick Recovery Commands

```powershell
# Check Docker status
docker ps 2>&1

# Check Docker service
Get-Service -Name 'com.docker.service'

# Restart Docker Desktop (non-admin)
Stop-Process -Name 'Docker Desktop' -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
Start-Sleep -Seconds 60
docker ps

# Start Docker service (requires admin)
Start-Service -Name 'com.docker.service'

# Verify all containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

---

## Appendix B: Docker Desktop Startup Flow

```
Windows Boot
    │
    ├─► com.docker.service (Manual) ──► Does NOT start
    │
    └─► Docker Desktop.exe (Auto via Registry)
            │
            └─► Attempts to connect to service
                    │
                    └─► Hangs indefinitely waiting for backend
```

**Correct Flow (after fix):**

```
Windows Boot
    │
    ├─► com.docker.service (Automatic) ──► Starts backend
    │
    └─► Docker Desktop.exe (Auto via Registry)
            │
            └─► Connects to running service ──► Success
                    │
                    └─► Containers with restart policy start
```

---

## Sign-Off

| Role | Name | Date |
|------|------|------|
| Incident Handler | Claude Code Assistant | 2025-12-30 |
| Repository Owner | User | Pending |
