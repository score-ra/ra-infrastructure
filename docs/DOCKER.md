# Docker Infrastructure Guide

## Overview

ra-infrastructure uses Docker Compose to run 10 containers on Raptor (Windows 11). All services share the `ra_network` bridge network.

```
┌────────────────────────────────────────────────────────────────────┐
│                        Docker Compose Stack                        │
│                                                                    │
│  DATABASES           APPLICATIONS           INFRASTRUCTURE         │
│  ┌──────────────┐   ┌──────────────────┐   ┌──────────────┐      │
│  │ ra_postgres   │   │ ra_snipeit       │   │ ra_traefik   │      │
│  │ (PG 16)      │   │ (Snipe-IT v8.3)  │   │ (Traefik v3) │      │
│  │ :5433        │   │ :8083            │   │ :8070        │      │
│  ├──────────────┤   ├──────────────────┤   ├──────────────┤      │
│  │ ra_mysql      │   │ ra_fasten        │   │ ra_gatus     │      │
│  │ (MySQL 8.0)  │   │ (Fasten Health)  │   │ (Monitoring) │      │
│  │ :3307        │   │ :9091            │   │ :8085        │      │
│  ├──────────────┤   ├──────────────────┤   └──────────────┘      │
│  │ ra_eventlog_db│   │ ra_eventlog      │                         │
│  │ (PG 16)      │   │ (Event Log)      │                         │
│  │ :5434        │   │ :8089            │                         │
│  └──────────────┘   ├──────────────────┤                         │
│                     │ ra_labels         │                         │
│                     │ (Label Service)   │                         │
│                     │ :8100            │                         │
│                     ├──────────────────┤                         │
│                     │ ra_dashboard      │                         │
│                     │ (nginx)          │                         │
│                     │ :8088            │                         │
│                     └──────────────────┘                         │
└────────────────────────────────────────────────────────────────────┘
```

## Containers

| Container | Image | Port | Purpose | Depends On |
|-----------|-------|------|---------|------------|
| ra_postgres | postgres:16-alpine | 5433 | Inventory database | — |
| ra_mysql | mysql:8.0 | 3307 | Snipe-IT database | — |
| ra_eventlog_db | postgres:16-alpine | 5434 | Event Log database | — |
| ra_snipeit | snipe/snipe-it:v8.3.7 | 8083 | Asset management | ra_mysql |
| ra_fasten | ghcr.io/fastenhealth/fasten-onprem:main | 9091 | Health records | — |
| ra_eventlog | daily-event-log:latest (local build) | 8089 | Event tracking | ra_eventlog_db |
| ra_labels | Built from snipeit-asset-management | 8100 | QR label service | — |
| ra_dashboard | nginx:alpine | 8088 | Service directory | — |
| ra_traefik | traefik:v3.2 | 8070 | Reverse proxy | — |
| ra_gatus | twinproduction/gatus:latest | 8085 | Status monitoring | — |

## Locally-Built Images

Two services use images not from a registry:

- **ra_eventlog** — `daily-event-log:latest`, built from `../ra-life-tracker/Dockerfile`
- **ra_labels** — built from `../snipeit-asset-management/src/label-service/Dockerfile`

Rebuild after code changes:
```powershell
# Event log
cd ..\ra-life-tracker && docker build -t daily-event-log:latest .

# Labels (rebuilt automatically by docker compose)
docker compose build ra_labels
```

## Environment Files

| File | Purpose | Git Status |
|------|---------|------------|
| `.env` | Secrets (DB passwords, SMTP) | git-ignored |
| `config/infrastructure.env` | Topology (ports, container names, paths) | tracked |
| `../snipeit-asset-management/.env` | Snipe-IT APP_KEY, MySQL creds | git-ignored |
| `../ra-life-tracker/.env` | Event log DB creds, Fasten/Gramps creds | git-ignored |

## Common Operations

### Start / Stop
```powershell
docker compose up -d          # Start all
docker compose down            # Stop all
docker compose restart         # Restart all
docker compose restart ra_postgres  # Restart one
```

### Logs
```powershell
docker compose logs -f                 # All services
docker compose logs -f ra_snipeit      # Specific service
docker compose logs --tail 50 ra_traefik
```

### Status
```powershell
docker compose ps              # Container status
docker system df               # Disk usage
```

### Rebuild
```powershell
docker compose up -d --build ra_labels    # Rebuild and restart
docker compose up -d --force-recreate     # Recreate all containers
```

## Volumes

| Volume | Container | Purpose |
|--------|-----------|---------|
| ra_postgres_data | ra_postgres | Inventory DB data |
| ra_mysql_data | ra_mysql | Snipe-IT DB data |
| ra_eventlog_postgres_data | ra_eventlog_db | Event Log DB data |
| ra_snipeit_data | ra_snipeit | Snipe-IT uploads |
| ra_snipeit_logs | ra_snipeit | Snipe-IT logs |
| ra_fasten_db | ra_fasten | Fasten Health DB |
| ra_fasten_cache | ra_fasten | Fasten cache |
| ra_fasten_certs | ra_fasten | Fasten certs |
| ra_gatus_data | ra_gatus | Gatus state |
| ra_labels_data | ra_labels | Label DB |

**Warning:** `docker compose down -v` deletes all volumes and data.

## Network

All containers communicate on `ra_network` (bridge). Use container names as hostnames for inter-container communication (e.g., `ra_postgres`, `ra_mysql`).

## Remote Session Notes (Tailscale SSH)

Docker Desktop's credential helpers (`docker-credential-desktop.exe`, `docker-credential-wincred.exe`) fail over remote sessions because they require the Windows DPAPI logon session. Workaround:

1. Rename credential helpers to `.bak` in `C:\Program Files\Docker\Docker\resources\bin\`
2. Set `"credsStore": ""` in `~\.docker\config.json`
3. Docker Desktop may reset `config.json` on restart — re-apply after reboot
