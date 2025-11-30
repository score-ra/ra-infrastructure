# Inventory Export Manifest

Export Date: 2025-11-30
Source: ra-infrastructure PostgreSQL database

---

## Files Overview

| File | Records | Purpose |
|------|---------|---------|
| devices.csv | 44 | Primary asset inventory |
| zones.csv | 14 | Physical locations within sites |
| device_categories.csv | 8 | Device classification lookup |
| networks.csv | 5 | Network segment definitions |
| sites.csv | 1 | Physical site/building info |
| organizations.csv | 1 | Top-level organization |
| ip_allocations.csv | 1 | IP address assignments |
| network_vlans.csv | 0 | VLAN definitions |
| device_connections.csv | 0 | Device topology/connections |
| device_attributes.csv | 0 | Extended key-value attributes |

---

## devices.csv (Primary Import)

The main asset inventory file. Each row represents a device/asset.

### Identification
| Column | Description |
|--------|-------------|
| id | UUID primary key |
| name | Human-readable device name |
| slug | URL-friendly identifier |
| description | Optional description |

### Classification
| Column | Description |
|--------|-------------|
| device_type | Specific type (router, dimmer_switch, ptz_camera, smart_speaker, etc.) |
| category_id | FK to device_categories |
| category_name | Category name (Automation, Security, Network, Computing, Entertainment, Climate, Appliance, Other) |

### Location
| Column | Description |
|--------|-------------|
| site_id | FK to sites table |
| site_name | Site name (e.g., "31-Newtown") |
| zone_id | FK to zones table |
| zone_name | Zone/room name (e.g., "Server Closet", "Living Room") |
| location_description | Free-text location details |

### Manufacturer Info
| Column | Description |
|--------|-------------|
| manufacturer | Manufacturer name (Google, Apple, Amazon, HP, etc.) |
| model | Model name |
| model_number | Manufacturer model number |
| serial_number | Device serial number |
| firmware_version | Current firmware version |
| hardware_version | Hardware revision |

### Network Info
| Column | Description |
|--------|-------------|
| network_id | FK to networks table |
| network_name | Network name (Main LAN, Z-Wave Network, etc.) |
| mac_address | MAC address (format: aa:bb:cc:dd:ee:ff) |
| ip_address | IPv4 address |
| hostname | DNS hostname |

### Protocol-Specific IDs
| Column | Description |
|--------|-------------|
| zwave_node_id | Z-Wave node ID (integer) |
| zwave_home_id | Z-Wave home/network ID |
| zigbee_ieee_address | Zigbee 64-bit IEEE address |
| zigbee_network_address | Zigbee 16-bit network address |
| bluetooth_address | Bluetooth MAC address |
| thread_eui64 | Thread EUI-64 identifier |

### Status
| Column | Description |
|--------|-------------|
| status | Operational status: online, offline, unknown, maintenance, decommissioned |
| usage_status | Deployment state: active, stored, failed, retired, pending |
| last_seen | Last communication timestamp |
| last_status_change | When status last changed |
| is_active | Boolean - device is active in inventory |

### Purchase/Warranty
| Column | Description |
|--------|-------------|
| purchase_date | Date of purchase |
| purchase_price | Purchase price (decimal) |
| purchase_currency | Currency code (default: USD) |
| purchase_source | Where purchased (Amazon, Best Buy, etc.) |
| receipt_reference | Order/receipt number |
| installation_date | When device was installed |
| warranty_expiry | Warranty end date |

### Failure Tracking
| Column | Description |
|--------|-------------|
| storage_location | Where stored devices are located |
| failure_date | Date device failed |
| failure_reason | Description of failure |
| rma_reference | RMA/warranty claim number |

### Flags
| Column | Description |
|--------|-------------|
| is_controller | Boolean - device is a hub/controller |
| is_battery_powered | Boolean - runs on battery |

### Integration References
| Column | Description |
|--------|-------------|
| homeseer_ref | HomeSeer device reference |
| homeassistant_entity_id | Home Assistant entity ID |
| blueiris_short_name | Blue Iris camera short name |

### Flexible Data (JSON)
| Column | Description |
|--------|-------------|
| capabilities | JSON array of device capabilities |
| configuration | JSON object with device-specific config |
| metadata | JSON object with additional attributes |

### Timestamps
| Column | Description |
|--------|-------------|
| created_at | Record creation timestamp |
| updated_at | Last modification timestamp |

---

## zones.csv

Physical locations within a site (rooms, floors, closets).

| Column | Description |
|--------|-------------|
| id | UUID primary key |
| site_id | FK to sites |
| site_name | Parent site name |
| parent_zone_id | FK to parent zone (for hierarchy) |
| name | Zone name |
| slug | URL-friendly identifier |
| zone_type | Type: building, floor, room, closet, outdoor, garage, other |
| floor_number | Floor number (0=ground, negative=basement) |
| area_sqft | Area in square feet |
| sort_order | Display order |
| icon | Icon identifier |
| color | Hex color for UI |
| is_active | Boolean |
| metadata | JSON additional data |
| created_at | Creation timestamp |
| updated_at | Last modified timestamp |

---

## device_categories.csv

Lookup table for device classification.

| Column | Description |
|--------|-------------|
| id | UUID primary key |
| name | Category name |
| slug | URL-friendly identifier |
| description | Category description |
| icon | Icon identifier |
| sort_order | Display order |
| created_at | Creation timestamp |

**Categories:**
- Automation - Smart home devices (switches, dimmers, sensors)
- Security - Cameras, locks, security sensors
- Network - Routers, switches, access points
- Computing - Computers, servers, NAS
- Entertainment - TVs, speakers, streaming devices
- Climate - HVAC, thermostats, fans
- Appliance - Smart appliances
- Other - Uncategorized

---

## networks.csv

Network segment definitions.

| Column | Description |
|--------|-------------|
| id | UUID primary key |
| site_id | FK to sites |
| site_name | Site name |
| name | Network name |
| slug | URL-friendly identifier |
| network_type | Type: ethernet, wifi, zwave, zigbee, bluetooth, thread, matter, other |
| cidr | IP network in CIDR notation (e.g., 192.168.68.0/24) |
| gateway_ip | Gateway IP address |
| dns_servers | Array of DNS server IPs |
| vlan_id | VLAN ID if applicable |
| ssid | WiFi SSID |
| frequency | WiFi frequency (2.4GHz, 5GHz, 6GHz) |
| security_type | WiFi security (WPA2, WPA3, Open) |
| controller_device_id | FK to controlling device (for mesh networks) |
| pan_id | Personal Area Network ID (Zigbee/Z-Wave) |
| channel | Radio channel |
| home_id | Z-Wave Home ID |
| is_primary | Boolean - primary network |
| is_active | Boolean |
| metadata | JSON additional data |
| created_at | Creation timestamp |
| updated_at | Last modified timestamp |

---

## sites.csv

Physical locations (buildings/addresses).

| Column | Description |
|--------|-------------|
| id | UUID primary key |
| organization_id | FK to organizations |
| org_name | Organization name |
| name | Site name |
| slug | URL-friendly identifier |
| site_type | Type: residence, office, datacenter, warehouse, other |
| address_line1 | Street address |
| address_line2 | Address line 2 |
| city | City |
| state | State/province |
| postal_code | ZIP/postal code |
| country | Country code (default: USA) |
| latitude | GPS latitude |
| longitude | GPS longitude |
| timezone | Timezone (e.g., America/Los_Angeles) |
| is_primary | Boolean - primary site for org |
| is_active | Boolean |
| metadata | JSON additional data |
| created_at | Creation timestamp |
| updated_at | Last modified timestamp |

---

## organizations.csv

Top-level organizational units.

| Column | Description |
|--------|-------------|
| id | UUID primary key |
| name | Organization name |
| slug | URL-friendly identifier |
| type | Type: home, business, lab, other |
| description | Description |
| metadata | JSON additional data |
| is_active | Boolean |
| created_at | Creation timestamp |
| updated_at | Last modified timestamp |

---

## ip_allocations.csv

IP address assignments.

| Column | Description |
|--------|-------------|
| id | UUID primary key |
| network_id | FK to networks |
| network_name | Network name |
| device_id | FK to devices |
| device_name | Device name |
| ip_address | Assigned IP address |
| allocation_type | Type: static, dhcp_reservation, dynamic, reserved |
| hostname | DNS hostname |
| dns_names | Array of DNS aliases |
| mac_address | Associated MAC address |
| lease_start | DHCP lease start |
| lease_end | DHCP lease end |
| is_active | Boolean |
| last_seen | Last seen timestamp |
| notes | Notes |
| metadata | JSON additional data |
| created_at | Creation timestamp |
| updated_at | Last modified timestamp |

---

## Snipe-IT Import Mapping Suggestions

For Snipe-IT asset import, consider these mappings from devices.csv:

| Snipe-IT Field | Source Column |
|----------------|---------------|
| Asset Name | name |
| Asset Tag | slug or id |
| Serial | serial_number |
| Model | model (create models from unique values) |
| Manufacturer | manufacturer |
| Category | category_name |
| Location | zone_name or site_name |
| Purchase Date | purchase_date |
| Purchase Cost | purchase_price |
| Warranty Expiration | warranty_expiry |
| Order Number | receipt_reference |
| Supplier | purchase_source |
| Notes | description |
| Status | Map usage_status: active=Ready to Deploy, stored=Pending, failed=Out for Repair, retired=Archived |
| Custom Fields | mac_address, ip_address, hostname, manufacturer info |
