# ra-infrastructure

| Field | Value |
|-------|-------|
| **Status** | Active |
| **Tier** | T1 Critical |
| **Kind** | Infrastructure |
| **Org** | score-ra |
| **Infra Repo** | Self (this is the RA infra repo) |
| **Last Reviewed** | 2026-02-15 |

## Purpose

Central infrastructure for personal/home services. Orchestrates 10+ services via Docker Compose including PostgreSQL (inventory + event logs), MySQL (Snipe-IT), Traefik reverse proxy, Gatus monitoring, and application containers for Snipe-IT asset management, Fasten Health records, Daily Event Log, and QR label service. Supports multi-organization and multi-site device tracking.

## Scope

**This repo IS for:**
- Docker Compose orchestration for personal services
- Device inventory database (PostgreSQL)
- Traefik routing, Gatus monitoring, pgAdmin
- Service health dashboards

**This repo is NOT for:**
- Symphony Core services -> see [sc-infrastructure](https://github.com/symphonycore-org/sc-infrastructure)
- Ansible-based deployments -> see [homelab-deploy](https://github.com/score-ra/homelab-deploy)
- Device software provisioning -> see [device-deployments](https://github.com/score-ra/device-deployments)

## Related Repos

| Relationship | Repo |
|-------------|------|
| **Dependencies** | N/A |
| **Dependents** | [snipeit-asset-management](https://github.com/score-ra/snipeit-asset-management), [ra-fasten-health](https://github.com/score-ra/ra-fasten-health), [ra-life-tracker](https://github.com/score-ra/ra-life-tracker) |
| **Supersedes** | N/A |
| **Superseded By** | N/A |

---

Central infrastructure repository for device inventory, network management, and multi-site organization support.

## Overview

This repository provides:
- **Device Inventory Database** - PostgreSQL-based tracking of all devices across sites
- **Multi-Organization Support** - Manage residential, office, and lab environments
- **Network Awareness** - Track networks (WiFi, Ethernet, Z-Wave, Zigbee, Bluetooth)
- **CLI Tools** - Python-based command-line interface for management
- **Auto-Generated Schema Diagrams** - ER diagrams generated directly from live database
- **REST API** - Node.js API for integrations (future)

## Architecture

```
Organization (e.g., "Anand Family", "Company")
└── Site (e.g., "Primary Residence", "Office")
    └── Zone (e.g., "Living Room", "Server Closet")
        └── Device (switches, cameras, sensors, etc.)
```

## Quick Start

### Prerequisites
- Docker & Docker Compose
- Python 3.11+
- Node.js 18+ (for API, future)

### Setup

```bash
# Start PostgreSQL and pgAdmin
cd docker
docker-compose up -d

# Install CLI
cd cli
pip install -e .

# Initialize database
inv db migrate
inv db seed

# Verify
inv org list
```

## Repository Structure

```
ra-infrastructure/
├── dashboard/                  # Selfwize Dashboard (service launcher)
│   ├── services.json           # Service definitions (edit this!)
│   └── docker-compose.dashboard.yml
├── docker/
│   └── docker-compose.yml      # PostgreSQL + pgAdmin + MySQL
├── traefik/                    # Reverse proxy configuration
│   ├── docker-compose.traefik.yml
│   └── dynamic/                # Dynamic route configs
├── gatus/                      # Status monitoring
│   └── docker-compose.gatus.yml
├── database/
│   ├── migrations/             # SQL migration files (versioned)
│   ├── seeds/                  # Initial/sample data
│   └── schema.sql              # Full schema reference
├── cli/                        # Python CLI (inv command)
│   ├── pyproject.toml
│   └── src/inventory/
│       ├── commands/           # CLI command groups
│       ├── db/                 # Database access
│       └── models/             # Data models
├── scripts/                    # Utility scripts
│   ├── health-check.ps1        # Infrastructure health check
│   └── backup.ps1              # Backup script
└── docs/
    ├── guides/                 # How-to guides
    ├── prds/                   # Product requirements
    └── architecture/           # Architecture docs
```

## CLI Commands (MVP)

```bash
# Organizations
inv org list
inv org create "Anand Family" --type home
inv org show anand-family

# Sites
inv site list --org anand-family
inv site create "Primary Residence" --org anand-family --address "..."
inv site show primary-residence

# Devices
inv device list --site primary-residence
inv device create "Living Room Switch" --type switch --zone living-room
inv device import homeassistant --file devices.json
inv device show living-room-switch

# Networks
inv network list --site primary-residence
inv network create "Main WiFi" --type wifi --ssid "HomeNet"
inv network scan --site primary-residence

# System Health Checks
inv system selfcheck               # Comprehensive infrastructure health check
inv system check-endpoint <url>    # Check specific endpoint

# Reports
inv report devices --format csv > devices.csv
inv report topology --site primary-residence

# Database schema diagram
inv db schema                      # Generate PNG diagram
inv db schema -f html              # Generate full HTML documentation
```

## Schema Diagram

Generate an up-to-date ER diagram directly from the live database:

```bash
# Generate PNG diagram (requires Docker)
inv db schema

# Output: docs/schema.png
```

This ensures the diagram always matches the actual database schema - no manual maintenance required. The command uses [SchemaSpy](https://schemaspy.org/) via Docker to introspect the database and generate the diagram.

For full interactive documentation with all tables, columns, and relationships:

```bash
inv db schema -f html
# Open docs/schema/index.html in a browser
```

## Web Services

All services are accessible via the **Selfwize Dashboard** at https://dash.selfwize.com

| Service | URL | Description |
|---------|-----|-------------|
| **Dashboard** | https://dash.selfwize.com | Service launcher (config-driven) |
| **Status Monitor** | https://status.selfwize.com | Gatus health monitoring |
| **Asset Inventory** | https://stuff.selfwize.com | Snipe-IT asset management |
| **Health Records** | https://wellness.selfwize.com | Fasten Health |
| **Family Contacts** | https://family.selfwize.com | Gramps Web genealogy |
| **Daily Events** | https://events.selfwize.com | Event log tracker |
| **Home Automation** | https://home.selfwize.com | Home Assistant |
| **Security Cameras** | https://cameras.selfwize.com | Blue Iris |

### Infrastructure Services (Local Only)

| Service | URL | Description |
|---------|-----|-------------|
| pgAdmin | http://localhost:5050 | PostgreSQL admin |
| Traefik | http://localhost:8080 | Reverse proxy dashboard |
| Gatus | http://localhost:8083 | Status monitor (local) |

### Adding Services to Dashboard

Edit `dashboard/services.json` - no code changes required. See [Dashboard README](dashboard/README.md) for details.

## Database Access

- **PostgreSQL**: `localhost:5432`
  - Database: `inventory`
  - User: `inventory`
  - Password: (see `.env`)

- **pgAdmin**: `http://localhost:5050`
  - Email: `admin@local.dev`
  - Password: (see `.env`)

- **DBeaver**: Import pre-configured connections from `config/dbeaver/`
  - See [DBeaver Connection Import Guide](docs/guides/DBEAVER-CONNECTION-IMPORT.md)

## Documentation

### Guides
| Guide | Description |
|-------|-------------|
| [Selfwize Dashboard](dashboard/README.md) | Config-driven service launcher - add services by editing JSON |
| [DBeaver Connection Import](docs/guides/DBEAVER-CONNECTION-IMPORT.md) | Import database connections into DBeaver for SQL access |
| [MINIX Z100-0dB Power Recovery](docs/guides/MINIX-Z100-0dB-Power-Recovery-Guide.md) | Configure auto power-on after outage for the home automation server |

## Integration with Other Repos

This repo provides the central database that other repos connect to:

| Repo | Integration |
|------|-------------|
| `ra-home-automation` | Syncs Home Assistant devices to inventory |
| `ra-network` | Network discovery populates devices |
| Future repos | Connect via CLI or API |

## Related Repositories

- [ra-home-automation](../ra-home-automation) - Home Assistant, BlueIris automation
- [ra-network](../ra-network) - Network management (future)

## License

Private - Internal use only

---

**Created**: 2025-11-25
**Status**: Foundation phase
