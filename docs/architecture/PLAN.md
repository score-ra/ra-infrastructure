# ra-infrastructure Architecture Plan

> **Status**: Draft - Pending User Approval
> **Created**: 2025-11-26
> **Author**: Claude (with Rohit Anand)

## Executive Summary

This document defines the architecture for `ra-infrastructure`, a home infrastructure management system for tracking devices, networks, and sites across multiple locations.

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| API Layer | CLI only | Simplicity; web app embeds in CLI |
| Integration Priority | HomeSeer first | Primary automation system |
| Multi-Site Support | 4+ sites | Family members, offices |
| Automation Scope | Inventory only | Track, don't control |
| Deployment | Single Windows machine | HomeSeer server |
| Web UI | Full CRUD + topology | Embedded Python web server |
| Security | VPN access only | No public exposure |

---

## 1. System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     ra-infrastructure System                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐  │
│  │   CLI (inv)  │    │ Web Dashboard│    │  Scheduled Tasks     │  │
│  │              │    │ (inv web)    │    │  (Windows Scheduler) │  │
│  └──────┬───────┘    └──────┬───────┘    └──────────┬───────────┘  │
│         │                   │                       │               │
│         └───────────────────┼───────────────────────┘               │
│                             │                                        │
│                    ┌────────▼────────┐                              │
│                    │  Shared Python  │                              │
│                    │  Library Layer  │                              │
│                    │  - DB access    │                              │
│                    │  - Models       │                              │
│                    │  - Business     │                              │
│                    └────────┬────────┘                              │
│                             │                                        │
│                    ┌────────▼────────┐                              │
│                    │   PostgreSQL    │                              │
│                    │   (Docker)      │                              │
│                    └─────────────────┘                              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
   ┌──────▼──────┐    ┌───────▼───────┐   ┌──────▼──────┐
   │  HomeSeer   │    │ Network Scan  │   │   Future    │
   │  (Primary)  │    │  (PowerShell) │   │ Integrations│
   └─────────────┘    └───────────────┘   └─────────────┘
```

### Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| **CLI (`inv`)** | All CRUD operations, migrations, imports, reports |
| **Web Dashboard** | Visual interface for browsing, editing, topology |
| **Scheduled Tasks** | Automated network scans, HomeSeer sync |
| **PostgreSQL** | Single source of truth for all inventory data |
| **HomeSeer Integration** | Sync devices from HomeSeer to inventory |
| **Network Scanner** | Discover devices on network, populate inventory |

---

## 2. Component Design

### 2.1 CLI Package Structure

```
cli/
├── src/inventory/
│   ├── __init__.py
│   ├── main.py                 # Typer app entry point
│   ├── config.py               # Settings (pydantic-settings)
│   │
│   ├── commands/               # CLI command groups
│   │   ├── __init__.py
│   │   ├── db.py               # Database utilities
│   │   ├── org.py              # Organization CRUD
│   │   ├── site.py             # Site CRUD
│   │   ├── zone.py             # Zone CRUD (NEW)
│   │   ├── device.py           # Device CRUD
│   │   ├── network.py          # Network CRUD + scanning
│   │   ├── sync.py             # Integration sync commands (NEW)
│   │   └── web.py              # Web server command (NEW)
│   │
│   ├── db/                     # Database layer
│   │   ├── __init__.py
│   │   ├── connection.py       # Connection management
│   │   ├── repositories/       # Data access (NEW)
│   │   │   ├── __init__.py
│   │   │   ├── base.py         # Base repository pattern
│   │   │   ├── organizations.py
│   │   │   ├── sites.py
│   │   │   ├── zones.py
│   │   │   ├── devices.py
│   │   │   └── networks.py
│   │   └── models.py           # Pydantic models (NEW)
│   │
│   ├── integrations/           # External system integrations (NEW)
│   │   ├── __init__.py
│   │   ├── base.py             # Base integration class
│   │   ├── homeseer.py         # HomeSeer API client
│   │   └── network_scanner.py  # PowerShell network discovery
│   │
│   └── web/                    # Web dashboard (NEW)
│       ├── __init__.py
│       ├── app.py              # FastAPI application
│       ├── routes/             # Route handlers
│       │   ├── __init__.py
│       │   ├── dashboard.py    # Home/overview
│       │   ├── organizations.py
│       │   ├── sites.py
│       │   ├── devices.py
│       │   ├── networks.py
│       │   └── topology.py     # Network topology view
│       ├── templates/          # Jinja2 templates
│       │   ├── base.html
│       │   ├── dashboard.html
│       │   ├── devices/
│       │   │   ├── list.html
│       │   │   ├── detail.html
│       │   │   └── form.html
│       │   └── topology/
│       │       └── view.html
│       └── static/             # CSS, JS, images
│           ├── css/
│           ├── js/
│           └── img/
│
├── tests/                      # Test suite
└── pyproject.toml
```

### 2.2 Web Dashboard Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **Web Framework** | FastAPI | Async, modern, easy to embed |
| **Templates** | Jinja2 | Server-rendered, no build step |
| **Interactivity** | HTMX | AJAX without JavaScript complexity |
| **Reactivity** | Alpine.js | Lightweight reactive components |
| **Styling** | Tailwind CSS (CDN) | No build step, utility-first |
| **Topology** | D3.js or Cytoscape.js | Network graph visualization |
| **Tables** | DataTables or AG Grid | Sorting, filtering, pagination |

### 2.3 Database Layer - Repository Pattern

```python
# db/repositories/base.py
class BaseRepository:
    def __init__(self, conn):
        self.conn = conn

    def find_all(self, **filters) -> list[Model]: ...
    def find_by_id(self, id: UUID) -> Model | None: ...
    def find_by_slug(self, slug: str) -> Model | None: ...
    def create(self, data: CreateModel) -> Model: ...
    def update(self, id: UUID, data: UpdateModel) -> Model: ...
    def delete(self, id: UUID) -> bool: ...

# db/repositories/devices.py
class DeviceRepository(BaseRepository):
    def find_by_site(self, site_id: UUID) -> list[Device]: ...
    def find_by_zone(self, zone_id: UUID) -> list[Device]: ...
    def find_by_mac(self, mac: str) -> Device | None: ...
    def find_by_homeseer_ref(self, ref: str) -> Device | None: ...
    def upsert_from_discovery(self, device: DiscoveredDevice) -> Device: ...
```

---

## 3. Integration Architecture

### 3.1 HomeSeer Integration (Priority 1)

```
┌─────────────────┐         ┌─────────────────┐
│    HomeSeer     │  HTTP   │  ra-infra CLI   │
│    HS4 API      │◄───────►│  sync homeseer  │
└─────────────────┘   JSON  └────────┬────────┘
                                     │
                            ┌────────▼────────┐
                            │   PostgreSQL    │
                            │   devices table │
                            └─────────────────┘
```

**HomeSeer API Endpoints Used:**
- `GET /JSON?request=getstatus` - All device status
- `GET /JSON?request=getdevices` - Device definitions
- `GET /JSON?request=getlocations` - Locations (maps to zones)

**Sync Strategy:**
1. Full sync: `inv sync homeseer --full` (initial import)
2. Incremental sync: `inv sync homeseer` (update status, last_seen)
3. Scheduled sync: Windows Task Scheduler runs every 15 minutes

**Field Mapping:**

| HomeSeer Field | PostgreSQL Field |
|----------------|------------------|
| `ref` | `homeseer_ref` |
| `name` | `name` |
| `device_type_string` | `device_type` |
| `location` | `zone_id` (lookup) |
| `location2` | `zone_id` (lookup) |
| `interface` | `metadata.interface` |
| `relationship` | `metadata.relationship` |

### 3.2 Network Discovery Integration

```
┌─────────────────┐         ┌─────────────────┐
│   PowerShell    │  JSON   │  ra-infra CLI   │
│   Scanner       │────────►│  network import │
└─────────────────┘         └────────┬────────┘
                                     │
                            ┌────────▼────────┐
                            │   PostgreSQL    │
                            │   devices table │
                            └─────────────────┘
```

**Discovery Flow:**
1. `Scan-Network.ps1` runs ARP scan + ping sweep
2. Outputs JSON file with discovered devices
3. `inv network import scan.json` upserts to database
4. Devices matched by MAC address (primary key for network devices)

---

## 4. Multi-Site Data Model

### 4.1 Hierarchy

```
Organization (Anand Family)
├── Site (Primary Residence - Fremont)
│   ├── Zone (First Floor)
│   │   ├── Zone (Living Room)
│   │   │   └── Devices...
│   │   └── Zone (Kitchen)
│   └── Zone (Server Closet)
│       └── Devices (HomeSeer, switches, etc.)
│
├── Site (Vacation Home - Tahoe)
│   └── Zones...
│
└── Site (Parents House - San Jose)
    └── Zones...

Organization (Work - SymphonyCore)
└── Site (Office)
    └── Zones...
```

### 4.2 Cross-Site Considerations

| Concern | Approach |
|---------|----------|
| **Unique slugs** | Slugs unique within site, not globally |
| **Network isolation** | Each site has independent networks |
| **Remote management** | VPN to each site, single dashboard |
| **HomeSeer instances** | Each site may have its own HomeSeer (or not) |
| **Data filtering** | All queries scoped by site by default |

### 4.3 Site Configuration

```sql
-- sites table metadata for integration settings
{
    "homeseer_url": "http://192.168.68.56",
    "homeseer_enabled": true,
    "blueiris_url": "http://192.168.68.56:81",
    "blueiris_enabled": false,
    "network_scan_enabled": true,
    "network_scan_cidr": "192.168.68.0/24"
}
```

---

## 5. Web Dashboard Design

### 5.1 Page Structure

```
/                           # Dashboard - overview, stats, recent activity
/organizations              # Org list
/organizations/{slug}       # Org detail + sites
/sites/{slug}               # Site detail + zones + devices
/sites/{slug}/devices       # Device list for site
/sites/{slug}/topology      # Network topology visualization
/devices                    # Global device search
/devices/{slug}             # Device detail
/devices/{slug}/edit        # Device edit form
/networks                   # Network list
/networks/{slug}            # Network detail + IP allocations
/sync                       # Integration status, manual sync triggers
/reports                    # Export reports (CSV, JSON)
```

### 5.2 Dashboard Widgets

| Widget | Content |
|--------|---------|
| **Site Selector** | Dropdown to filter all views by site |
| **Device Stats** | Total devices, online/offline counts |
| **Recent Activity** | Last 10 audit log entries |
| **Network Health** | Devices by status (online/offline/unknown) |
| **Quick Actions** | Run sync, run scan, add device |
| **Alerts** | New devices, missing devices, IP conflicts |

### 5.3 Topology Visualization

```
┌─────────────────────────────────────────────────────────────┐
│  Site: Primary Residence           [Zone Filter ▼]          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│     [Router]                                                 │
│        │                                                     │
│    ┌───┴────┬────────┬────────┐                             │
│    │        │        │        │                             │
│  [Switch] [AP-1]  [AP-2]  [HomeSeer]                        │
│    │                           │                             │
│  ┌─┴──┐                    ┌───┴───┐                        │
│  │    │                    │       │                        │
│ [NAS] [PC]            [Z-Wave] [Zigbee]                     │
│                           │       │                          │
│                      [Devices] [Devices]                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Features:**
- Pan, zoom, drag nodes
- Click node for device details
- Color-coded by status (green=online, red=offline, gray=unknown)
- Filter by network type (Ethernet, WiFi, Z-Wave, Zigbee)
- Show/hide connection labels

---

## 6. Implementation Phases

### Phase 1: Foundation Completion (Current → 1 week)
**Goal**: Complete core CLI and prepare for integrations

| Task | Priority | Status |
|------|----------|--------|
| Complete site commands (create, show, delete) | P0 | Pending |
| Complete zone commands (list, create, show, delete) | P0 | Pending |
| Complete device commands (create, show, update, delete) | P0 | Pending |
| Complete network commands (list, show, create) | P0 | Pending |
| Add repository pattern to db layer | P1 | Pending |
| Add Pydantic models for validation | P1 | Pending |
| Achieve 80% test coverage | P1 | Pending |

### Phase 2: HomeSeer Integration (1-2 weeks)
**Goal**: Sync HomeSeer devices to inventory

| Task | Priority | Status |
|------|----------|--------|
| Create HomeSeer API client | P0 | Pending |
| Implement `inv sync homeseer --full` | P0 | Pending |
| Implement `inv sync homeseer` (incremental) | P0 | Pending |
| Map HomeSeer locations to zones | P1 | Pending |
| Map HomeSeer device types to categories | P1 | Pending |
| Create Windows scheduled task for sync | P2 | Pending |
| Test with real HomeSeer instance | P0 | Pending |

### Phase 3: Network Discovery (1 week)
**Goal**: Discover network devices automatically

| Task | Priority | Status |
|------|----------|--------|
| Create PowerShell scanner script | P0 | Pending |
| Implement `inv network scan` command | P0 | Pending |
| Implement `inv network import` command | P0 | Pending |
| MAC vendor lookup (OUI database) | P1 | Pending |
| Implement `inv network diff` command | P1 | Pending |
| Create Windows scheduled task for scans | P2 | Pending |

### Phase 4: Web Dashboard (2-3 weeks)
**Goal**: Visual interface for inventory management

| Task | Priority | Status |
|------|----------|--------|
| Set up FastAPI app structure | P0 | Pending |
| Create base template with Tailwind | P0 | Pending |
| Implement dashboard page | P0 | Pending |
| Implement device list/detail/form | P0 | Pending |
| Implement site/zone views | P0 | Pending |
| Implement network topology view | P1 | Pending |
| Implement HTMX interactions | P1 | Pending |
| Add site selector/filter | P1 | Pending |
| Implement sync status page | P2 | Pending |
| Implement reports/export | P2 | Pending |

### Phase 5: Polish & Multi-Site (1 week)
**Goal**: Production-ready for multiple sites

| Task | Priority | Status |
|------|----------|--------|
| Add second site configuration | P0 | Pending |
| Test multi-site workflows | P0 | Pending |
| Add audit log viewing | P1 | Pending |
| Performance optimization | P2 | Pending |
| Documentation | P1 | Pending |

---

## 7. File Deliverables

After approval, these documents will be created:

| Document | Location | Purpose |
|----------|----------|---------|
| Architecture Overview | `docs/architecture/OVERVIEW.md` | High-level system design |
| Database Schema | `docs/architecture/DATABASE.md` | Schema documentation |
| Integration Guide | `docs/architecture/INTEGRATIONS.md` | HomeSeer, network discovery |
| Web Dashboard Design | `docs/architecture/WEB-DASHBOARD.md` | UI/UX specifications |
| API Reference | `docs/architecture/CLI-REFERENCE.md` | CLI command documentation |
| Development Guide | `docs/DEVELOPMENT.md` | Setup, testing, contributing |

---

## 8. Open Questions

1. **HomeSeer API Access**: Do you have the HomeSeer JSON API enabled? (Settings → Setup → Web Server → Enable JSON)

2. **Multiple HomeSeer Instances**: Will remote sites have their own HomeSeer, or centrally managed?

3. **Device Naming**: When HomeSeer and network discovery find the same device, which name wins?

4. **Dashboard Auth**: Even on VPN, do you want basic auth for the web dashboard?

---

## Approval

Please review this plan and confirm:
- [ ] Architecture approach is acceptable
- [ ] Phase priorities are correct
- [ ] Technology choices are acceptable
- [ ] Ready to proceed with implementation

