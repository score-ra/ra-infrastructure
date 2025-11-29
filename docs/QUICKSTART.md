# Quick Start Guide

## Prerequisites

- Docker Desktop installed and running
- Python 3.11+ installed
- pip (Python package manager)

## Setup

### 1. Start Database

```powershell
cd c:\Users\ranand\workspace\personal\software\ra-infrastructure\docker

# Copy environment file
copy .env.example .env

# Start PostgreSQL and pgAdmin
docker-compose up -d

# Verify containers are running
docker ps
```

You should see:
- `inventory-db` (PostgreSQL)
- `inventory-pgadmin` (pgAdmin web UI)

### 2. Install CLI

```powershell
cd c:\Users\ranand\workspace\personal\software\ra-infrastructure\cli

# Create virtual environment (optional but recommended)
python -m venv .venv
.venv\Scripts\activate

# Install in development mode
pip install -e .

# Verify installation
inv --help
```

### 3. Initialize Database

```powershell
# Run migrations (creates tables)
inv db migrate

# Seed initial data
inv db seed

# Verify
inv db stats
```

### 4. Explore

```powershell
# Check system status
inv status

# List organizations
inv org list

# List sites
inv site list

# List devices
inv device list

# Show device details
inv device show homeseer-server
```

## Access pgAdmin

Open http://localhost:5050 in your browser:
- Email: `admin@local.dev`
- Password: (from your .env file)

Add server connection:
- Host: `postgres` (or `host.docker.internal` on Windows)
- Port: `5432`
- Database: `inventory`
- Username: `inventory`
- Password: (from your .env file)

## CLI Commands Overview

```
inv --help                    # Show all commands

# Organizations
inv org list                  # List organizations
inv org show <slug>           # Show org details
inv org create "Name"         # Create organization

# Sites
inv site list                 # List sites
inv site list --org <slug>    # Filter by org
inv site show <slug>          # Show site details
inv site create "Name" --org <slug>

# Devices
inv device list               # List devices
inv device list --site <slug> # Filter by site
inv device show <slug>        # Show device details
inv device count --by category
inv device create "Name" --type switch --site <slug>

# Networks
inv network list              # List networks
inv network show <slug>       # Show network details
inv network types             # List network types

# Database
inv db stats                  # Show record counts
inv db tables                 # List tables
inv db migrate                # Run migrations
inv db seed                   # Seed data
inv db reset --yes            # Reset database
```

## Next Steps

1. Add your devices to the inventory
2. Configure zones for your site
3. Set up network records
4. Import existing data from HomeSeer

## Troubleshooting

### Database connection failed
- Ensure Docker containers are running: `docker ps`
- Check .env file has correct credentials
- Try: `docker-compose down && docker-compose up -d`

### CLI not found
- Ensure virtual environment is activated
- Reinstall: `pip install -e .`

### Migrations failed
- Reset database: `inv db reset --yes`
- Check PostgreSQL logs: `docker logs inventory-db`
