# Schema Contract

This document defines the stability guarantees for the ra_inventory database schema.

**Version**: 1.0
**Last Updated**: 2025-11-29

## Overview

The ra_inventory database schema is divided into **public** and **internal** tables:
- **Public tables** are stable and versioned. Breaking changes require deprecation notice.
- **Internal tables** may change without notice. Do not depend on them directly.

---

## Public Tables (Stable)

These tables are part of the public API. Breaking changes will be:
1. Documented in CHANGELOG.md
2. Communicated to dependents via GitHub issues
3. Given a deprecation period before removal

### Core Hierarchy

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `organizations` | Top-level organizational units | id, slug, name, type |
| `sites` | Physical locations | id, organization_id, slug, name, timezone |
| `zones` | Logical areas (rooms, floors) | id, site_id, parent_zone_id, slug, zone_type |

### Network Infrastructure

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `networks` | Network segments (IP, WiFi, mesh) | id, site_id, slug, network_type, cidr |
| `ip_allocations` | IP address assignments | id, network_id, device_id, ip_address, mac_address |

### Device Inventory

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `devices` | Core device inventory | id, site_id, slug, mac_address, ip_address, hostname, manufacturer, status, last_seen |
| `device_categories` | Device categorization lookup | id, slug, name |
| `device_connections` | Physical/logical device topology | id, source_device_id, target_device_id, connection_type |
| `device_attributes` | Flexible key-value attributes | id, device_id, attribute_key, attribute_value |

---

## Internal Tables (Unstable)

These tables are implementation details. They may change without notice.
**Do not build integrations that depend on these directly.**

| Table | Purpose | Why Internal |
|-------|---------|--------------|
| `audit_log` | Change tracking | Internal implementation of audit trail |
| `sync_history` | External sync tracking | Implementation detail for sync operations |
| `import_batches` | Bulk import tracking | Implementation detail for import operations |
| `network_vlans` | VLAN definitions | May be restructured or merged |

If you need data from internal tables, request a public API or view.

---

## Stability Guarantees

### What We Promise

1. **Additive changes are non-breaking**: New columns, new tables, new indexes
2. **Public columns won't disappear**: Removal requires deprecation notice
3. **Data types won't change incompatibly**: `VARCHAR` → `TEXT` is OK; `INTEGER` → `VARCHAR` requires notice
4. **Foreign keys remain stable**: Relationship structure won't change without notice

### What May Change Without Notice

1. Internal table structure
2. Index names and composition
3. Constraint names
4. Default values (unless documented as part of contract)
5. JSONB field internal structure in `metadata` columns

### Breaking Changes

A breaking change is:
- Removing a public column
- Renaming a public column
- Changing a column's data type incompatibly
- Removing a public table
- Changing foreign key relationships

Breaking changes will:
1. Be prefixed with `BREAKING_` in migration filename
2. Be documented in CHANGELOG.md
3. Trigger GitHub issues in dependent repos (per DEPENDENTS.md)
4. Allow time for dependents to update before removal

---

## Column Stability by Table

### devices (Primary Integration Point)

| Column | Stability | Notes |
|--------|-----------|-------|
| `id` | Stable | UUID primary key |
| `site_id` | Stable | Required FK to sites |
| `slug` | Stable | Unique within site |
| `name` | Stable | Display name |
| `mac_address` | Stable | Primary matching key for discovery |
| `ip_address` | Stable | Network address |
| `hostname` | Stable | DNS hostname |
| `manufacturer` | Stable | Device manufacturer |
| `device_type` | Stable | Specific device type |
| `category_id` | Stable | FK to device_categories |
| `status` | Stable | online/offline/unknown/maintenance/decommissioned |
| `last_seen` | Stable | Last discovery timestamp |
| `metadata` | Stable (structure unstable) | JSONB - keys within may change |
| `homeseer_ref` | Stable | HomeSeer integration reference |
| Integration columns | Semi-stable | `homeassistant_entity_id`, `blueiris_short_name` |

---

## Migration Naming Convention

```
NNN_description.sql           # Non-breaking change
NNN_BREAKING_description.sql  # Breaking change requiring dependent updates
```

Examples:
```
006_add_last_seen_column.sql      # Additive - safe
007_add_device_notes.sql          # Additive - safe
008_BREAKING_rename_mac_field.sql # Breaking - requires coordination
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-29 | Initial schema contract |
