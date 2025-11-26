# ra-infrastructure

Central infrastructure repository for device inventory, network management, and multi-site organization support.

## Overview

This repository provides:
- **Device Inventory Database** - PostgreSQL-based tracking of all devices across sites
- **Multi-Organization Support** - Manage residential, office, and lab environments
- **Network Awareness** - Track networks (WiFi, Ethernet, Z-Wave, Zigbee, Bluetooth)
- **CLI Tools** - Python-based command-line interface for management
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
├── docker/
│   └── docker-compose.yml      # PostgreSQL + pgAdmin
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
├── api/                        # REST API (future)
│   └── node/
└── docs/
    └── schema.md               # Database documentation
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
inv device import homeseer --file devices.json
inv device show living-room-switch

# Networks
inv network list --site primary-residence
inv network create "Main WiFi" --type wifi --ssid "HomeNet"
inv network scan --site primary-residence

# Reports
inv report devices --format csv > devices.csv
inv report topology --site primary-residence
```

## Database Access

- **PostgreSQL**: `localhost:5432`
  - Database: `inventory`
  - User: `inventory`
  - Password: (see `.env`)

- **pgAdmin**: `http://localhost:5050`
  - Email: `admin@local.dev`
  - Password: (see `.env`)

## Integration with Other Repos

This repo provides the central database that other repos connect to:

| Repo | Integration |
|------|-------------|
| `ra-home-automation` | Syncs HomeSeer devices to inventory |
| `ra-network` | Network discovery populates devices |
| Future repos | Connect via CLI or API |

## Related Repositories

- [ra-home-automation](../ra-home-automation) - HomeSeer, BlueIris automation
- [ra-network](../ra-network) - Network management (future)

## License

Private - Internal use only

---

**Created**: 2025-11-25
**Status**: Foundation phase
