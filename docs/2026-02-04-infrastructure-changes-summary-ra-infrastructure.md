# Infrastructure Changes Summary — ra-infrastructure

> Date: 2026-02-04
> Scope: selfwize.com vertical — standalone deployment on BEAST (192.168.68.74)
> Context: [Full migration summary](../../../device-deployments/docs/2026-02-04-infrastructure-changes-summary.md) in `device-deployments` repo

---

## What Changed Today

### New Standalone Stack Created

ra-infrastructure was separated out of sc-infrastructure into its own standalone project. Previously, selfwize.com services were temporarily merged into sc-infrastructure during migration from the old PC (192.168.68.56). Today they were split back out with full independence.

### Services Deployed (10 containers)

| Service | Container | Port | Status |
|---------|-----------|------|--------|
| Traefik | ra_traefik | 8070 | Live |
| PostgreSQL (inventory) | ra_postgres | 5433 | Live |
| PostgreSQL (event_log) | ra_eventlog_db | 5434 | Live |
| MySQL 8.0 (Snipe-IT) | ra_mysql | 3307 | Live |
| Snipe-IT | ra_snipeit | 8083 | Live |
| Daily Event Log | ra_eventlog | 8089 | Live |
| Fasten Health | ra_fasten | 9091 | Live (standby) |
| Selfwize Dashboard | ra_dashboard | 8088 | Live |
| Gatus | ra_gatus | 8085 | Live |
| pgAdmin | ra_pgadmin | 8084 | Live |

### External URLs (via Cloudflare Tunnel `1f014ff9`)

| URL | Service | Status |
|-----|---------|--------|
| https://stuff.selfwize.com | Snipe-IT | Live (302) |
| https://wellness.selfwize.com | Fasten Health | Live (302) |
| https://events.selfwize.com | Daily Event Log | Live (200) |
| https://dash.selfwize.com | Dashboard | Live (200) |
| https://home.selfwize.com | Homeseer (old PC) | Live (200) |
| https://status.selfwize.com | Gatus | Live (200) |
| https://cameras.selfwize.com | Blue Iris (old PC) | Backlog |

### Data Migrated

| Source | Data | Method |
|--------|------|--------|
| Snipe-IT MySQL | 54 tables + 17MB uploads | SQL dump + tar archive |
| Inventory PostgreSQL | 17 tables, 71KB | pg_dump / pg_restore |
| Daily Event Log PostgreSQL | 442 events, 318 contacts (event_log schema) | SQL export |
| Fasten Health | 170MB SQLite database | File copy |

### Cloudflare Tunnel

- Tunnel UUID: `1f014ff9-68ae-4033-bacf-e058b91d2df4`
- Windows service: `cloudflared-selfwize`
- Config: `C:\Program Files (x86)\cloudflared\config-selfwize.yml`
- Ingress: `*.selfwize.com` -> `localhost:8070`
- DNS: Wildcard + individual CNAMEs in selfwize.com zone -> tunnel

### Gatus Monitoring

14 endpoints configured (8 internal + 6 external) in `gatus/config/config.yaml`.

### Files Created/Modified

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Full stack definition (10 services) |
| `.env` | Credentials (not committed) |
| `traefik/dynamic/services.yml` | 7 Traefik routes |
| `gatus/config/config.yaml` | 14 monitoring endpoints |
| `dashboard/index.html` | Dashboard SPA |
| `dashboard/app.js` | Dashboard logic |
| `dashboard/services.json` | Service directory data |
| `database/postgresql/init/01-inventory-init.sql` | Inventory DB schema |
| `data/` | Imported dumps (gitignored) |

---

## Infrastructure Ownership

**This repository is the single source of truth for the entire `selfwize.com` infrastructure vertical.**

### Scope of Responsibility

- All 10 containers defined in `docker-compose.yml`
- All Traefik routing for `*.selfwize.com` (via `traefik/dynamic/services.yml`)
- All Gatus monitoring for selfwize services (via `gatus/config/config.yaml`)
- Database management for inventory (PG :5433), event_log (PG :5434), and Snipe-IT (MySQL :3307)
- Dashboard SPA content and configuration
- Coordination with old PC for proxied services (Homeseer, Blue Iris)

### Boundary with sc-infrastructure

| Concern | Owner |
|---------|-------|
| `*.selfwize.com` routing, DNS, tunnel | ra-infrastructure |
| `*.symphonycorelabs.com` routing, DNS, tunnel | sc-infrastructure |
| BEAST host-level concerns (Docker, networking) | Shared — coordinate |
| Cloudflare account (both zones) | Shared — coordinate |
| Port allocation on BEAST | Shared — coordinate (see port table above) |

### Infrastructure Issue Resolution

This repo is responsible for triaging and resolving infrastructure issues reported by any service running under the selfwize.com vertical, including:

- Container health failures or restart loops
- Traefik routing issues for selfwize.com subdomains
- Database connectivity or performance issues (PG :5433, PG :5434, MySQL :3307)
- Cloudflare tunnel connectivity for selfwize-dev tunnel
- Gatus monitoring alerts for selfwize endpoints
- Proxied service issues (Homeseer/Blue Iris routing from old PC)

---

## Health Check Required

Before this infrastructure is considered production-ready, conduct a repo health check to confirm:

- [ ] All 10 containers healthy (`docker compose ps`)
- [ ] All 7 Traefik routes responding (test each `*.selfwize.com` subdomain)
- [ ] All 14 Gatus endpoints green (`http://localhost:8085`)
- [ ] Database connectivity verified (PG :5433, PG :5434, MySQL :3307)
- [ ] Cloudflare tunnel stable (`cloudflared-selfwize` Windows service running)
- [ ] External URLs reachable (test from outside BEAST network)
- [ ] `.env` file present with all required credentials
- [ ] Data integrity confirmed (Snipe-IT assets, inventory records, event log entries)
- [ ] Backup strategy defined for all databases
- [ ] CLAUDE.md or equivalent repo instructions exist and are current

---

## Open Items

- [ ] **cameras.selfwize.com**: DNS + Traefik route configured, but Blue Iris HTTPS (192.168.68.56:443) unreachable from Docker. Service may be replaced. Revisit when replacement is deployed.
- [ ] **Fasten Health**: App in STANDBY mode — needs encryption key setup via UI at https://wellness.selfwize.com
- [ ] **Old PC decommission**: Stop legacy containers (daily-event-log, event-log-db, snipeit-app, snipeit-db, etc.) after validation period. Do NOT stop Homeseer or Blue Iris.
- [ ] **Repo health check**: Complete the checklist above and confirm readiness.
