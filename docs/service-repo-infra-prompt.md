# Infrastructure Briefing: ra-infrastructure (Feb 2026)

> **Paste this prompt into a Claude Code session in any `score-ra/*` repository to brief the session about the central infrastructure and run a health check for stale references.**

---

## 1. What is ra-infrastructure?

`score-ra/ra-infrastructure` is the central infrastructure repo for all **selfwize.com** services. It manages:

- **Docker containers** for all services (single `docker-compose.yml` at repo root)
- **Traefik v3** reverse proxy (all `*.selfwize.com` routing)
- **Databases**: PostgreSQL 16 (inventory, event_log) and MySQL 8.0 (Snipe-IT)
- **Monitoring**: Gatus health checks
- **Backups**: Automated local + remote backup schedules
- **Config source of truth**: `config/infrastructure.env` with `RA_*` prefixed variables

GitHub: `score-ra/ra-infrastructure`

---

## 2. What Changed (Feb 2026 Consolidation)

A major consolidation unified all infrastructure under a single compose stack. These breaking changes may affect your repo:

| Change | Before | After |
|--------|--------|-------|
| **Container names** | Mixed (`inventory-db`, `snipeit-app`, `daily-event-log`) | `ra_` prefix (`ra_postgres`, `ra_snipeit`, `ra_eventlog`) |
| **Docker network** | Multiple (`inventory_network`, `docker_snipeit-network`) | Single `ra_network` |
| **PostgreSQL (inventory)** | `localhost:5432`, user `inventory`, db `inventory` | `localhost:5433`, user `postgres`, db `inventory` |
| **PostgreSQL (event_log)** | `localhost:5432`, user `eventlog` | `localhost:5434`, user `eventlog`, db `event_log` |
| **MySQL (Snipe-IT)** | `localhost:3306`, user/db `homeautomation` | `localhost:3307`, user/db `snipeit` |
| **Compose file** | `docker/docker-compose.yml` | Root `docker-compose.yml` |
| **Config source** | Hardcoded in each script | `config/infrastructure.env` with `RA_*` vars |
| **Traefik host port** | `:80` | `:8070` |
| **pgAdmin port** | `:5050` | `:8084` |
| **Dashboard** | Homarr | Lightweight nginx + `services.json` |

---

## 3. Current Infrastructure Reference

### Services & Ports

| Service | Container | Host Port | Internal Port | Domain |
|---------|-----------|-----------|---------------|--------|
| PostgreSQL (inventory) | `ra_postgres` | 5433 | 5432 | — |
| PostgreSQL (event_log) | `ra_eventlog_db` | 5434 | 5432 | — |
| MySQL (Snipe-IT) | `ra_mysql` | 3307 | 3306 | — |
| Snipe-IT | `ra_snipeit` | 8083 | 80 | `stuff.selfwize.com` |
| Fasten Health | `ra_fasten` | 9091 | 8080 | `wellness.selfwize.com` |
| Daily Event Log | `ra_eventlog` | 8089 | 8000 | `events.selfwize.com` |
| Dashboard | `ra_dashboard` | 8088 | 80 | `dash.selfwize.com` |
| Gatus (monitoring) | `ra_gatus` | 8085 | 8080 | `status.selfwize.com` |
| Traefik | `ra_traefik` | 8070 | 80 | — |
| pgAdmin | `ra_pgadmin` | 8084 | 80 | — |

### Additional Routed Services (external, not in compose)

| Domain | Backend |
|--------|---------|
| `cameras.selfwize.com` | Blue Iris at `192.168.68.56:443` |
| `home.selfwize.com` | Homeseer at `192.168.68.56:80` |
| `family.selfwize.com` | Gramps Web at `host.docker.internal:5000` |

### Database Connection Strings

```
# PostgreSQL (inventory)
postgresql://postgres:<password>@localhost:5433/inventory

# PostgreSQL (event_log)
postgresql://eventlog:<password>@localhost:5434/event_log

# MySQL (Snipe-IT)
mysql://snipeit:<password>@localhost:3307/snipeit
```

### Docker Network

All containers share a single bridge network: `ra_network`

---

## 4. Health Check Checklist

Search this repository for stale references to the **old** infrastructure. For each category, search for the listed patterns and flag any matches:

### 4.1 Database connection strings
- Old PostgreSQL host/port: `localhost:5432` with user `inventory`
- Old MySQL host/port: `localhost:3306` with user/db `homeautomation`
- Old event_log references using port `5432` instead of `5434`

### 4.2 Container name references
- `inventory-db` or `inventory_db` (now `ra_postgres`)
- `snipeit-app` or `snipeit_app` (now `ra_snipeit`)
- `daily-event-log` or `daily_event_log` (now `ra_eventlog`)
- Any container name not using the `ra_` prefix

### 4.3 Network name references
- `inventory_network`, `docker_snipeit-network`, or any network name that isn't `ra_network`

### 4.4 Docker compose paths
- `docker/docker-compose.yml` (the compose file is now at the repo root)
- `cd docker && docker-compose` or similar commands

### 4.5 Port references
- Port `5432` for the inventory database (now `5433`)
- Port `3306` for MySQL (now `3307`)
- Port `80` for Traefik (now `8070`)
- Port `5050` for pgAdmin (now `8084`)
- Port `8083` for Gatus (now `8085`; port `8083` is Snipe-IT)
- Port `8082` for Snipe-IT (now `8083`)

### 4.6 Hardcoded URLs
- Old localhost URLs with wrong ports
- Domain references that may have changed

### 4.7 CLAUDE.md / start-here.md
- Verify any infrastructure details match the current topology above

### 4.8 Environment variables
- Stale `INV_*` prefixed vars that should reference `RA_*` infra config
- Hardcoded database credentials instead of referencing `config/infrastructure.env`

### 4.9 CI/CD or scripts
- Deployment scripts referencing old container names or compose paths
- Scripts using old port numbers or database credentials

### 4.10 README / docs
- Outdated setup instructions referencing old infrastructure
- Old connection examples or Docker commands

---

## 5. Expected Action

1. **Run the health check** above — search for each pattern category
2. **Fix any stale references** found (update to current values from Section 3)
3. **Update this repo's CLAUDE.md** if it references ra-infrastructure details
4. **Commit fixes** with a message like: `fix: update stale infrastructure references (Feb 2026 consolidation)`
