# Repository Consolidation Research & Recommendations

**Date**: 2025-11-29
**Author**: Claude Code (automated analysis)
**Status**: Research Complete - Pending Review
**Scope**: ra-infrastructure, network-tools, ra-home-automation

---

## Executive Summary

Three repositories have overlapping concerns that require consolidation:
- **ra-infrastructure**: Central database and Docker services (PostgreSQL + Python CLI)
- **network-tools**: Network scanning tools (currently empty skeleton)
- **ra-home-automation**: Home automation (contains 70% generic code that should migrate)

**Key Finding**: `ra-home-automation` contains a fully functional network discovery system with 469+ tracked devices that should be split between `ra-infrastructure` (database/inventory) and `network-tools` (scanning).

---

## Repository Analysis

### 1. ra-infrastructure

**Location**: Runs on separate PC/Docker
**Purpose**: Central database, Docker services, device inventory
**GitHub Remote**: `https://github.com/score-ra/ra-infrastructure`

#### What's Implemented

| Component | Status | Details |
|-----------|--------|---------|
| PostgreSQL Database | Complete | 5 migrations, comprehensive schema |
| Python CLI (`inv` command) | Complete | All CRUD operations for org/site/zone/device/network |
| Docker Compose | Complete | PostgreSQL 16 + pgAdmin 4 |
| Device Schema | Complete | Categories, usage status, audit logging |
| Integration Points | Schema Ready | `homeseer_ref` column, sync tracking tables |
| REST API | Not Started | Documented as "future" |
| Sync Commands | Not Started | No HomeSeer/network sync code |

#### Database Schema (5 Migrations)

```
organizations (UUID, slug, type: home/business/lab/other)
└── sites (address, geolocation, timezone)
    └── zones (hierarchical, room types)
        └── devices (469+ device fields)
            └── networks (ethernet, wifi, zwave, zigbee, bluetooth, thread, matter)
                └── ip_allocations (static/DHCP/reserved)

Supporting tables:
- device_categories (8 pre-populated)
- audit_log (change tracking)
- sync_history (integration sync tracking)
- import_history (CSV/JSON import tracking)
```

#### CLI Commands Available

```bash
# Organizations
inv org list|show|create|delete

# Sites
inv site list|show|create|delete

# Zones
inv zone list|show|create|delete|types

# Devices (10+ commands)
inv device list|show|create|update|delete|count
inv device store|activate|fail|retire|pending  # Usage status management

# Networks
inv network list|show|create|delete|types|ips

# Database utilities
inv db health|stats|tables|migrate|seed|reset|schema|monitor
```

#### Git History Issue

During today's session, a merge combined unrelated histories:
- **Local content**: "Personal infrastructure tools" (scripts, guides, Obsidian setup)
- **Remote content**: "Device inventory database" system
- **Result**: Local content was overwritten by remote

**Action Required**: Determine if local "personal tools" content needs recovery.

---

### 2. network-tools

**Location**: Same PC as ra-home-automation
**Purpose**: Network scanning and device discovery
**Status**: Empty skeleton - no actual code implemented

#### What Exists

| Component | Status | Details |
|-----------|--------|---------|
| Python Framework | Skeleton | Empty `src/shared/config.py` and `utils.py` |
| Network Scanning | Not Implemented | Dependencies commented out (scapy, nmap, requests) |
| Device Inventory | Markdown Files | Manual documentation, not database |
| Tests | Not Written | Framework ready, no tests |
| Database Integration | None | No connectivity to ra-infrastructure |

#### Current Device Storage (Markdown-based)

```
organizations/
├── sc-office/
│   ├── README.md (network topology)
│   └── devices/
│       └── epson-wf7840.md (device specs)
└── ra-home-31-nt/
    ├── README.md (network topology)
    └── devices/ (empty)
```

#### Organization Data

| Organization | Subnet | Devices Documented |
|--------------|--------|-------------------|
| sc-office | 192.168.1.0/24 | 1 (Epson printer) |
| ra-home-31-nt | 192.168.68.0/24 | 2 (Windows PCs) |

---

### 3. ra-home-automation

**Location**: Same PC as network-tools (192.168.68.x network)
**Purpose**: HomeSeer/BlueIris automation
**Status**: Contains significant code that belongs elsewhere

#### What Should STAY (Home Automation Specific)

| Component | Location | Purpose |
|-----------|----------|---------|
| Windows Setup Scripts | `scripts/setup/` | 20+ scripts for Windows 11 + HomeSeer + BlueIris + HA |
| HomeSeer Device Export | `scripts/inventory/Export-HomeSeerDevices.ps1` | Export 459 devices |
| System Inventory | `scripts/inventory/Collect-SystemInventory.ps1` | Remote WMI collection |
| Migration Assessment | `scripts/migration/` | Win10→Win11 readiness |
| Remote Access | `scripts/remote-access/` | PowerShell remoting setup |
| All Documentation | `docs/` | Property-specific docs |
| Zigbee Diagnostics | `scripts/diagnose-zigbee-issue.ps1` | Troubleshooting |

#### What Should MIGRATE (Generic Infrastructure)

##### To ra-infrastructure (Database/Inventory)

| Component | Current Location | Description |
|-----------|------------------|-------------|
| Device Database | `scripts/network-discovery/lib/DeviceDatabase.ps1` | JSON-based CRUD with snapshots |
| Device Inventory Data | `scripts/network-discovery/data/device-inventory.json` | 469+ devices tracked |
| MAC Vendor Lookup | `scripts/network-discovery/lib/MacVendorLookup.ps1` | IEEE OUI database (20,000+ vendors) |
| Device Categories | `scripts/network-discovery/config/device-categories.json` | 7 category definitions |
| Known Devices | `scripts/network-discovery/config/known-devices.json` | Whitelist |

##### To network-tools (Scanning)

| Component | Current Location | Description |
|-----------|------------------|-------------|
| PowerShell Scanner | `scripts/network-discovery/scanners/Scan-NetworkPowerShell.ps1` | Concurrent ping sweep |
| ARP Scanner | `scripts/network-discovery/scanners/Scan-NetworkARP.ps1` | Fast passive scanning (<30s) |
| Nmap Scanner | `scripts/network-discovery/scanners/Scan-NetworkNmap.ps1` | Advanced scanning wrapper |
| Change Detection | `scripts/network-discovery/lib/ChangeDetection.ps1` | New/missing device alerts |
| Report Generator | `scripts/network-discovery/lib/ReportGenerator.ps1` | JSON/CSV/Markdown/HTML output |
| Scan Config | `scripts/network-discovery/config/scan-config.json` | Timeouts, alerts, subnets |
| Orchestrator | `scripts/network-discovery/Invoke-NetworkDiscovery.ps1` | Main entry point |
| Integration Stub | `scripts/network-discovery/lib/Integration.ps1` | HA/HomeSeer hooks |

---

## Device Inventory Analysis

### Current State: 3 Separate Inventories

| Location | Format | Device Count | Integration |
|----------|--------|--------------|-------------|
| ra-infrastructure | PostgreSQL | 0 (empty) | CLI ready |
| ra-home-automation | JSON | 469+ | PowerShell scripts |
| network-tools | Markdown | 3 | Manual documentation |

### Device Data Fields (ra-home-automation JSON)

```json
{
  "mac": "AA:BB:CC:DD:EE:FF",
  "ip": "192.168.68.100",
  "hostname": "device-name",
  "vendor": "Manufacturer Name",
  "category": "Network|IoT|Cameras|Computers|Mobile|Entertainment|Automation",
  "location": {
    "floor": "First Floor",
    "room": "Living Room"
  },
  "firstSeen": "2025-01-15T10:30:00Z",
  "lastSeen": "2025-11-29T08:00:00Z",
  "appearanceCount": 150,
  "isKnown": true,
  "notes": "Optional notes"
}
```

### Field Mapping to ra-infrastructure Schema

| JSON Field | PostgreSQL Column | Notes |
|------------|-------------------|-------|
| mac | mac_address | Direct mapping |
| ip | ip_address | Direct mapping |
| hostname | hostname | Direct mapping |
| vendor | manufacturer | Direct mapping |
| category | device_category_id | FK to device_categories |
| location.floor | zone_id (floor) | Create zone hierarchy |
| location.room | zone_id (room) | Create zone hierarchy |
| firstSeen | created_at | Direct mapping |
| lastSeen | last_seen_at | New column needed? |
| appearanceCount | metadata.appearance_count | JSONB field |
| isKnown | is_known | New column needed? |
| notes | notes | Direct mapping |

---

## Technology Stack Comparison

| Aspect | ra-infrastructure | network-tools | ra-home-automation |
|--------|-------------------|---------------|-------------------|
| Language | Python 3.11+ | Python (planned) | PowerShell |
| Database | PostgreSQL 16 | None | JSON files |
| CLI Framework | Typer | Click (planned) | Native PS |
| ORM/DB Access | psycopg3 + Repository Pattern | None | None |
| Testing | pytest (79 tests) | pytest (0 tests) | None |
| Docker | Yes (PostgreSQL, pgAdmin) | No | No |

---

## Recommendations

### 1. Consolidate Device Inventory to PostgreSQL

**Rationale**:
- ra-infrastructure has a production-ready schema
- Single source of truth eliminates sync issues
- Enables cross-repository queries
- Audit logging built-in

**Action**: Import 469 devices from JSON to PostgreSQL

### 2. Keep PowerShell Scanners (Don't Port to Python)

**Rationale**:
- Working code with 469 devices already tracked
- PowerShell is native to Windows (primary platform)
- Network scanning requires Windows-specific features (WMI, ARP cache)
- Porting would take significant effort with no functional gain

**Action**: Add PostgreSQL connectivity to PowerShell scripts via `Npgsql` module

### 3. Migration Order

**Phase 1**: Migrate database components to ra-infrastructure
- DeviceDatabase.ps1, MacVendorLookup.ps1, device-categories.json
- Import device-inventory.json to PostgreSQL

**Phase 2**: Migrate scanning components to network-tools
- All scanners, change detection, reporting
- Update imports to reference ra-infrastructure database

**Phase 3**: Update ra-home-automation
- Remove migrated code
- Add references to network-tools for scanning
- Keep home-automation specific scripts

### 4. Integration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ra-infrastructure                         │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │  PostgreSQL DB  │  │  Python CLI     │                   │
│  │  (Port 5432)    │◄─┤  (inv command)  │                   │
│  └────────┬────────┘  └─────────────────┘                   │
│           │                                                  │
│           │ TCP/IP                                           │
└───────────┼─────────────────────────────────────────────────┘
            │
            ▼
┌───────────────────────────────────────────────────────────────┐
│                      network-tools                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────┐ │
│  │ PowerShell      │  │ Change          │  │ Report        │ │
│  │ Scanners        │─►│ Detection       │─►│ Generator     │ │
│  └─────────────────┘  └────────┬────────┘  └───────────────┘ │
│                                │                              │
│                                ▼                              │
│                       ┌─────────────────┐                     │
│                       │ Npgsql Module   │──► PostgreSQL       │
│                       │ (DB Writer)     │                     │
│                       └─────────────────┘                     │
└───────────────────────────────────────────────────────────────┘
            │
            │ Scheduled scans
            ▼
┌───────────────────────────────────────────────────────────────┐
│                   ra-home-automation                           │
│  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────┐ │
│  │ HomeSeer        │  │ BlueIris        │  │ Windows       │ │
│  │ Integration     │  │ Integration     │  │ Setup Scripts │ │
│  └─────────────────┘  └─────────────────┘  └───────────────┘ │
│                                                               │
│  Calls network-tools for device discovery                     │
│  Queries ra-infrastructure for device inventory               │
└───────────────────────────────────────────────────────────────┘
```

---

## Open Questions Requiring Decision

### Q1: Language Strategy
Keep PowerShell scanners and add PostgreSQL connectivity, or port everything to Python?

**Recommendation**: Keep PowerShell (working code, Windows-native)

### Q2: Device Inventory Consolidation
Import all 469 devices to PostgreSQL and deprecate JSON/Markdown inventories?

**Recommendation**: Yes - single source of truth

### Q3: Git History Recovery
The earlier merge overwrote "personal tools" content. Does it need recovery?

**Recommendation**: Investigate what was lost before deciding

### Q4: Implementation Priority
- **Option A**: Clean separation first (move code, then integrate)
- **Option B**: Working scanner first (get network-tools populating DB)

**Recommendation**: Option A - cleaner foundation prevents future issues

---

## Critical Files for Implementation

### ra-infrastructure
- `cli/src/inventory/db/repositories/device.py` - Device repository
- `database/migrations/003_inventory_devices.sql` - Device schema
- `database/seeds/001_initial_data.sql` - Seed data format

### ra-home-automation (to migrate)
- `scripts/network-discovery/lib/DeviceDatabase.ps1` - Current DB logic
- `scripts/network-discovery/data/device-inventory.json` - 469+ devices
- `scripts/network-discovery/Invoke-NetworkDiscovery.ps1` - Orchestrator
- `scripts/network-discovery/lib/MacVendorLookup.ps1` - Vendor lookup

### network-tools
- `requirements.txt` - Dependencies to add
- `src/shared/config.py` - Configuration structure

---

## Next Steps

1. **Review this document** on the other PC
2. **Decide on open questions** (Q1-Q4 above)
3. **Create migration tickets/tasks** based on decisions
4. **Execute Phase 1** (database migration)
5. **Execute Phase 2** (scanner migration)
6. **Execute Phase 3** (cleanup ra-home-automation)
7. **Test end-to-end** integration

---

## Appendix: Device Categories (from ra-home-automation)

```json
{
  "categories": [
    {
      "name": "Network",
      "vendors": ["Cisco", "TP-Link", "Netgear", "Ubiquiti", "Aruba"]
    },
    {
      "name": "IoT",
      "vendors": ["Tuya", "Shelly", "Sonoff", "Wemo", "Kasa"]
    },
    {
      "name": "Cameras",
      "vendors": ["Amcrest", "Hikvision", "Reolink", "Wyze"]
    },
    {
      "name": "Computers",
      "vendors": ["Dell", "HP", "Lenovo", "Apple", "Microsoft"]
    },
    {
      "name": "Mobile",
      "vendors": ["Apple", "Samsung", "Google", "OnePlus"]
    },
    {
      "name": "Entertainment",
      "vendors": ["Roku", "Amazon", "Google", "Sony", "LG"]
    },
    {
      "name": "Automation",
      "vendors": ["HomeSeer", "Hubitat", "SmartThings", "Zigbee", "Z-Wave"]
    }
  ]
}
```

---

*Document generated by Claude Code analysis of three repositories.*
*Review and approve before implementation begins.*
