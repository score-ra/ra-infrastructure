# Infrastructure Migration Inventory

> **Generated**: 2026-02-04
> **Source PC**: 31NT (Windows 11, Docker Desktop)
> **Domain**: selfwize.com
> **Purpose**: Complete inventory of all infrastructure components to support migration to a new PC.

---

## 1. Executive Summary

| Metric | Count |
|--------|-------|
| Running Docker containers | 12 |
| Stopped/exited containers | 0 |
| Docker Compose projects | 5 |
| Source repositories | 13 |
| Docker volumes | 27 |
| Custom Docker networks | 8 |
| Docker images | 19 |
| Databases (active) | 5 |
| Cloudflare Tunnels | 3 (1 actively connected) |
| Cloudflare subdomain routes | 8 |
| Windows services | 2 (both STOPPED) |
| External network services | 2 (Homeseer, Blue Iris on 192.168.68.56) |
| Active backups | PostgreSQL daily (D:\backups) |
| Stale backups | MySQL (last: 2025-12-14) |
| Total memory in use | ~2.6 GB across all containers |

**Overall health**: All 12 containers running, 4 with health checks passing. No exited or crashed containers.

---

## 2. Active Docker Containers (12)

| Container | Image | Ports | Status | Health | Memory | Compose Project | Source Repo |
|-----------|-------|-------|--------|--------|--------|----------------|-------------|
| inventory-db | postgres:16-alpine | 5432:5432 | Up | healthy | 52.6 MiB / 512M | docker | ra-infrastructure |
| inventory-pgadmin | dpage/pgadmin4:latest | 5050:80 | Up | — | 233.1 MiB / 256M | docker | ra-infrastructure |
| homeautomation-db | mysql:5.7 | 3306:3306 | Up | healthy | 189.4 MiB / 512M | docker | ra-infrastructure |
| event-log-db | postgres:16-alpine | 5433:5432 | Up | healthy | 28.8 MiB / 512M | docker | ra-infrastructure |
| gramps-web | ghcr.io/gramps-project/grampsweb:latest | 5000:5000 | Up | — | 1.39 GiB / 2G | docker | ra-infrastructure |
| snipeit-app | snipe/snipe-it:latest | 8082:80 | Up | — | 90.0 MiB / unlim | docker | snipeit-asset-management |
| snipeit-db | mysql:8.0 | (internal 3306) | Up | — | 413.2 MiB / unlim | docker | snipeit-asset-management |
| daily-event-log | daily-event-log:latest | 8000:8000 | Up | healthy | 102.3 MiB / unlim | docker | ra-life-tracker (built) |
| traefik | traefik:v3.2 | 80:80, 8080:8080 | Up | — | 47.2 MiB / 256M | traefik | ra-infrastructure |
| ra-status | twinproduction/gatus:latest | 8083:8080 | Up | — | 26.1 MiB / 128M | gatus | ra-infrastructure |
| selfwize-dashboard | nginx:alpine | 8088:80 | Up | — | 6.5 MiB / 32M | dashboard | ra-infrastructure |
| fasten-deploy-fasten-prod-1 | ghcr.io/fastenhealth/fasten-onprem:main | 9090:8080 | Up | — | 66.1 MiB / unlim | fasten-deploy | fasten-deploy |

All containers use `restart: unless-stopped` policy.

---

## 3. Inactive / Orphaned Components

### Volumes without running containers

| Component | Evidence | Status |
|-----------|----------|--------|
| **Homarr** (old) | Volumes: `homarr_appdata`, `homarr_config`, `homarr_data`, `homarr_icons` | No compose file found. Images exist: `ghcr.io/ajnart/homarr:latest` (1.52 GB) and `ghcr.io/homarr-labs/homarr:latest` (582 MB). Replaced by selfwize-dashboard. |
| **Gramps Web** (old volumes) | Volumes: `gramps-web_gramps_*` (7 volumes) vs active `gramps_*` (8 volumes) | Duplicate set. Active containers use `gramps_*` prefix. `gramps-web_*` volumes are likely from an older compose project name. |

### Defined but not deployed

| Component | Compose File | Status |
|-----------|-------------|--------|
| **Home Assistant** | `windows-setup/scripts/setup/docker-compose.yml` | Image pulled (`homeassistant/home-assistant:stable`, 3.19 GB), not running |
| **Mosquitto** (MQTT) | `windows-setup/scripts/setup/docker-compose.yml` | Image pulled (`eclipse-mosquitto:latest`, 17.9 MB), not running |
| **Frigate NVR** | `homelab-deploy/stacks/frigate/docker-compose.yml` | Not deployed, no image pulled |
| **OpenHAB** | `homelab-deploy/stacks/elder-care/docker-compose.yml` | Not deployed, no image pulled |
| **MkDocs** | `homelab-deploy/stacks/elder-care/docker-compose.yml` | Not deployed, no image pulled |

### Unused images (no running container)

| Image | Tag | Size | Notes |
|-------|-----|------|-------|
| homeassistant/home-assistant | stable | 3.19 GB | Defined in windows-setup, never started |
| ghcr.io/homarr-labs/homarr | latest | 582 MB | Replaced by selfwize-dashboard |
| ghcr.io/ajnart/homarr | latest | 1.52 GB | Old version, replaced |
| eclipse-mosquitto | latest | 17.9 MB | Defined in windows-setup, never started |
| python | 3.11-slim | 188 MB | Build image for daily-event-log |
| alpine/sqlite | latest | 17.3 MB | Utility image |
| schemaspy/schemaspy | latest | 616 MB | Schema documentation tool |
| pallocchi/sqlcipher | latest | 690 MB | SQLite encryption utility |

---

## 4. Docker Compose Projects (5)

| Project | Status | Services | Config Files |
|---------|--------|----------|-------------|
| **docker** | running(7) | inventory-db, inventory-pgadmin, homeautomation-db, event-log-db, gramps-web, snipeit-app, snipeit-db | `ra-infrastructure/docker/docker-compose.yml`, `ra-infrastructure/docker/docker-compose.life-tracker.yml`, `snipeit-asset-management/docker/docker-compose.yml` |
| **dashboard** | running(1) | selfwize-dashboard | `ra-infrastructure/dashboard/docker-compose.dashboard.yml` |
| **fasten-deploy** | running(1) | fasten-deploy-fasten-prod-1 | `fasten-deploy/docker-compose.yml` |
| **gatus** | running(1) | ra-status | `ra-infrastructure/gatus/docker-compose.gatus.yml` |
| **traefik** | running(1) | traefik | `ra-infrastructure/traefik/docker-compose.traefik.yml` |

**Notes**:
- The "docker" project merges 3 compose files (ra-infrastructure core + life-tracker + snipeit) into one project with 7 services.
- `docker-compose.life-tracker.yml` is referenced in container labels but the **file has been deleted** from disk. The containers (event-log-db, gramps-web, daily-event-log) continue running but cannot be recreated via `docker compose up` without restoring this file. **Migration action**: Reconstruct this file before migration or extract the running config with `docker inspect`.

---

## 5. Databases (5)

### PostgreSQL Databases

| Database | Container | Port | Image | Volume | Backup Status |
|----------|-----------|------|-------|--------|---------------|
| `inventory` | inventory-db | 5432 | postgres:16-alpine | `inventory_postgres_data` | Active daily (D:\backups\ra-infrastructure\daily), last: 2026-02-04 |
| `event_log` | event-log-db | 5433 | postgres:16-alpine | `event_log_postgres_data` | **Not backed up** |

### MySQL Databases

| Database | Container | Port | Image | Volume | Backup Status |
|----------|-----------|------|-------|--------|---------------|
| `homeautomation` | homeautomation-db | 3306 | mysql:5.7 | `homeautomation_mysql_data` | **Stale** — last backup 2025-12-14 |
| `snipeit` | snipeit-db | (internal) | mysql:8.0 | `docker_snipeit-db` | **Not backed up** |

### Embedded / File-based

| Database | Container | Type | Location |
|----------|-----------|------|----------|
| Fasten Health DB | fasten-deploy-fasten-prod-1 | SQLite (bind mount) | `fasten-deploy/db/` |
| Gatus status history | ra-status | SQLite | Volume `ra_gatus_data` at `/data/gatus.db` |

---

## 6. Docker Volumes (27)

### Critical data volumes (back up before migration)

| Volume | Service | Data Criticality |
|--------|---------|-----------------|
| `inventory_postgres_data` | inventory-db | **HIGH** — Main inventory database |
| `event_log_postgres_data` | event-log-db | **HIGH** — Event log database |
| `homeautomation_mysql_data` | homeautomation-db | **HIGH** — Home automation database |
| `docker_snipeit-db` | snipeit-db | **HIGH** — Snipe-IT asset database |
| `docker_snipeit-data` | snipeit-app | **HIGH** — Snipe-IT uploads/attachments |
| `gramps_grampsdb` | gramps-web | **HIGH** — Family tree database |
| `gramps_media` | gramps-web | **HIGH** — Family photos/documents |
| `gramps_users` | gramps-web | **MEDIUM** — User accounts |
| `gramps_secret` | gramps-web | **MEDIUM** — Encryption keys |

### Operational volumes (can be regenerated)

| Volume | Service | Data Criticality |
|--------|---------|-----------------|
| `inventory_pgadmin_data` | inventory-pgadmin | LOW — Server config, re-setup easily |
| `ra_gatus_data` | ra-status | LOW — Status history, regenerates |
| `gramps_index` | gramps-web | LOW — Search index, rebuilds |
| `gramps_cache` | gramps-web | LOW — Cache, regenerates |
| `gramps_thumb_cache` | gramps-web | LOW — Thumbnails, regenerates |
| `gramps_tmp` | gramps-web | LOW — Temp files |

### Orphaned volumes (no running container)

| Volume | Original Service | Action |
|--------|-----------------|--------|
| `homarr_appdata` | Homarr (replaced) | Safe to delete |
| `homarr_config` | Homarr (replaced) | Safe to delete |
| `homarr_data` | Homarr (replaced) | Safe to delete |
| `homarr_icons` | Homarr (replaced) | Safe to delete |
| `gramps-web_gramps_cache` | Old Gramps project | Safe to delete (active uses `gramps_cache`) |
| `gramps-web_gramps_db` | Old Gramps project | **Verify empty** before deleting |
| `gramps-web_gramps_index` | Old Gramps project | Safe to delete |
| `gramps-web_gramps_media` | Old Gramps project | **Verify empty** before deleting |
| `gramps-web_gramps_secret` | Old Gramps project | **Verify empty** before deleting |
| `gramps-web_gramps_thumb` | Old Gramps project | Safe to delete |
| `gramps-web_gramps_tmp` | Old Gramps project | Safe to delete |
| `gramps-web_gramps_users` | Old Gramps project | **Verify empty** before deleting |

---

## 7. Docker Networks (8 custom)

| Network | Driver | Connected Containers |
|---------|--------|---------------------|
| `inventory_network` | bridge | inventory-db, inventory-pgadmin, homeautomation-db, selfwize-dashboard, traefik, ra-status |
| `docker_snipeit-network` | bridge | snipeit-app, snipeit-db |
| `event-log_default` | bridge | daily-event-log, event-log-db |
| `fasten-deploy_default` | bridge | fasten-deploy-fasten-prod-1 |
| `gramps-web_default` | bridge | gramps-web |
| `life_tracker_network` | bridge | (gramps-web, event-log-db — shared network for life tracker services) |
| `setup_default` | bridge | (from windows-setup compose, no active containers) |

**Default networks** (not custom): `bridge`, `host`, `none`

---

## 8. Docker Images (19)

| Repository | Tag | Size | In Use? |
|------------|-----|------|---------|
| daily-event-log | latest | 831 MB | Yes |
| ghcr.io/gramps-project/grampsweb | latest | 7.47 GB | Yes |
| twinproduction/gatus | latest | 72.5 MB | Yes |
| nginx | alpine | 82 MB | Yes |
| snipe/snipe-it | latest | 1.32 GB | Yes |
| ghcr.io/fastenhealth/fasten-onprem | main | 934 MB | Yes |
| postgres | 16-alpine | 394 MB | Yes (x2) |
| dpage/pgadmin4 | latest | 792 MB | Yes |
| mysql | 8.0 | 1.07 GB | Yes |
| mysql | 5.7 | 700 MB | Yes |
| traefik | v3.2 | 245 MB | Yes |
| homeassistant/home-assistant | stable | 3.19 GB | No |
| ghcr.io/homarr-labs/homarr | latest | 582 MB | No |
| ghcr.io/ajnart/homarr | latest | 1.52 GB | No |
| eclipse-mosquitto | latest | 17.9 MB | No |
| python | 3.11-slim | 188 MB | No (build dep) |
| alpine/sqlite | latest | 17.3 MB | No (utility) |
| schemaspy/schemaspy | latest | 616 MB | No (utility) |
| pallocchi/sqlcipher | latest | 690 MB | No (utility) |

**Total image storage**: ~19 GB
**Active images only**: ~12 GB

---

## 9. Windows Services

| Service | Status | Start Type | Purpose |
|---------|--------|-----------|---------|
| `Cloudflared` | **STOPPED** | Disabled | Cloudflare Tunnel connector (not used — tunnel runs via Cloudflare dashboard-managed connector) |
| `com.docker.service` | **STOPPED** | Manual | Docker Engine Windows service (not used — Docker Desktop runs as user process) |

### Auto-start programs

| Program | Mechanism | Notes |
|---------|-----------|-------|
| Docker Desktop | Registry `HKCU\...\Run` | Starts on user login. Path: `C:\Program Files\Docker\Docker\Docker Desktop.exe` |
| Cloudflare Tunnel | Cloudflare dashboard | Remotely managed connector; starts automatically via Docker Desktop or Cloudflare WARP |

---

## 10. Cloudflare Tunnel & DNS

### Domain: selfwize.com

### Tunnels

| Name | ID | Status | Connections |
|------|------|--------|------------|
| selfwize-dev | `1f014ff9-68ae-4033-bacf-e058b91d2df4` | **Active** (7 edge connections) | 2x EWR01, EWR07, EWR11, EWR14, EWR16, IAD12, IAD17 |
| orchestrator-webhooks | `a187ef23-900f-4a62-bf3d-9dc2ed10edc2` | **Inactive** (0 connections) | — |
| symphonycore-dev | `86fc275f-d004-4d5d-b2e8-24a6ea3eb006` | **Active** (4 edge connections) | 2x EWR08, EWR11, IAD02 |

### Subdomain Routes (via Traefik on port 80)

All traffic flows: `Internet → Cloudflare → Tunnel → Traefik :80 → Backend service`

| Subdomain | Backend Service | Backend Port | Cloudflare Access |
|-----------|----------------|-------------|-------------------|
| `stuff.selfwize.com` | Snipe-IT (snipeit-app) | 8082 | Yes (production) |
| `wellness.selfwize.com` | Fasten Health | 9090 | Yes (production) |
| `dash.selfwize.com` | Selfwize Dashboard | 8088 | No |
| `status.selfwize.com` | Gatus (ra-status) | 8083 | No |
| `family.selfwize.com` | Gramps Web | 5000 | No |
| `events.selfwize.com` | Daily Event Log | 8000 | No |
| `home.selfwize.com` | Homeseer (192.168.68.56) | 80 | No |
| `cameras.selfwize.com` | Blue Iris (192.168.68.56) | 443 (HTTPS) | No |

### Local config file

- `C:\Users\ranand\.cloudflared\config.yml` — **Outdated** (references old ports 3001/3002). Tunnel routes are managed via Cloudflare Zero Trust dashboard.
- Credentials file: `C:\Users\ranand\.cloudflared\1f014ff9-68ae-4033-bacf-e058b91d2df4.json`

### Cloudflare Access (Zero Trust)

- Protects: `stuff.selfwize.com`, `wellness.selfwize.com` (confirmed by HTTP 403 responses)
- Authentication: Configured via Cloudflare Zero Trust dashboard
- Not protecting: All other subdomains

---

## 11. External Network Services

These run on a separate machine (192.168.68.56), not on this PC. They are routed through Traefik via `host.docker.internal`.

| Service | Internal URL | External URL | Notes |
|---------|-------------|-------------|-------|
| **Homeseer** | `http://192.168.68.56:80` | `https://home.selfwize.com` | Home automation controller |
| **Blue Iris** | `https://192.168.68.56:443` | `https://cameras.selfwize.com` | Security camera NVR. Self-signed cert (Traefik uses `insecureSkipVerify`). |

**Migration note**: These services do not run on this PC. Only the Traefik routing config and Cloudflare tunnel DNS entries need to be migrated. The IP address (192.168.68.56) will remain the same on the local network.

---

## 12. Backup Infrastructure

### Active backups

| Target | Location | Schedule | Retention | Last Backup | Size |
|--------|----------|----------|-----------|-------------|------|
| PostgreSQL `inventory` | `D:\backups\ra-infrastructure\daily\` | Daily ~2:00 AM | Rolling (28 files present) | 2026-02-04 | ~13 KB each (.dump.gz) |

### Stale / broken backups

| Target | Location | Last Backup | Gap | Action Required |
|--------|----------|-------------|-----|----------------|
| MySQL `homeautomation` | `D:\backups\homeautomation-mysql\daily\` | **2025-12-14** | 52 days | Fix backup script or schedule |

### Not backed up

| Database | Container | Criticality | Action Required |
|----------|-----------|-------------|----------------|
| PostgreSQL `event_log` | event-log-db | HIGH | Set up daily backup |
| MySQL `snipeit` | snipeit-db | HIGH | Set up daily backup |
| SQLite (Fasten) | fasten-deploy | MEDIUM | Back up `fasten-deploy/db/` directory |
| SQLite (Gatus) | ra-status | LOW | Regenerates automatically |
| Gramps DB | gramps-web | HIGH | Back up `gramps_grampsdb` volume |

### Backup gaps identified

1. **event_log** database has no backup at all
2. **snipeit** database has no backup at all
3. **homeautomation** MySQL backup is 52 days stale
4. **Gramps Web** data (family tree + media) has no backup
5. **Fasten Health** SQLite DB has no backup
6. PostgreSQL `inventory` backup has occasional gaps (missing 2026-01-21, 2026-01-26 through 2026-01-28, 2026-01-30)

---

## 13. Resource Usage

Snapshot taken 2026-02-04:

| Container | CPU % | Memory | Memory Limit | Memory % | Net I/O | Block I/O |
|-----------|-------|--------|-------------|----------|---------|-----------|
| daily-event-log | 0.49% | 102.3 MiB | 3.8 GiB | 2.61% | 1.12 MB / 7.49 MB | 78.3 MB / 0B |
| inventory-pgadmin | 0.07% | 233.1 MiB | 256 MiB | **91.06%** | 570 kB / 6.07 MB | 141 MB / 15.8 MB |
| inventory-db | 0.00% | 52.6 MiB | 512 MiB | 10.27% | 334 kB / 260 kB | 39.1 MB / 8.51 MB |
| homeautomation-db | 0.25% | 189.4 MiB | 512 MiB | 36.99% | 677 kB / 963 kB | 45.6 MB / 13.2 MB |
| gramps-web | 0.01% | 1.39 GiB | 2 GiB | **69.26%** | 51.5 kB / 71.9 kB | 176 MB / 12.1 MB |
| event-log-db | 6.58% | 28.8 MiB | 512 MiB | 5.63% | 4.65 MB / 1.06 MB | 12.4 MB / 319 kB |
| selfwize-dashboard | 0.00% | 6.5 MiB | 32 MiB | 20.42% | 69 kB / 243 kB | 7.91 MB / 8.19 kB |
| fasten-deploy-fasten-prod-1 | 0.00% | 66.1 MiB | 3.8 GiB | 1.69% | 1.7 kB / 126B | 37.1 MB / 1.36 MB |
| traefik | 0.00% | 47.2 MiB | 256 MiB | 18.42% | 8.5 MB / 8.28 MB | 131 MB / 0B |
| ra-status | 0.12% | 26.1 MiB | 128 MiB | 20.42% | 89.1 MB / 17.9 MB | 44.3 MB / 347 MB |
| snipeit-app | 0.03% | 90.0 MiB | 3.8 GiB | 2.30% | 14.9 MB / 839 kB | 98.9 MB / 5.94 MB |
| snipeit-db | 3.23% | 413.2 MiB | 3.8 GiB | 10.55% | 841 kB / 14.9 MB | 113 MB / 18.9 MB |

**Hotspots**:
- `inventory-pgadmin` at 91% memory (256 MiB limit) — consider increasing limit
- `gramps-web` at 69% of 2 GiB — largest memory consumer

---

## 14. Source Repositories (13)

All located under `C:\Users\ranand\workspace\personal\software\`:

| Repository | Docker Services Defined | Currently Running? |
|------------|------------------------|-------------------|
| **ra-infrastructure** | inventory-db, inventory-pgadmin, homeautomation-db, event-log-db, gramps-web, traefik, ra-status, selfwize-dashboard | Yes (8 containers) |
| **snipeit-asset-management** | snipeit-app, snipeit-db | Yes (2 containers) |
| **fasten-deploy** | fasten-deploy-fasten-prod-1 | Yes (1 container) |
| **ra-life-tracker** | daily-event-log (custom-built image) | Yes (1 container) |
| **windows-setup** | homeassistant, mosquitto | No (defined, not deployed) |
| **homelab-deploy** | frigate, openhab, mosquitto, mkdocs | No (defined, not deployed) |
| **ra-home-automation** | (no compose files found) | — |
| **ra-personal-work-tech** | (no compose files found) | — |
| **ra-fasten-health** | (no compose files found) | — |
| **asha-care** | (no compose files found) | — |
| **network-tools** | (no compose files found) | — |
| **personal-os** | (no compose files found) | — |
| **property-design-toolkit** | (no compose files found) | — |

---

## 15. Credential Locations

**Values are NOT included in this document.** These are file paths only.

### .env files (contain secrets)

| File | Contains |
|------|----------|
| `ra-infrastructure/.env` | PostgreSQL credentials, MySQL credentials, pgAdmin credentials |
| `ra-infrastructure/gatus/.env` | SMTP credentials, alert email config |
| `ra-infrastructure/docker/.env.life-tracker` | Event log DB credentials, Gramps credentials, Gramps secret key |
| `snipeit-asset-management/docker/.env` | Snipe-IT DB credentials, APP_KEY, SMTP credentials |
| `snipeit-asset-management/config/.env` | Snipe-IT configuration |
| `fasten-deploy/.env` | Fasten Health configuration |

### Config files with embedded credentials

| File | Contains |
|------|----------|
| `fasten-deploy/config.yaml` | Fasten Health app configuration |
| `C:\Users\ranand\.cloudflared\config.yml` | Cloudflare tunnel ID reference |
| `C:\Users\ranand\.cloudflared\1f014ff9-...json` | Tunnel credentials JSON |

### External credential stores

| System | Notes |
|--------|-------|
| Cloudflare Zero Trust dashboard | Tunnel routes, Access policies, DNS records |
| SMTP provider (Gmail/Google Workspace) | App passwords for alerting |

---

## 16. Migration Checklist

### Pre-migration (on old PC)

- [ ] **Back up all databases** before any migration work
  ```bash
  # PostgreSQL inventory
  docker exec inventory-db pg_dump -U inventory inventory | gzip > inventory_pre_migration.dump.gz

  # PostgreSQL event_log
  docker exec event-log-db pg_dump -U eventlog event_log | gzip > event_log_pre_migration.dump.gz

  # MySQL homeautomation
  docker exec homeautomation-db mysqldump -u root -p homeautomation | gzip > homeautomation_pre_migration.sql.gz

  # MySQL snipeit
  docker exec snipeit-db mysqldump -u root -p snipeit | gzip > snipeit_pre_migration.sql.gz
  ```
- [ ] **Export Docker volumes** (for non-database services)
  ```bash
  # Gramps Web (family tree data + media)
  docker run --rm -v gramps_grampsdb:/data -v $(pwd):/backup alpine tar czf /backup/gramps_grampsdb.tar.gz -C /data .
  docker run --rm -v gramps_media:/data -v $(pwd):/backup alpine tar czf /backup/gramps_media.tar.gz -C /data .
  docker run --rm -v gramps_users:/data -v $(pwd):/backup alpine tar czf /backup/gramps_users.tar.gz -C /data .
  docker run --rm -v gramps_secret:/data -v $(pwd):/backup alpine tar czf /backup/gramps_secret.tar.gz -C /data .

  # Snipe-IT uploads
  docker run --rm -v docker_snipeit-data:/data -v $(pwd):/backup alpine tar czf /backup/snipeit_data.tar.gz -C /data .
  ```
- [ ] **Copy Fasten Health bind mounts**
  ```
  fasten-deploy/db/        → contains SQLite database
  fasten-deploy/cache/     → cache data
  fasten-deploy/certs/     → TLS certificates
  fasten-deploy/config.yaml → app configuration
  ```
- [ ] **Copy Cloudflare credentials**
  ```
  C:\Users\ranand\.cloudflared\config.yml
  C:\Users\ranand\.cloudflared\1f014ff9-68ae-4033-bacf-e058b91d2df4.json
  ```
- [ ] **Copy all .env files** (listed in Section 15)
- [ ] **Copy D:\backups\** directory to new PC

### New PC setup (order of operations)

#### Phase 1: Foundation

1. [ ] Install Docker Desktop
2. [ ] Clone all 13 repositories to same directory structure
3. [ ] Copy `.env` files to their respective locations
4. [ ] Copy `.cloudflared/` directory to new user profile

#### Phase 2: Core infrastructure (ra-infrastructure)

5. [ ] Start core databases:
   ```bash
   cd ra-infrastructure/docker
   docker compose up -d
   ```
6. [ ] Verify databases are healthy:
   ```bash
   docker exec inventory-db pg_isready -U inventory
   docker exec homeautomation-db mysqladmin ping -h localhost -u root -p
   ```
7. [ ] Restore database dumps:
   ```bash
   # PostgreSQL
   gunzip -c inventory_pre_migration.dump.gz | docker exec -i inventory-db psql -U inventory inventory
   gunzip -c event_log_pre_migration.dump.gz | docker exec -i event-log-db psql -U eventlog event_log

   # MySQL
   gunzip -c homeautomation_pre_migration.sql.gz | docker exec -i homeautomation-db mysql -u root -p homeautomation
   ```
8. [ ] Restore Gramps Web volumes:
   ```bash
   docker run --rm -v gramps_grampsdb:/data -v $(pwd):/backup alpine tar xzf /backup/gramps_grampsdb.tar.gz -C /data
   docker run --rm -v gramps_media:/data -v $(pwd):/backup alpine tar xzf /backup/gramps_media.tar.gz -C /data
   docker run --rm -v gramps_users:/data -v $(pwd):/backup alpine tar xzf /backup/gramps_users.tar.gz -C /data
   docker run --rm -v gramps_secret:/data -v $(pwd):/backup alpine tar xzf /backup/gramps_secret.tar.gz -C /data
   ```

#### Phase 3: Application services

9. [ ] Start Snipe-IT:
    ```bash
    cd snipeit-asset-management/docker
    docker compose up -d
    ```
10. [ ] Restore Snipe-IT database + uploads:
    ```bash
    gunzip -c snipeit_pre_migration.sql.gz | docker exec -i snipeit-db mysql -u root -p snipeit
    docker run --rm -v docker_snipeit-data:/data -v $(pwd):/backup alpine tar xzf /backup/snipeit_data.tar.gz -C /data
    ```
11. [ ] Copy Fasten Health data and start:
    ```bash
    # Copy db/, cache/, certs/, config.yaml to fasten-deploy/
    cd fasten-deploy
    docker compose up -d
    ```
12. [ ] Build and start Daily Event Log:
    ```bash
    cd ra-life-tracker
    # Build the image (check repo for build instructions)
    docker compose up -d
    ```

#### Phase 4: Infrastructure services

13. [ ] Start Traefik:
    ```bash
    cd ra-infrastructure/traefik
    docker compose -f docker-compose.traefik.yml up -d
    ```
14. [ ] Start Gatus:
    ```bash
    cd ra-infrastructure/gatus
    docker compose -f docker-compose.gatus.yml up -d
    ```
15. [ ] Start Dashboard:
    ```bash
    cd ra-infrastructure/dashboard
    docker compose -f docker-compose.dashboard.yml up -d
    ```

#### Phase 5: Networking & external access

16. [ ] Install cloudflared:
    ```bash
    winget install Cloudflare.cloudflared
    ```
17. [ ] Copy `.cloudflared/` config and credentials to new user profile
18. [ ] Start tunnel (or configure via Cloudflare dashboard):
    ```bash
    cloudflared tunnel run selfwize-dev
    ```
19. [ ] Update Cloudflare Zero Trust dashboard if the origin IP changes

#### Phase 6: Verification

20. [ ] Run infrastructure self-check:
    ```bash
    cd ra-infrastructure
    inv system selfcheck
    ```
21. [ ] Verify all 12 containers are running:
    ```bash
    docker ps --format "table {{.Names}}\t{{.Status}}"
    ```
22. [ ] Verify database connectivity:
    ```bash
    inv db health
    inv db stats
    ```
23. [ ] Test each external URL:
    - [ ] https://stuff.selfwize.com (Snipe-IT)
    - [ ] https://wellness.selfwize.com (Fasten Health)
    - [ ] https://dash.selfwize.com (Dashboard)
    - [ ] https://status.selfwize.com (Gatus)
    - [ ] https://family.selfwize.com (Gramps Web)
    - [ ] https://events.selfwize.com (Daily Event Log)
    - [ ] https://home.selfwize.com (Homeseer — proxied, not on this PC)
    - [ ] https://cameras.selfwize.com (Blue Iris — proxied, not on this PC)
24. [ ] Verify backups are running on new PC:
    ```bash
    # Check next morning for new backup files in D:\backups\
    ```
25. [ ] Set up missing backups (event_log, snipeit, Gramps, Fasten)

### Post-migration cleanup (on old PC)

- [ ] Stop all containers: `docker compose down` in each project
- [ ] Optionally prune Docker data: `docker system prune -a --volumes`
- [ ] Decommission old PC or repurpose

---

## Appendix: Port Map

| Port | Service | Access |
|------|---------|--------|
| 80 | Traefik (HTTP entrypoint) | Receives tunnel traffic |
| 3306 | MySQL (homeautomation) | Local only |
| 5000 | Gramps Web | Local + tunnel |
| 5050 | pgAdmin | Local only |
| 5432 | PostgreSQL (inventory) | Local only |
| 5433 | PostgreSQL (event_log) | Local only |
| 8000 | Daily Event Log | Local + tunnel |
| 8080 | Traefik Dashboard | Local only |
| 8082 | Snipe-IT | Local + tunnel |
| 8083 | Gatus | Local + tunnel |
| 8088 | Selfwize Dashboard | Local + tunnel |
| 9090 | Fasten Health | Local + tunnel |
