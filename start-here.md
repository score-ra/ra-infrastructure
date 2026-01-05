# Start Here - ra-infrastructure

> **Read this file at the start of every session. Update it at the end.**

## Current Status

| Field | Value |
|-------|-------|
| **Phase** | Operations Ready |
| **Last Updated** | 2025-12-30 |
| **Purpose** | Central infrastructure database for other repositories |

## Session Context (2025-12-30)

### Docker Service Outage - RESOLVED

**Incident:** All Docker services were unavailable after system reboot at 5:00 AM.

**Root Cause:** `com.docker.service` Windows service is set to Manual startup. Docker Desktop UI started but backend service did not.

**Resolution:** Restarted Docker Desktop, all 11 containers recovered.

**Post-Mortem:** [docs/post-mortems/2025-12-30-docker-service-outage.md](docs/post-mortems/2025-12-30-docker-service-outage.md)

**Files Created:**
- `docs/post-mortems/2025-12-30-docker-service-outage.md` - Full RCA and incident report
- `scripts/check-docker-health.ps1` - Health check and auto-recovery script
- `start-here.md` - Added Docker Troubleshooting section

**Action Completed:**
- [x] Set Docker service to Automatic startup ([Issue #2](https://github.com/score-ra/ra-infrastructure/issues/2) - Closed)

**Verification Completed (2025-12-30):**
- [x] Docker daemon responds: `docker ps` - All 11 containers running
- [x] External endpoints accessible (stuff.selfwize.com, wellness.selfwize.com)
- [x] Gatus showing healthy (status.selfwize.com)
- [x] Cloudflared tunnel running (Automatic startup)

**Root Cause Clarification:**
The `com.docker.service` being set to Manual is **expected behavior** with Docker Desktop + WSL2. Docker Desktop manages this service internally and resets it to Manual. The real issue was that Docker Desktop only starts on **user login**, not system boot.

**Permanent Fix Applied:**
- [x] Windows auto-login configured for user `ranand`
- Boot sequence: Power on → Windows → Auto-login → Docker Desktop starts → Containers start
- This ensures services recover automatically after power outages
- **Change Request:** [CR-001-windows-auto-login.md](docs/change-requests/CR-001-windows-auto-login.md)

### Reboot Test - PENDING

**Purpose:** Verify auto-login and Docker auto-recovery work after reboot.

**Pre-Reboot Checklist:**
- [x] Auto-login configured: `AutoAdminLogon=1`, `DefaultUsername=ranand`
- [x] Docker Desktop auto-start enabled (HKCU registry)
- [x] All containers have restart policies
- [x] Changes committed and pushed

**Post-Reboot Verification (run after reboot):**
```powershell
# 1. Verify auto-login worked (should show current user)
whoami

# 2. Check Docker is responding
docker ps

# 3. Count running containers (expect 11)
docker ps --format "{{.Names}}" | Measure-Object

# 4. Check external endpoints
curl.exe -s -o NUL -w "%{http_code}" https://status.selfwize.com
curl.exe -s -o NUL -w "%{http_code}" https://stuff.selfwize.com
curl.exe -s -o NUL -w "%{http_code}" https://wellness.selfwize.com

# 5. Verify cloudflared tunnel
Get-Service cloudflared
```

**Expected Results:**
- [ ] Windows auto-logged in as `ranand` (no manual login required)
- [ ] Docker daemon responsive
- [ ] All 11 containers running
- [ ] External endpoints returning 200/302
- [ ] Cloudflared service running

**To initiate reboot:**
```powershell
Restart-Computer -Force
```

---

## Previous Session Context (2025-12-20)

### Cloudflare Tunnel Setup - VERIFIED WORKING ✓

**What was done:**
1. Registered selfwize.com with Cloudflare (nameservers: arushi/thomas)
2. Installed cloudflared via winget
3. Created tunnel `selfwize-dev` (ID: `1f014ff9-68ae-4033-bacf-e058b91d2df4`)
4. Created DNS routes for subdomains
5. Installed Windows service with registry fix
6. Enabled "Always Use HTTPS" in Cloudflare
7. **Fixed port mappings** (was pointing to wrong ports)
8. **Added noTLSVerify** for Fasten Health (self-signed cert)

**E2E Validation Completed (2025-12-20):**
- stuff.selfwize.com -> Snipe-IT (port 8082) - WORKING
- wellness.selfwize.com -> Fasten Health (port 9090, HTTPS) - WORKING

### Cloudflare Access Security - IMPLEMENTED ✓

**What was done:**
1. Created PRD-007 documenting Zero Trust authentication requirements
2. Developed comprehensive implementation guide with step-by-step instructions
3. Created PowerShell verification script (verify-cloudflare-access.ps1)
4. Updated CLOUDFLARE-TUNNEL-SETUP.md making Phase 9 MANDATORY
5. **Implemented Access via Cloudflare dashboard** (manual configuration)
6. Created two Access applications:
   - Wellness Portal (wellness.selfwize.com) - PROTECTED
   - Asset Inventory (stuff.selfwize.com) - PROTECTED
7. Configured email OTP authentication with authorized user allowlist
8. Tested authentication flow - SSO working correctly

**Security Status:**
- ✅ Edge-level authentication enabled
- ✅ Health records (Fasten) protected by Zero Trust
- ✅ Infrastructure data (Snipe-IT) protected by Zero Trust
- ✅ Unauthorized access blocked at Cloudflare edge
- ✅ Audit logs available in Zero Trust dashboard

### Files Modified This Session:
- `docs/prds/PRD-007-cloudflare-access-security.md` - **NEW** Requirements for Zero Trust authentication
- `docs/guides/CLOUDFLARE-ACCESS-IMPLEMENTATION.md` - **NEW** Step-by-step implementation guide
- `scripts/verify-cloudflare-access.ps1` - **NEW** Verification script for Access status
- `docs/guides/CLOUDFLARE-TUNNEL-SETUP.md` - Updated Phase 9 as MANDATORY, added verification
- `start-here.md` - Added Access status column and pending action items

## What This Repository Is

**ra-infrastructure** is a standalone database infrastructure and CLI for managing:
- **Organizations** - Multi-tenant support
- **Sites** - Physical locations
- **Zones** - Logical areas within sites
- **Devices** - All infrastructure devices
- **Networks** - Network configurations and IP allocations

This database is designed to be consumed by **other repositories** for their device/network data needs.

## What's Done

- [x] Database schema (4 migrations)
- [x] Docker infrastructure (PostgreSQL 16 + pgAdmin)
- [x] CLI with Typer (`inv` command)
- [x] Full CRUD for all entities (org, site, zone, device, network)
- [x] Repository pattern for db layer
- [x] Pydantic models for validation
- [x] 79 tests passing
- [x] **Backup & DR infrastructure** (PRD-005)
  - Daily local backups (2:00 AM) with 30-day retention
  - Weekly remote backups (Sunday 3:00 AM) to Google Drive with 6-month retention
  - Health monitoring every 5 minutes with email alerts
  - Disaster recovery runbook with 4-tier procedures
  - Restore script with safety backups
  - Backup verification fixed (2025-12-10) - backups now create valid, restorable dumps
  - **Fasten Health integration** (2025-12-10) - consolidated backup supports `-IncludeFasten` flag
  - **MySQL (home automation)** (2025-12-14) - consolidated backup supports `-IncludeMySQL` flag
  - **Pending**: End-to-end DR test on separate device

## For External Repositories

See **[docs/DATABASE.md](docs/DATABASE.md)** for:
- Connection details
- Schema documentation
- Example queries
- Python connection examples

## Infrastructure Status

| Component | Status |
|-----------|--------|
| PostgreSQL | `localhost:5432` |
| MySQL | `localhost:3306` |
| pgAdmin | `localhost:5050` |
| **Traefik** | `localhost:80` (tunnel), `localhost:8080` (dashboard) |
| **Homarr** | `https://dash.selfwize.com` or `localhost:7575` |
| **Gatus Dashboard** | `https://status.selfwize.com` or `localhost:8083` |
| Database (PostgreSQL) | `inventory` |
| Database (MySQL) | `homeautomation` |
| User (PostgreSQL) | `inventory` |
| User (MySQL) | `homeautomation` |
| Backups | `D:\Backups\ra-infrastructure\daily\` |
| MySQL Backups | `D:\Backups\homeautomation-mysql\daily\` |
| Fasten Backups | `D:\Backups\fasten-health\` |
| Remote Backups | Google Drive: `ra-infrastructure-backup` |

## Quick Commands

```powershell
# Infrastructure self-check (all services)
inv system selfcheck

# Start database
cd docker && docker-compose up -d

# Check status
inv db stats

# Install CLI
cd cli && pip install -e ".[dev]"

# Run tests
cd cli && pytest

# Backup ra-infrastructure only
.\scripts\backup.ps1 -Type daily

# Backup ra-infrastructure + MySQL (home automation)
.\scripts\backup.ps1 -Type daily -IncludeMySQL

# Backup ra-infrastructure + Fasten Health
.\scripts\backup.ps1 -Type daily -IncludeFasten

# Backup everything (ra-infrastructure + MySQL + Fasten)
.\scripts\backup.ps1 -Type daily -IncludeMySQL -IncludeFasten

# Weekly backup with Google Drive upload
.\scripts\backup.ps1 -Type weekly -IncludeMySQL -IncludeFasten

# Start Traefik reverse proxy (PRD-008)
cd traefik && docker-compose -f docker-compose.traefik.yml up -d

# Start Homarr dashboard
cd homarr && docker-compose -f docker-compose.homarr.yml up -d

# Start Gatus monitoring dashboard
cd gatus && docker-compose -f docker-compose.gatus.yml up -d

# View Traefik dashboard (routes, services)
Start-Process "http://localhost:8080"

# Stop all proxy infrastructure
docker stop traefik homarr ra-status
```

## Key Documents

| Document | Purpose |
|----------|---------|
| [docs/SELF-CHECK.md](docs/SELF-CHECK.md) | **Infrastructure health check guide** |
| [docs/DATABASE.md](docs/DATABASE.md) | **External repository integration guide** |
| [docs/DR-RUNBOOK.md](docs/DR-RUNBOOK.md) | **Disaster recovery procedures** |
| [docs/RECOVERY-QUICKSTART.md](docs/RECOVERY-QUICKSTART.md) | One-page recovery reference |
| [docs/prds/PRD-005-infrastructure-operations.md](docs/prds/PRD-005-infrastructure-operations.md) | Backup/DR requirements |
| [docs/prds/PRD-007-service-monitoring-dashboard.md](docs/prds/PRD-007-service-monitoring-dashboard.md) | Gatus monitoring dashboard |
| [docs/prds/PRD-008-reverse-proxy-infrastructure.md](docs/prds/PRD-008-reverse-proxy-infrastructure.md) | **Traefik + Homarr setup** |
| [docs/guides/TRAEFIK-SETUP.md](docs/guides/TRAEFIK-SETUP.md) | Traefik reverse proxy guide |
| [traefik/README.md](traefik/README.md) | Traefik quick start |
| [homarr/README.md](homarr/README.md) | Homarr dashboard guide |
| [gatus/README.md](gatus/README.md) | Gatus quick start guide |
| [CLAUDE.md](CLAUDE.md) | Development instructions |

## Gatus Monitoring Dashboard

Visual status monitoring for all infrastructure services.

**PRD:** [docs/prds/PRD-007-service-monitoring-dashboard.md](docs/prds/PRD-007-service-monitoring-dashboard.md)

**Dashboard:** http://localhost:8083

| Service | Check Type | Interval |
|---------|------------|----------|
| PostgreSQL | TCP 5432 | 30s |
| MySQL | TCP 3306 | 30s |
| pgAdmin | HTTP | 60s |
| Snipe-IT (External) | HTTPS + SSL | 60s |
| Fasten Health (External) | HTTPS + SSL | 60s |

**Setup:**
```powershell
# 1. Copy environment template
Copy-Item gatus\.env.template gatus\.env

# 2. Configure SMTP (copy from config/monitoring.env)
notepad gatus\.env

# 3. Start Gatus
cd gatus && docker-compose -f docker-compose.gatus.yml up -d

# 4. Access dashboard
Start-Process "http://localhost:8083"
```

## Cloudflare Tunnel (External Access)

Expose local services to the internet via custom domains.

**Domain:** `selfwize.com`
**Tunnel:** `selfwize-dev` (ID: `1f014ff9-68ae-4033-bacf-e058b91d2df4`)
**Status:** VERIFIED WORKING (2025-12-20)

### Architecture (PRD-008)

```
Internet → Cloudflare (*.selfwize.com) → Tunnel → Traefik:80 → Services
```

All `*.selfwize.com` traffic flows through Traefik reverse proxy. To add new services, just add Docker labels - no Cloudflare changes needed!

| Subdomain | Purpose | Routed By | Access Status |
|-----------|---------|-----------|---------------|
| dash.selfwize.com | Homarr Dashboard | Traefik (Docker) | Optional |
| status.selfwize.com | Gatus Monitoring | Traefik (Docker) | Optional |
| stuff.selfwize.com | Snipe-IT Asset Inventory | Traefik (External) | ✓ **ENABLED** |
| wellness.selfwize.com | Fasten Health Records | Traefik (External) | ✓ **ENABLED** |

**✅ SECURITY IMPLEMENTED:** Cloudflare Access (Zero Trust authentication) is now protecting both active subdomains.
- **Team:** symphonycore (symphonycore.cloudflareaccess.com)
- **Protected Applications:** Wellness Portal, Asset Inventory
- **Authentication:** Email OTP with authorized user allowlist
- **Session Duration:** 24 hours
- **Implementation Date:** 2025-12-20
- **PRD:** [PRD-007: Cloudflare Access Security](docs/prds/PRD-007-cloudflare-access-security.md)

**Config locations:**
- Service config: `C:\Program Files (x86)\cloudflared\config.yml`
- Credentials: `C:\Program Files (x86)\cloudflared\1f014ff9-68ae-4033-bacf-e058b91d2df4.json`
- User config: `C:\Users\ranand\.cloudflared\config.yml`

**Setup guide:** [docs/guides/CLOUDFLARE-TUNNEL-SETUP.md](docs/guides/CLOUDFLARE-TUNNEL-SETUP.md)

```powershell
# Service management
Get-Service cloudflared
Start-Service cloudflared
Stop-Service cloudflared
Restart-Service cloudflared

# Check tunnel status
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel info selfwize-dev

# Fresh install (run as Admin)
.\scripts\install-cloudflared.ps1

# Service-only setup (if tunnel already exists)
.\scripts\setup-cloudflared-service.ps1

# Verify Cloudflare Access protection
.\scripts\verify-cloudflare-access.ps1
```

## Docker Troubleshooting & Recovery

**Related Incident:** [2025-12-30-docker-service-outage.md](docs/post-mortems/2025-12-30-docker-service-outage.md)

### Quick Health Check

```powershell
# Check if Docker is responding
docker ps

# Run automated health check
.\scripts\check-docker-health.ps1

# Auto-recover if unhealthy
.\scripts\check-docker-health.ps1 -AutoRestart
```

### Post-Reboot Verification Checklist

After any system reboot, verify:

- [ ] Docker daemon is responsive: `docker ps`
- [ ] All 11 containers are running
- [ ] External endpoints accessible (stuff.selfwize.com, wellness.selfwize.com)
- [ ] Gatus showing all services healthy (status.selfwize.com)

### Manual Recovery Steps

If Docker is not responding after reboot:

```powershell
# 1. Check Docker service status
Get-Service -Name 'com.docker.service'

# 2. If stopped, restart Docker Desktop
Stop-Process -Name 'Docker Desktop' -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
Start-Sleep -Seconds 60

# 3. Verify recovery
docker ps
```

### Auto-Recovery Configuration (IMPLEMENTED)

Docker Desktop + WSL2 requires user login to start. Windows auto-login is configured:

```powershell
# Verify auto-login is enabled
Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' | Select-Object AutoAdminLogon, DefaultUsername

# Should show:
# AutoAdminLogon: 1
# DefaultUsername: ranand
```

**Boot sequence:**
1. Power on → Windows starts
2. Auto-login as `ranand`
3. Docker Desktop starts (via HKCU Run registry)
4. All containers start automatically

**Note:** `Set-Service -StartupType Automatic` does NOT work with Docker Desktop WSL2 mode - Docker Desktop resets it to Manual.

---

## Notes

- PostgreSQL runs on localhost:5432 (inventory database)
- MySQL runs on localhost:3306 (homeautomation database for home automation systems)
- pgAdmin available at localhost:5050
- GitHub repo: https://github.com/score-ra/ra-infrastructure

## MySQL (Home Automation) Connection Details

| Setting | Value |
|---------|-------|
| Host | `localhost` |
| Port | `3306` |
| Database | `homeautomation` |
| Username | `homeautomation` |
| Password | `homeautomation_dev_password` |
| Root Password | `mysql_root_dev_password` |

Connection string: `mysql://homeautomation:homeautomation_dev_password@localhost:3306/homeautomation`
