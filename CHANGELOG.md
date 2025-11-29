# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Cross-repository dependency management documentation
  - `DEPENDENTS.md` - Registry of repos that depend on this database
  - `docs/SCHEMA-CONTRACT.md` - Public vs internal schema definitions
  - `CHANGELOG.md` - This file

### Changed
- None

### Schema Changes
- None

---

## [1.0.0] - 2025-11-25

### Added
- Initial database schema with 5 migrations
- Python CLI (`inv` command) for device inventory management
- Docker Compose setup for PostgreSQL 16 + pgAdmin 4

### Schema (Migrations 001-005)

#### Migration 001: Core Organizations
- `organizations` - Top-level organizational units
- `sites` - Physical locations
- `zones` - Logical areas (rooms, floors)

#### Migration 002: Core Networks
- `networks` - Network segments (IP, WiFi, Z-Wave, Zigbee)
- `ip_allocations` - IP address assignments
- `network_vlans` - VLAN definitions

#### Migration 003: Inventory Devices
- `devices` - Core device inventory
- `device_categories` - Device categorization (8 pre-populated)
- `device_connections` - Device topology
- `device_attributes` - Flexible key-value attributes

#### Migration 004: Inventory Audit
- `audit_log` - Change tracking
- `sync_history` - External sync tracking
- `import_batches` - Bulk import tracking

#### Migration 005: Device Usage Status
- Added `usage_status` column to devices table
- Values: stored, pending, active, failed, retired

---

## Schema Change Template

When documenting schema changes, use this format:

```markdown
### Schema Changes
- **BREAKING**: Description of breaking change
  - Affects: [list dependent repos from DEPENDENTS.md]
  - Migration: Steps to migrate
  - Deprecation: Date when old behavior will be removed

- Added `column_name` to `table_name` - Description
- Changed `column_name` type from X to Y (non-breaking)
```
