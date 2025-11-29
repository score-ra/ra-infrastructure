# Docker Infrastructure Guide

This document describes the Docker containers used by ra-infrastructure and their purposes.

## Overview

ra-infrastructure uses Docker Compose to manage two containers that provide the database layer for device inventory and network management.

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Environment                        │
│                                                              │
│  ┌──────────────────┐       ┌──────────────────┐            │
│  │   inventory-db   │       │ inventory-pgadmin │            │
│  │   (PostgreSQL)   │◄──────│    (pgAdmin 4)    │            │
│  │                  │       │                   │            │
│  │  Port: 5432      │       │   Port: 5050      │            │
│  │  CPU: 1.0 max    │       │   CPU: 0.5 max    │            │
│  │  RAM: 512M max   │       │   RAM: 256M max   │            │
│  └──────────────────┘       └───────────────────┘            │
│           │                                                  │
│           ▼                                                  │
│  ┌──────────────────┐                                       │
│  │ postgres_data    │  Named volume for data persistence    │
│  └──────────────────┘                                       │
└─────────────────────────────────────────────────────────────┘
```

## Containers

### inventory-db (PostgreSQL 16)

| Property | Value |
|----------|-------|
| **Image** | `postgres:16-alpine` |
| **Container Name** | `inventory-db` |
| **Purpose** | Primary database for all device, network, and organization data |
| **Port** | `5432` (host) → `5432` (container) |
| **Restart Policy** | `unless-stopped` |

**Purpose:**
- Stores all inventory data (organizations, sites, zones, devices, networks)
- Provides the data layer consumed by external repositories
- Runs migrations automatically on first start via `/docker-entrypoint-initdb.d`

**Resource Limits:**
- CPU: 1.0 core max, 0.25 core reserved
- Memory: 512MB max, 128MB reserved

**Health Check:**
- Command: `pg_isready -U inventory`
- Interval: 10 seconds
- Timeout: 5 seconds
- Retries: 5

**Volumes:**
- `inventory_postgres_data` → `/var/lib/postgresql/data` (persistent data)
- `../database/migrations` → `/docker-entrypoint-initdb.d` (read-only, init scripts)

### inventory-pgadmin (pgAdmin 4)

| Property | Value |
|----------|-------|
| **Image** | `dpage/pgadmin4:latest` |
| **Container Name** | `inventory-pgadmin` |
| **Purpose** | Web-based database administration interface |
| **Port** | `5050` (host) → `80` (container) |
| **Restart Policy** | `unless-stopped` |

**Purpose:**
- Provides a web UI for database administration at `http://localhost:5050`
- Useful for manual queries, schema inspection, and debugging
- Optional for production use (can be disabled)

**Resource Limits:**
- CPU: 0.5 core max, 0.1 core reserved
- Memory: 256MB max, 64MB reserved

**Dependencies:**
- Waits for `inventory-db` to be healthy before starting

**Default Credentials:**
- Email: `admin@local.dev`
- Password: `admin_dev_password` (change via `.env`)

## Network

| Property | Value |
|----------|-------|
| **Network Name** | `inventory_network` |
| **Type** | Bridge (default) |

Both containers communicate over `inventory_network`. From within pgAdmin, connect to the database using hostname `postgres` (Docker DNS).

## Volumes

| Volume Name | Purpose | Container Path |
|-------------|---------|----------------|
| `inventory_postgres_data` | PostgreSQL data persistence | `/var/lib/postgresql/data` |
| `inventory_pgadmin_data` | pgAdmin configuration/sessions | `/var/lib/pgadmin` |

**Important:** These volumes persist data across container restarts and rebuilds. To completely reset the database, you must remove the volumes:

```powershell
docker-compose down -v  # WARNING: Deletes all data
```

## Environment Variables

Configure via `docker/.env` file (copy from `.env.example`):

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_DB` | `inventory` | Database name |
| `POSTGRES_USER` | `inventory` | Database user |
| `POSTGRES_PASSWORD` | `inventory_dev_password` | Database password |
| `POSTGRES_PORT` | `5432` | Host port for PostgreSQL |
| `PGADMIN_EMAIL` | `admin@local.dev` | pgAdmin login email |
| `PGADMIN_PASSWORD` | `admin_dev_password` | pgAdmin login password |
| `PGADMIN_PORT` | `5050` | Host port for pgAdmin |

## Common Operations

### Start Services
```powershell
cd docker
docker-compose up -d
```

### Stop Services
```powershell
cd docker
docker-compose down
```

### View Logs
```powershell
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f postgres
docker-compose logs -f pgadmin
```

### Check Status
```powershell
docker-compose ps

# Or via CLI
inv db stats
```

### Restart Services
```powershell
docker-compose restart

# Specific service
docker-compose restart postgres
```

### Reset Database (destructive)
```powershell
docker-compose down -v
docker-compose up -d
inv db migrate
inv db seed
```

## Connecting to the Database

### From Host Machine
```
Host: localhost
Port: 5432
Database: ra_inventory
User: inventory
Password: inventory_dev_password
```

### From Another Docker Container
```
Host: postgres (or inventory-db)
Port: 5432
Database: ra_inventory
User: inventory
Password: inventory_dev_password
```

### From pgAdmin Web UI
1. Open `http://localhost:5050`
2. Login with pgAdmin credentials
3. Add server with:
   - Host: `postgres`
   - Port: `5432`
   - Database: `ra_inventory`
   - User: `inventory`

## Troubleshooting

### Container Won't Start
```powershell
# Check logs for errors
docker-compose logs postgres

# Check if port is in use
netstat -an | findstr 5432
```

### Database Connection Refused
```powershell
# Verify container is running and healthy
docker-compose ps

# Check health status
docker inspect inventory-db --format='{{.State.Health.Status}}'
```

### Out of Disk Space
```powershell
# Check Docker disk usage
docker system df

# Clean up unused resources
docker system prune
```

### pgAdmin Can't Connect to Database
- Use hostname `postgres` (not `localhost`) when connecting from pgAdmin
- Ensure the database container is healthy before pgAdmin starts
