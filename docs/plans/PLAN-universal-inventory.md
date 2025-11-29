# Plan: Universal Inventory System

## Overview

Extend the ra-infrastructure database to support:
1. **Properties** - physical structures (houses, offices) with ownership/lease details
2. **Networks as first-class entities** - devices can move between networks
3. **General devices** - laptops, PCs, phones beyond home automation
4. **Physical inventory** - desks, chairs, furniture, equipment

## Current State Analysis

### Current Schema Structure
```
organizations
├── sites
│   ├── zones (hierarchical rooms/floors)
│   ├── networks (tied to site)
│   └── devices (tied to site + optional zone/network)
```

### Current Limitations

1. **Devices tightly coupled to networks**: `devices.network_id` is a single FK - device can only be on one network at a time, but changing networks requires update (no history)

2. **Device model is smart-home focused**: Contains `zwave_node_id`, `zigbee_ieee_address`, `homeseer_ref` columns - appropriate for IoT but clutters general device use

3. **No concept of portable devices**: A laptop that moves between home office and work office has no way to track network transitions

4. **No physical inventory support**: Furniture, equipment, non-electronic items cannot be tracked

---

## Proposed Architecture

### Option A: Extend Devices Table (Minimal Change)

Add columns and make network relationship more flexible:
- Add `device_network_assignments` table for many-to-many with timestamps
- Add more `device_type` values for computers, phones
- Use `metadata` JSONB for type-specific attributes

**Pros**: Minimal schema changes, single "device" concept
**Cons**: `devices` table becomes bloated, physical items don't fit well

### Option B: Separate Items Table + Properties (Recommended)

Create a clear separation between **properties**, electronic **devices**, and physical **items**:

```
organizations
├── properties (physical structures - houses, offices, with ownership details)
│   └── sites (operational locations within properties)
│       ├── zones
│       ├── networks (site-scoped) ──────────────┐
│       ├── devices (electronic/connected)       │
│       │   ├── device_network_assignments ──────┘
│       │   └── device_site_history
│       └── items (physical inventory - furniture, equipment)
│           └── item_location_history
└── networks (org-scoped, e.g., VPNs)
```

**Pros**: Clean separation, appropriate columns per type, extensible, property tracking
**Cons**: More tables, some overlap in tracking

### Option C: Unified Assets Table

Replace `devices` with a generic `assets` table that handles everything:

```
assets (type: 'device' | 'item' | 'furniture' | 'equipment')
├── asset_attributes (key-value for type-specific data)
└── asset_network_assignments (for network-capable assets)
```

**Pros**: Single table for all inventory, maximum flexibility
**Cons**: Loses type safety, complex queries, harder to validate

---

## Recommended Approach: Option B (Enhanced)

### New Schema Design

#### 0. Properties Table (Physical Structures)

```sql
CREATE TABLE properties (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Identification
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    description TEXT,
    property_type VARCHAR(50) NOT NULL CHECK (property_type IN (
        'house', 'apartment', 'condo', 'townhouse', 'office',
        'building', 'warehouse', 'land', 'other'
    )),

    -- Address (canonical address for the property)
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(50),
    postal_code VARCHAR(20),
    country VARCHAR(3) DEFAULT 'USA',
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),

    -- Physical specs
    year_built INTEGER,
    total_area_sqft DECIMAL(10, 2),
    lot_size_sqft DECIMAL(10, 2),
    floors INTEGER,
    bedrooms INTEGER,
    bathrooms DECIMAL(3, 1),  -- 2.5 bathrooms
    parking_spaces INTEGER,

    -- Ownership
    ownership_type VARCHAR(50) CHECK (ownership_type IN (
        'owned', 'rented', 'leased', 'managed', 'other'
    )),
    owner_name VARCHAR(255),
    landlord_name VARCHAR(255),

    -- Financial
    purchase_date DATE,
    purchase_price DECIMAL(12, 2),
    current_value DECIMAL(12, 2),
    monthly_rent DECIMAL(10, 2),
    monthly_hoa DECIMAL(10, 2),
    property_tax_annual DECIMAL(10, 2),

    -- Lease details (for rented properties)
    lease_start DATE,
    lease_end DATE,

    -- Legal/Records
    parcel_number VARCHAR(100),      -- Tax parcel/APN
    legal_description TEXT,

    -- Extensible fields for unknown future needs
    details JSONB DEFAULT '{}',      -- heating, cooling, roof, foundation, utilities, etc.

    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(organization_id, slug)
);

-- Link sites to properties (optional - a site can exist without property details)
ALTER TABLE sites ADD COLUMN property_id UUID REFERENCES properties(id) ON DELETE SET NULL;

CREATE INDEX idx_properties_organization ON properties(organization_id);
CREATE INDEX idx_properties_type ON properties(property_type);
CREATE INDEX idx_sites_property ON sites(property_id);

COMMENT ON TABLE properties IS 'Physical structures with ownership and property details';
COMMENT ON COLUMN properties.details IS 'Extensible JSON: heating, cooling, roof_type, foundation, utilities, appliances, hoa_name, school_district, etc.';
```

Example `details` JSONB usage:
```json
{
  "heating": "forced air gas",
  "cooling": "central AC",
  "roof_type": "composition shingle",
  "roof_year": 2018,
  "foundation": "concrete slab",
  "utilities": ["electricity", "gas", "water", "sewer"],
  "appliances_included": ["refrigerator", "dishwasher", "microwave"],
  "hoa_name": "Sunset Hills HOA",
  "school_district": "XYZ Unified",
  "zoning": "R-1 Residential"
}
```

#### 1. Network Scope Enhancement (Organization-level networks)

```sql
-- Add organization_id to networks for VPNs/overlay networks
ALTER TABLE networks
ADD COLUMN organization_id UUID REFERENCES organizations(id);

-- Constraint: must have either site_id OR organization_id (not both, not neither)
-- Note: site_id already exists, make it nullable for org-level networks
ALTER TABLE networks
ALTER COLUMN site_id DROP NOT NULL;

ALTER TABLE networks
ADD CONSTRAINT networks_scope_check
CHECK (
    (site_id IS NOT NULL AND organization_id IS NULL) OR
    (site_id IS NULL AND organization_id IS NOT NULL)
);
```

#### 2. Device Network History (Track device mobility)

```sql
CREATE TABLE device_network_assignments (
    id UUID PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES devices(id),
    network_id UUID NOT NULL REFERENCES networks(id),

    -- Assignment details
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    unassigned_at TIMESTAMPTZ,  -- NULL = currently assigned
    is_current BOOLEAN DEFAULT TRUE,

    -- Connection info at this network
    ip_address INET,
    mac_address MACADDR,
    hostname VARCHAR(255),

    -- Context
    assignment_reason VARCHAR(255),  -- 'permanent', 'temporary', 'guest'

    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

This allows tracking when a laptop moves from "Home Office Network" to "Work Office Network".

#### 3. Enhanced Device Categories

Update `device_categories` with new categories:

```sql
INSERT INTO device_categories (name, slug, description, icon, sort_order) VALUES
    ('Computer', 'computer', 'Laptops, desktops, workstations', 'laptop', 35),
    ('Mobile', 'mobile', 'Phones, tablets', 'phone', 36),
    ('Peripheral', 'peripheral', 'Keyboards, mice, monitors, printers', 'monitor', 37),
    ('Storage', 'storage', 'NAS, external drives, USB drives', 'harddrive', 38);
```

#### 4. Device Portability and Site Mobility

```sql
-- Add portable flag for devices that move between networks/sites
ALTER TABLE devices ADD COLUMN is_portable BOOLEAN DEFAULT FALSE;

-- Track device site changes (for cross-site mobility)
CREATE TABLE device_site_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,

    -- Site at this time
    site_id UUID NOT NULL REFERENCES sites(id),
    zone_id UUID REFERENCES zones(id),

    -- Timing
    moved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    moved_from_site_id UUID REFERENCES sites(id),
    moved_by VARCHAR(255),
    reason VARCHAR(255),

    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### 5. Physical Items Table (New)

```sql
CREATE TABLE items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Location
    site_id UUID NOT NULL REFERENCES sites(id),
    zone_id UUID REFERENCES zones(id),

    -- Identification
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    description TEXT,

    -- Classification
    item_type VARCHAR(100) NOT NULL,  -- 'desk', 'chair', 'shelf', 'tool'
    category_id UUID REFERENCES item_categories(id),

    -- Quantity (allows "6 office chairs" as single record)
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),

    -- Physical attributes
    manufacturer VARCHAR(255),
    model VARCHAR(255),
    serial_number VARCHAR(255),  -- For individual items (quantity=1)
    color VARCHAR(50),
    material VARCHAR(100),
    dimensions JSONB,  -- {"width": 60, "height": 30, "depth": 24, "unit": "inches"}
    weight_kg DECIMAL(10, 2),

    -- Status
    condition VARCHAR(50) DEFAULT 'good',  -- 'new', 'good', 'fair', 'poor', 'broken'
    status VARCHAR(50) DEFAULT 'active',   -- 'active', 'stored', 'disposed', 'sold'
    storage_location VARCHAR(255),

    -- Purchase/Ownership
    purchase_date DATE,
    purchase_price DECIMAL(10, 2),  -- Total price for all quantity
    unit_price DECIMAL(10, 2),      -- Price per item (calculated or explicit)
    purchase_currency VARCHAR(3) DEFAULT 'USD',
    purchase_source VARCHAR(255),
    receipt_reference VARCHAR(255),
    warranty_expiry DATE,

    -- Disposal
    disposed_date DATE,
    disposal_method VARCHAR(50),  -- 'sold', 'donated', 'recycled', 'trashed'
    disposal_value DECIMAL(10, 2),

    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(site_id, slug)
);

CREATE TABLE item_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    slug VARCHAR(100) NOT NULL UNIQUE,
    parent_category_id UUID REFERENCES item_categories(id),
    description TEXT,
    icon VARCHAR(50),
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed categories
INSERT INTO item_categories (name, slug, description, icon, sort_order) VALUES
    ('Furniture', 'furniture', 'Desks, chairs, tables, shelves', 'chair', 10),
    ('Office Equipment', 'office-equipment', 'Whiteboards, projectors, supplies', 'briefcase', 20),
    ('Tools', 'tools', 'Hand tools, power tools, equipment', 'wrench', 30),
    ('Appliances', 'appliances', 'Non-smart appliances, fans, heaters', 'plug', 40),
    ('Decor', 'decor', 'Art, plants, decorations', 'image', 50),
    ('Storage', 'storage', 'Bins, boxes, containers', 'box', 60);
```

#### 5. Item Movement History

```sql
CREATE TABLE item_location_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID NOT NULL REFERENCES items(id),

    -- Location at this time
    site_id UUID NOT NULL REFERENCES sites(id),
    zone_id UUID REFERENCES zones(id),
    location_description TEXT,

    -- Timing
    moved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    moved_by VARCHAR(255),
    reason VARCHAR(255),

    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Migration Strategy

### Phase 0: Properties (Migration 006)
1. Create `properties` table for physical structures
2. Add `property_id` FK to `sites` table
3. Link existing site to a new property record (optional migration)
4. Add CLI commands for property management

### Phase 1: Network Scope Enhancement (Migration 007)
1. Add `organization_id` to networks table
2. Make `site_id` nullable with check constraint
3. Add index on `organization_id`
4. Existing networks remain site-scoped (no data migration needed)

### Phase 2: Device Network Assignments (Migration 008)
1. Create `device_network_assignments` table
2. Migrate existing `devices.network_id` data to assignments
3. Keep `devices.network_id` as convenience column (current network)
4. Add trigger to update `network_id` when assignment changes

### Phase 3: Device Mobility (Migration 009)
1. Add new device categories (Computer, Mobile, Peripheral, Storage)
2. Add `is_portable` column to devices
3. Create `device_site_history` table for cross-site tracking
4. No breaking changes to existing devices

### Phase 4: Physical Items (Migration 010)
1. Create `item_categories` table with seed data
2. Create `items` table with quantity support
3. Create `item_location_history` table
4. Add CLI commands for item management

### Phase 5: Protocol Cleanup (Optional - Migration 011)
1. Move protocol-specific columns to `device_attributes`
2. Keep backward compatibility via views
3. Cleaner device table for general use

---

## Example Use Cases

### Use Case 0: Managing Properties

```sql
-- Register a house property
INSERT INTO properties (
    organization_id, name, slug, property_type,
    address_line1, city, state, postal_code,
    year_built, total_area_sqft, bedrooms, bathrooms,
    ownership_type, purchase_date, purchase_price, current_value,
    details
) VALUES (
    'org-uuid', 'Main Residence', 'main-residence', 'house',
    '123 Oak Street', 'San Jose', 'CA', '95123',
    2005, 2400, 4, 2.5,
    'owned', '2020-06-15', 850000, 1100000,
    '{"heating": "forced air gas", "cooling": "central AC", "roof_year": 2018}'
);

-- Link existing site to property
UPDATE sites SET property_id = 'property-uuid' WHERE slug = 'primary-residence';

-- Query: Get all properties with their sites
SELECT p.name, p.property_type, p.ownership_type,
       p.total_area_sqft, p.current_value,
       s.name as site_name
FROM properties p
LEFT JOIN sites s ON s.property_id = p.id
WHERE p.organization_id = 'org-uuid';

-- Register a rented office
INSERT INTO properties (
    organization_id, name, slug, property_type,
    address_line1, city, state, postal_code,
    ownership_type, landlord_name, monthly_rent,
    lease_start, lease_end, details
) VALUES (
    'org-uuid', 'Downtown Office', 'downtown-office', 'office',
    '500 Tech Blvd, Suite 200', 'San Francisco', 'CA', '94105',
    'leased', 'Tech Tower LLC', 3500,
    '2024-01-01', '2026-12-31',
    '{"floor": 2, "parking_included": true, "amenities": ["gym", "conference rooms"]}'
);
```

### Use Case 1: Laptop Moving Between Networks

```sql
-- Register laptop
INSERT INTO devices (site_id, name, device_type, category_id, is_portable)
VALUES (site_id, 'MacBook Pro 16"', 'laptop', (SELECT id FROM device_categories WHERE slug = 'computer'), TRUE);

-- Assign to home network
INSERT INTO device_network_assignments (device_id, network_id, ip_address, assignment_reason)
VALUES (device_id, home_network_id, '192.168.68.100', 'permanent');

-- Later: moves to office (closes home, opens office)
UPDATE device_network_assignments
SET unassigned_at = NOW(), is_current = FALSE
WHERE device_id = device_id AND is_current = TRUE;

INSERT INTO device_network_assignments (device_id, network_id, ip_address, assignment_reason)
VALUES (device_id, office_network_id, '10.0.1.50', 'temporary');
```

### Use Case 2: Tracking Office Furniture

```sql
-- Register standing desk
INSERT INTO items (site_id, zone_id, name, item_type, category_id, manufacturer, model, purchase_date, purchase_price)
VALUES (
    site_id,
    office_zone_id,
    'Standing Desk',
    'standing_desk',
    (SELECT id FROM item_categories WHERE slug = 'furniture'),
    'Uplift',
    'V2 Commercial',
    '2024-03-15',
    899.00
);

-- Move to different room
INSERT INTO item_location_history (item_id, site_id, zone_id, reason, moved_by)
VALUES (item_id, site_id, new_zone_id, 'Office reorganization', 'Rohit');

UPDATE items SET zone_id = new_zone_id WHERE id = item_id;
```

### Use Case 3: Query All Inventory at a Site

```sql
-- Combined view of all assets
SELECT 'device' as asset_type, name, device_type as type, zone_id, created_at
FROM devices WHERE site_id = :site_id AND is_active = TRUE
UNION ALL
SELECT 'item' as asset_type, name, item_type as type, zone_id, created_at
FROM items WHERE site_id = :site_id AND is_active = TRUE
ORDER BY name;
```

---

## CLI Commands (New)

```bash
# Property management
inv property list [--org <org>] [--type <type>]
inv property add <name> --org <org> --type <type> [--address <address>]
inv property show <slug>
inv property update <slug> [--value <value>] [--details <json>]
inv property delete <slug>
inv property link-site <property-slug> --site <site-slug>

# Device network management
inv device assign-network <device-slug> --network <network-slug>
inv device unassign-network <device-slug>
inv device network-history <device-slug>
inv device move-site <device-slug> --site <new-site-slug> [--reason <reason>]

# Item management
inv item list [--site <site>] [--zone <zone>] [--category <category>]
inv item add <name> --type <type> --site <site> [--zone <zone>] [--quantity <n>]
inv item show <slug>
inv item move <slug> --zone <new-zone>
inv item update <slug> [--condition <condition>] [--status <status>] [--quantity <n>]
inv item delete <slug>

# Reports
inv inventory report --site <site>  # Combined devices + items
inv inventory value --site <site>   # Total purchase value
inv property value --org <org>      # Total property values
```

---

## Files to Create/Modify

### New Migration Files
- `database/migrations/006_properties.sql`
- `database/migrations/007_network_scope.sql`
- `database/migrations/008_device_network_assignments.sql`
- `database/migrations/009_device_mobility.sql`
- `database/migrations/010_physical_items.sql`

### New Python Files
- `cli/src/inventory/models/property.py`
- `cli/src/inventory/db/repositories/property.py`
- `cli/src/inventory/commands/property.py`
- `cli/src/inventory/models/item.py`
- `cli/src/inventory/db/repositories/item.py`
- `cli/src/inventory/commands/item.py`
- `cli/tests/test_commands/test_property.py`
- `cli/tests/test_commands/test_item.py`
- `cli/tests/test_models/test_property.py`
- `cli/tests/test_models/test_item.py`

### Modified Files
- `cli/src/inventory/models/device.py` - Add `is_portable`
- `cli/src/inventory/models/network.py` - Add `organization_id`
- `cli/src/inventory/models/site.py` - Add `property_id`
- `cli/src/inventory/commands/device.py` - Add network assignment commands
- `cli/src/inventory/commands/network.py` - Support org-level networks
- `cli/src/inventory/commands/site.py` - Link to properties
- `cli/src/inventory/db/repositories/network.py` - Handle org scope
- `database/seeds/001_initial_data.sql` - Add sample properties and items
- `docs/DATABASE.md` - Document new tables

---

## Design Decisions (Answered)

1. **Network scope**: Hybrid approach - networks can be either site-scoped OR organization-scoped
   - Physical networks (WiFi, Ethernet, Z-Wave) remain site-bound
   - VPNs and overlay networks can be organization-level (span multiple sites)
   - Implementation: Add optional `organization_id` to networks with constraint

2. **Cross-site mobility**: Yes - devices and items can move between sites
   - Track site changes in history tables
   - Update `site_id` on device/item when moved

3. **Item granularity**: Support quantities
   - Add `quantity` column to items table (default 1)
   - Allows "6 office chairs" as single record or individual tracking

4. **Integration priority**:
   - Primary: ra-home-automation
   - Secondary: network-tools

---

## Estimated Effort

| Phase | Description | Complexity |
|-------|-------------|------------|
| Phase 1 | Device network assignments | Medium |
| Phase 2 | Extended device categories | Low |
| Phase 3 | Physical items | Medium |
| Phase 4 | Protocol cleanup | Low |

---

## Summary

This plan transforms ra-infrastructure from a smart-home-focused database into a **universal inventory system** that can track:

- **Smart devices** (current functionality preserved)
- **General electronics** (laptops, phones, monitors)
- **Physical items** (furniture, equipment, tools)
- **Network mobility** (devices moving between locations/networks)

The approach maintains backward compatibility while adding new capabilities.
