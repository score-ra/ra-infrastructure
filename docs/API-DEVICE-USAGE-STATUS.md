# Device Usage Status API Reference

This document describes the `usage_status` feature for the `devices` table, enabling external repositories to integrate with device deployment state tracking.

## Overview

The `usage_status` column tracks the **deployment state** of a device, which is orthogonal to the `status` column (operational/connectivity state). This allows you to know both:
- **status**: Is the device online/offline? (operational state)
- **usage_status**: Is the device deployed, stored, or retired? (deployment state)

## Database Schema

### New Columns

| Column | Type | Default | Nullable | Description |
|--------|------|---------|----------|-------------|
| `usage_status` | VARCHAR(50) | 'active' | NOT NULL | Deployment state |
| `storage_location` | VARCHAR(255) | NULL | YES | Physical storage location |
| `failure_date` | DATE | NULL | YES | Date device failed |
| `failure_reason` | TEXT | NULL | YES | Description of failure |
| `rma_reference` | VARCHAR(100) | NULL | YES | RMA/warranty claim reference |

### Usage Status Values

| Value | Description | Typical `status` Values |
|-------|-------------|------------------------|
| `active` | Currently installed and in use | online, offline, unknown, maintenance |
| `stored` | Functional, in storage (spare, seasonal, awaiting deployment) | offline, unknown |
| `failed` | Hardware failure, out of service | offline, decommissioned |
| `retired` | Permanently out of service, kept for records | decommissioned |
| `pending` | Newly acquired, not yet deployed | unknown |

### Check Constraint

```sql
CHECK (usage_status IN ('active', 'stored', 'failed', 'retired', 'pending'))
```

### Index

```sql
CREATE INDEX idx_devices_usage_status ON devices(usage_status);
```

## Connection Details

```
Host: localhost
Port: 5432
Database: inventory
User: inventory
Password: inventory_dev_password
```

## Common Queries

### List all active (deployed) devices

```sql
SELECT id, name, slug, device_type, status
FROM devices
WHERE usage_status = 'active'
  AND is_active = TRUE
ORDER BY name;
```

### List stored (spare) devices

```sql
SELECT id, name, slug, device_type, storage_location, updated_at
FROM devices
WHERE usage_status = 'stored'
ORDER BY updated_at DESC;
```

### List failed devices (potential warranty claims)

```sql
SELECT
    id, name, slug, device_type,
    failure_date, failure_reason, rma_reference,
    warranty_expiry
FROM devices
WHERE usage_status = 'failed'
ORDER BY failure_date DESC;
```

### List failed devices still under warranty

```sql
SELECT name, failure_date, failure_reason, warranty_expiry
FROM devices
WHERE usage_status = 'failed'
  AND warranty_expiry > CURRENT_DATE;
```

### Count devices by usage status

```sql
SELECT usage_status, COUNT(*) as count
FROM devices
GROUP BY usage_status
ORDER BY count DESC;
```

### Find devices by site and usage status

```sql
SELECT d.name, d.device_type, d.usage_status, d.storage_location
FROM devices d
JOIN sites s ON d.site_id = s.id
WHERE s.slug = 'primary-residence'
  AND d.usage_status IN ('stored', 'pending')
ORDER BY d.name;
```

## Updating Usage Status

### Mark device as stored

```sql
UPDATE devices
SET usage_status = 'stored',
    storage_location = 'Server closet, shelf 3',
    status = 'offline'
WHERE slug = 'spare-motion-sensor';
```

### Mark device as active (restore from storage)

```sql
UPDATE devices
SET usage_status = 'active',
    storage_location = NULL,
    failure_date = NULL,
    failure_reason = NULL,
    rma_reference = NULL
WHERE slug = 'spare-motion-sensor';
```

### Mark device as failed

```sql
UPDATE devices
SET usage_status = 'failed',
    status = 'offline',
    failure_date = CURRENT_DATE,
    failure_reason = 'Stopped responding, no LED indicator',
    rma_reference = 'RMA-2025-001'
WHERE slug = 'kitchen-dimmer';
```

### Mark device as retired

```sql
UPDATE devices
SET usage_status = 'retired',
    status = 'decommissioned'
WHERE slug = 'old-hub-v1';
```

### Mark device as pending (new acquisition)

```sql
UPDATE devices
SET usage_status = 'pending',
    status = 'unknown'
WHERE slug = 'new-thermostat';
```

## CLI Commands (ra-infrastructure)

If using the `inv` CLI from ra-infrastructure:

```bash
# List devices filtered by usage status
inv device list --usage-status stored
inv device list --usage-status failed

# Count devices by usage status
inv device count --by usage

# Change usage status
inv device store <slug> --location "Server closet"
inv device activate <slug>
inv device fail <slug> --reason "Power surge damage" --rma "RMA-123"
inv device retire <slug> --yes
inv device pending <slug>
```

## Integration Example (Python)

```python
import psycopg2
from psycopg2.extras import RealDictCursor

def get_connection():
    return psycopg2.connect(
        host="localhost",
        port=5432,
        database="inventory",
        user="inventory",
        password="inventory_dev_password",
        cursor_factory=RealDictCursor
    )

def get_active_devices(site_slug: str = None):
    """Get all active (deployed) devices."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            query = """
                SELECT d.*, s.name as site_name, z.name as zone_name
                FROM devices d
                JOIN sites s ON d.site_id = s.id
                LEFT JOIN zones z ON d.zone_id = z.id
                WHERE d.usage_status = 'active'
                  AND d.is_active = TRUE
            """
            params = []
            if site_slug:
                query += " AND s.slug = %s"
                params.append(site_slug)
            query += " ORDER BY d.name"

            cur.execute(query, params)
            return cur.fetchall()

def get_stored_devices():
    """Get all stored (spare) devices."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, name, slug, device_type, storage_location, updated_at
                FROM devices
                WHERE usage_status = 'stored'
                ORDER BY name
            """)
            return cur.fetchall()

def mark_device_failed(slug: str, reason: str = None, rma: str = None):
    """Mark a device as failed."""
    from datetime import date

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE devices
                SET usage_status = 'failed',
                    status = 'offline',
                    failure_date = %s,
                    failure_reason = %s,
                    rma_reference = %s
                WHERE slug = %s
                RETURNING id
            """, (date.today(), reason, rma, slug))
            conn.commit()
            return cur.fetchone()
```

## Best Practices

1. **Always filter by `usage_status = 'active'`** when listing devices for automation/control purposes
2. **Update `status` alongside `usage_status`** when changing deployment state:
   - `stored` → set `status = 'offline'`
   - `failed` → set `status = 'offline'`
   - `retired` → set `status = 'decommissioned'`
   - `pending` → set `status = 'unknown'`
3. **Clear tracking fields** when activating a device (set storage_location, failure_* to NULL)
4. **Record failure information** when marking as failed for warranty tracking

## Related Documentation

- [CR-001: Device Usage Status Enhancement](../ra-home-automation/docs/change-requests/CR-001-device-usage-status.md) - Original change request
- [database/migrations/005_device_usage_status.sql](../database/migrations/005_device_usage_status.sql) - Migration script
