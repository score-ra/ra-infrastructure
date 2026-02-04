# Ports in Use

Host ports exposed by ra-infrastructure services. All containers use the `ra_` prefix and share the `ra_network` bridge network.

## Application Services

| Port | Service | Container | Protocol | Domain |
|------|---------|-----------|----------|--------|
| 8083 | Snipe-IT | ra_snipeit | HTTP | stuff.selfwize.com |
| 8085 | Gatus | ra_gatus | HTTP | status.selfwize.com |
| 8088 | Selfwize Dashboard | ra_dashboard | HTTP | dash.selfwize.com |
| 8089 | Daily Event Log | ra_eventlog | HTTP | events.selfwize.com |
| 9091 | Fasten Health | ra_fasten | HTTP | wellness.selfwize.com |

## Infrastructure Services

| Port | Service | Container | Protocol | Notes |
|------|---------|-----------|----------|-------|
| 8070 | Traefik | ra_traefik | HTTP | Reverse proxy; receives all *.selfwize.com traffic from Cloudflare tunnel |
| 8084 | pgAdmin 4 | ra_pgadmin | HTTP | PostgreSQL management UI |

## Databases

| Port | Service | Container | Notes |
|------|---------|-----------|-------|
| 3307 | MySQL 8.0 | ra_mysql | Snipe-IT backend (default 3306 remapped) |
| 5433 | PostgreSQL 16 | ra_postgres | Inventory database (default 5432 remapped) |
| 5434 | PostgreSQL 16 | ra_eventlog_db | Event Log database |

## External (Non-Docker) Services

Routed through Traefik via `host.docker.internal` or direct LAN IP.

| Port | Service | Address | Protocol | Domain |
|------|---------|---------|----------|--------|
| 80 | Homeseer | 192.168.68.56 | HTTP | home.selfwize.com |
| 443 | Blue Iris | 192.168.68.56 | HTTPS (self-signed) | cameras.selfwize.com |
| 5000 | Gramps Web | host.docker.internal | HTTP | family.selfwize.com |
