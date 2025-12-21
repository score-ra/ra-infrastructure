# Start Here - ra-infrastructure

> **Read this file at the start of every session. Update it at the end.**

## Current Status

| Field | Value |
|-------|-------|
| **Phase** | Operations Ready |
| **Last Updated** | 2025-12-21 |
| **Purpose** | Central infrastructure database for other repositories |

## Session Context (2025-12-20)

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
| **Gatus Dashboard** | `localhost:8083` |
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

# Start Gatus monitoring dashboard
cd gatus && docker-compose -f docker-compose.gatus.yml up -d

# Stop Gatus
docker-compose -f gatus/docker-compose.gatus.yml down

# View Gatus logs
docker-compose -f gatus/docker-compose.gatus.yml logs -f
```

## Key Documents

| Document | Purpose |
|----------|---------|
| [docs/DATABASE.md](docs/DATABASE.md) | **External repository integration guide** |
| [docs/DR-RUNBOOK.md](docs/DR-RUNBOOK.md) | **Disaster recovery procedures** |
| [docs/RECOVERY-QUICKSTART.md](docs/RECOVERY-QUICKSTART.md) | One-page recovery reference |
| [docs/prds/PRD-005-infrastructure-operations.md](docs/prds/PRD-005-infrastructure-operations.md) | Backup/DR requirements |
| [docs/prds/PRD-007-service-monitoring-dashboard.md](docs/prds/PRD-007-service-monitoring-dashboard.md) | Gatus monitoring dashboard |
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

| Subdomain | Purpose | Local Target | Tunnel Status | Access Status |
|-----------|---------|--------------|---------------|---------------|
| stuff.selfwize.com | Snipe-IT Asset Inventory | localhost:8082 | ✓ WORKING | ✓ **ENABLED** |
| wellness.selfwize.com | Fasten Health Records | https://localhost:9090 | ✓ WORKING | ✓ **ENABLED** |
| dash.selfwize.com | Gatus Status Dashboard | localhost:8083 | ✓ WORKING | ✓ **ENABLED** |
| app.selfwize.com | Main Dashboard | localhost:3000 | Not configured | N/A |
| api.selfwize.com | API Endpoint | localhost:8080 | Not configured | N/A |

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

## Notes

- PostgreSQL runs on localhost:5432 (inventory database)
- MySQL runs on localhost:5432 (homeautomation database for home automation systems)
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
