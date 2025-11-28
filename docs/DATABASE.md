# ra-infrastructure Database Guide

This document describes how external repositories can connect to and use the ra-infrastructure database.

---

## Schema Ownership Policy

**IMPORTANT: The database schema is owned and managed exclusively by the `ra-infrastructure` repository.**

### For External Repositories

- **READ-ONLY ACCESS**: External repositories may query the database but must NOT create, alter, or drop tables
- **NO DIRECT SCHEMA CHANGES**: Do not include migration files that modify this database's structure
- **CHANGE REQUEST PROCESS**: If schema changes are needed, submit a Change Request (CR) to the ra-infrastructure repository:
  1. Create an issue in `ra-infrastructure` describing the requirement
  2. Tag it with `schema-change-request`
  3. Include: use case, proposed changes, affected queries, and urgency
  4. Wait for approval before proceeding
- **SCHEMA REFERENCE**: Always refer to this document or run `inv db schema` for the current schema

### Schema Diagram

View the current schema as a visual ER diagram:

```bash
# Generate PNG diagram (in ra-infrastructure repo)
inv db schema

# Output: docs/schema.png
```

Or view the auto-generated [schema.png](schema.png) in this docs folder.

For full interactive documentation: `inv db schema -f html` then open `docs/schema/index.html`.

---

## Connection Details

| Setting | Value |
|---------|-------|
| **Host** | `localhost` |
| **Port** | `5432` |
| **Database** | `ra_inventory` |
| **User** | `inventory` |
| **Password** | `inventory_dev_password` |

## Quick Start

### 1. Ensure Database is Running

```powershell
cd ra-infrastructure/docker
docker-compose up -d
```

### 2. Verify Connection

```powershell
# Using the CLI
inv db stats

# Or via psql
psql -h localhost -U inventory -d ra_inventory
```

## Schema Overview

```
organizations
├── sites
│   ├── zones (hierarchical)
│   ├── networks
│   │   └── ip_allocations
│   └── devices
│       └── device_attributes
└── device_categories
```

## Core Tables

### organizations

Top-level multi-tenant container.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `name` | VARCHAR(255) | Display name |
| `slug` | VARCHAR(100) | URL-friendly identifier (unique) |
| `type` | VARCHAR(50) | home, business, lab, other |
| `is_active` | BOOLEAN | Soft delete flag |
| `metadata` | JSONB | Flexible attributes |

### sites

Physical locations within an organization.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `organization_id` | UUID | FK to organizations |
| `name` | VARCHAR(255) | Display name |
| `slug` | VARCHAR(100) | Unique within organization |
| `site_type` | VARCHAR(50) | residence, office, datacenter, warehouse, other |
| `city`, `state`, `country` | VARCHAR | Location info |
| `timezone` | VARCHAR(50) | Default: America/Los_Angeles |
| `is_primary` | BOOLEAN | Primary site flag |
| `metadata` | JSONB | Flexible attributes |

### zones

Logical areas within a site (rooms, floors, closets). Supports hierarchy.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `site_id` | UUID | FK to sites |
| `parent_zone_id` | UUID | FK to zones (self-referential) |
| `name` | VARCHAR(255) | Display name |
| `slug` | VARCHAR(100) | Unique within site |
| `zone_type` | VARCHAR(50) | building, floor, room, closet, outdoor, garage, other |
| `floor_number` | INTEGER | Floor level |
| `sort_order` | INTEGER | Display ordering |

### devices

All tracked devices.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `site_id` | UUID | FK to sites (required) |
| `zone_id` | UUID | FK to zones (optional) |
| `network_id` | UUID | FK to networks (optional) |
| `category_id` | UUID | FK to device_categories (optional) |
| `name` | VARCHAR(255) | Display name |
| `slug` | VARCHAR(100) | Unique within site |
| `device_type` | VARCHAR(100) | Device type string |
| `status` | VARCHAR(50) | online, offline, unknown, maintenance |
| `manufacturer` | VARCHAR(255) | Manufacturer name |
| `model` | VARCHAR(255) | Model number |
| `serial_number` | VARCHAR(255) | Serial number |
| `mac_address` | MACADDR | MAC address |
| `ip_address` | INET | IP address |
| `hostname` | VARCHAR(255) | DNS hostname |
| `firmware_version` | VARCHAR(100) | Firmware version |
| `is_active` | BOOLEAN | Soft delete flag |
| `metadata` | JSONB | Flexible attributes |

### networks

Network configurations.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `site_id` | UUID | FK to sites |
| `name` | VARCHAR(255) | Display name |
| `slug` | VARCHAR(100) | Unique within site |
| `network_type` | VARCHAR(50) | ethernet, wifi, zwave, zigbee, bluetooth, thread, matter, other |
| `cidr` | CIDR | Network CIDR (e.g., 192.168.1.0/24) |
| `gateway_ip` | INET | Gateway IP address |
| `vlan_id` | INTEGER | VLAN ID (1-4094) |
| `ssid` | VARCHAR(100) | WiFi SSID |
| `is_primary` | BOOLEAN | Primary network flag |

### ip_allocations

IP address assignments within networks.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `network_id` | UUID | FK to networks |
| `device_id` | UUID | FK to devices (optional) |
| `ip_address` | INET | IP address |
| `hostname` | VARCHAR(255) | DNS hostname |
| `allocation_type` | VARCHAR(50) | static, dhcp_reserved, dhcp_dynamic |
| `is_active` | BOOLEAN | Active flag |
| `last_seen` | TIMESTAMPTZ | Last seen timestamp |

### device_categories

Device classification categories.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `name` | VARCHAR(255) | Category name |
| `slug` | VARCHAR(100) | Unique identifier |
| `parent_category_id` | UUID | FK for hierarchy |
| `icon` | VARCHAR(50) | Icon identifier |

## Python Connection Examples

### Using psycopg (psycopg3)

```python
import psycopg
from psycopg.rows import dict_row

# Connect
conn = psycopg.connect(
    host="localhost",
    port=5432,
    dbname="ra_inventory",
    user="inventory",
    password="inventory_dev_password",
    row_factory=dict_row,
)

# Query devices
with conn.cursor() as cur:
    cur.execute("""
        SELECT d.*, s.name as site_name, z.name as zone_name
        FROM devices d
        JOIN sites s ON d.site_id = s.id
        LEFT JOIN zones z ON d.zone_id = z.id
        WHERE d.is_active = TRUE
        ORDER BY d.name
    """)
    devices = cur.fetchall()

for device in devices:
    print(f"{device['name']} - {device['site_name']} / {device['zone_name']}")

conn.close()
```

### Using SQLAlchemy

```python
from sqlalchemy import create_engine, text

engine = create_engine(
    "postgresql+psycopg://inventory:inventory_dev_password@localhost:5432/ra_inventory"
)

with engine.connect() as conn:
    result = conn.execute(text("SELECT * FROM devices WHERE is_active = TRUE"))
    for row in result:
        print(row)
```

### Environment Variables

You can also use environment variables:

```python
import os

DB_CONFIG = {
    "host": os.getenv("RA_DB_HOST", "localhost"),
    "port": int(os.getenv("RA_DB_PORT", "5432")),
    "dbname": os.getenv("RA_DB_NAME", "ra_inventory"),
    "user": os.getenv("RA_DB_USER", "inventory"),
    "password": os.getenv("RA_DB_PASSWORD", "inventory_dev_password"),
}
```

## Common Queries

### Get all devices at a site

```sql
SELECT d.*, z.name as zone_name, n.name as network_name
FROM devices d
LEFT JOIN zones z ON d.zone_id = z.id
LEFT JOIN networks n ON d.network_id = n.id
WHERE d.site_id = (SELECT id FROM sites WHERE slug = 'primary-residence')
  AND d.is_active = TRUE
ORDER BY d.name;
```

### Get devices by zone hierarchy

```sql
WITH RECURSIVE zone_tree AS (
    SELECT id, name, parent_zone_id, 0 as depth
    FROM zones WHERE slug = 'first-floor'
    UNION ALL
    SELECT z.id, z.name, z.parent_zone_id, zt.depth + 1
    FROM zones z
    JOIN zone_tree zt ON z.parent_zone_id = zt.id
)
SELECT d.*
FROM devices d
JOIN zone_tree zt ON d.zone_id = zt.id
WHERE d.is_active = TRUE;
```

### Get network with device count

```sql
SELECT n.*, COUNT(d.id) as device_count
FROM networks n
LEFT JOIN devices d ON d.network_id = n.id AND d.is_active = TRUE
WHERE n.site_id = (SELECT id FROM sites WHERE slug = 'primary-residence')
GROUP BY n.id
ORDER BY n.name;
```

### Find device by MAC address

```sql
SELECT d.*, s.name as site_name
FROM devices d
JOIN sites s ON d.site_id = s.id
WHERE d.mac_address = '00:1A:2B:3C:4D:5E';
```

### Get IP allocations for a network

```sql
SELECT ip.*, d.name as device_name
FROM ip_allocations ip
LEFT JOIN devices d ON ip.device_id = d.id
WHERE ip.network_id = (SELECT id FROM networks WHERE slug = 'main-lan')
ORDER BY ip.ip_address;
```

## pgAdmin Access

pgAdmin is available at `http://localhost:5050`:
- **Email**: `admin@admin.com`
- **Password**: `admin`

Then add the server:
- **Host**: `postgres` (Docker network name)
- **Port**: `5432`
- **Database**: `ra_inventory`
- **User**: `inventory`
- **Password**: `inventory_dev_password`

## CLI Commands

The `inv` CLI provides convenient access:

```bash
# List all devices
inv device list

# Show device details
inv device show <slug>

# List networks
inv network list

# Show network with IPs
inv network ips <network-slug>

# Database stats
inv db stats
```

## Notes

- All primary keys are UUIDs
- Timestamps use `TIMESTAMPTZ` (timezone-aware)
- Soft deletes via `is_active` flag
- `metadata` columns are JSONB for flexible attributes
- Slugs are unique within their parent scope (e.g., device slugs unique within site)
