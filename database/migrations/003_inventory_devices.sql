-- Migration: 003_inventory_devices
-- Description: Device inventory and topology
-- Created: 2025-11-25

-- ============================================================================
-- DEVICE_CATEGORIES
-- Lookup table for device categorization
-- ============================================================================
CREATE TABLE device_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    icon VARCHAR(50),
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO device_categories (name, slug, description, icon, sort_order) VALUES
    ('Automation', 'automation', 'Smart home automation devices (switches, dimmers, sensors)', 'lightbulb', 10),
    ('Security', 'security', 'Security devices (cameras, locks, sensors)', 'shield', 20),
    ('Network', 'network', 'Network infrastructure (routers, switches, APs)', 'wifi', 30),
    ('Computing', 'computing', 'Computers, servers, NAS devices', 'server', 40),
    ('Entertainment', 'entertainment', 'TVs, speakers, streaming devices', 'tv', 50),
    ('Climate', 'climate', 'HVAC, thermostats, fans', 'thermometer', 60),
    ('Appliance', 'appliance', 'Smart appliances (washer, fridge, etc)', 'home', 70),
    ('Other', 'other', 'Uncategorized devices', 'box', 100);

COMMENT ON TABLE device_categories IS 'Device category lookup for organization';

-- ============================================================================
-- DEVICES
-- Core device inventory table
-- ============================================================================
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Location
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    zone_id UUID REFERENCES zones(id) ON DELETE SET NULL,
    network_id UUID REFERENCES networks(id) ON DELETE SET NULL,

    -- Identification
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    description TEXT,

    -- Classification
    device_type VARCHAR(100) NOT NULL,   -- Specific type: 'dimmer_switch', 'ptz_camera', 'access_point'
    category_id UUID REFERENCES device_categories(id),

    -- Manufacturer
    manufacturer VARCHAR(255),
    model VARCHAR(255),
    model_number VARCHAR(100),
    serial_number VARCHAR(255),
    firmware_version VARCHAR(100),
    hardware_version VARCHAR(100),

    -- Network Addressing
    mac_address MACADDR,
    ip_address INET,
    hostname VARCHAR(255),

    -- Protocol-specific IDs
    zwave_node_id INTEGER,
    zwave_home_id VARCHAR(20),
    zigbee_ieee_address VARCHAR(24),      -- 64-bit IEEE address
    zigbee_network_address VARCHAR(10),   -- 16-bit network address
    bluetooth_address VARCHAR(17),
    thread_eui64 VARCHAR(24),

    -- Status
    status VARCHAR(50) DEFAULT 'unknown' CHECK (status IN (
        'online', 'offline', 'unknown', 'maintenance', 'decommissioned'
    )),
    last_seen TIMESTAMPTZ,
    last_status_change TIMESTAMPTZ,

    -- Physical Location
    location_description TEXT,           -- Human-readable location
    installation_date DATE,
    warranty_expiry DATE,

    -- Purchase Info
    purchase_date DATE,
    purchase_price DECIMAL(10, 2),
    purchase_currency VARCHAR(3) DEFAULT 'USD',
    purchase_source VARCHAR(255),        -- Where purchased
    receipt_reference VARCHAR(255),      -- Receipt/order number

    -- Integration References (external system IDs)
    homeseer_ref VARCHAR(100),           -- HomeSeer device reference
    homeassistant_entity_id VARCHAR(255),-- Home Assistant entity ID
    blueiris_short_name VARCHAR(50),     -- BlueIris camera short name

    -- Flags
    is_controller BOOLEAN DEFAULT FALSE, -- Is this a hub/controller?
    is_battery_powered BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,

    -- Flexible data
    capabilities JSONB DEFAULT '[]',     -- Array of capabilities
    configuration JSONB DEFAULT '{}',    -- Device-specific config
    metadata JSONB DEFAULT '{}',         -- Additional attributes

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(site_id, slug)
);

-- Indexes for common queries
CREATE INDEX idx_devices_site ON devices(site_id);
CREATE INDEX idx_devices_zone ON devices(zone_id);
CREATE INDEX idx_devices_network ON devices(network_id);
CREATE INDEX idx_devices_category ON devices(category_id);
CREATE INDEX idx_devices_type ON devices(device_type);
CREATE INDEX idx_devices_status ON devices(status);
CREATE INDEX idx_devices_mac ON devices(mac_address);
CREATE INDEX idx_devices_ip ON devices(ip_address);
CREATE INDEX idx_devices_manufacturer ON devices(manufacturer);
CREATE INDEX idx_devices_zwave ON devices(zwave_node_id) WHERE zwave_node_id IS NOT NULL;
CREATE INDEX idx_devices_zigbee ON devices(zigbee_ieee_address) WHERE zigbee_ieee_address IS NOT NULL;
CREATE INDEX idx_devices_homeseer ON devices(homeseer_ref) WHERE homeseer_ref IS NOT NULL;

COMMENT ON TABLE devices IS 'Central device inventory across all sites';
COMMENT ON COLUMN devices.device_type IS 'Specific device type (dimmer_switch, ptz_camera, etc)';
COMMENT ON COLUMN devices.is_controller IS 'True if device is a hub/controller (Z-Wave stick, Zigbee coordinator)';
COMMENT ON COLUMN devices.capabilities IS 'JSON array of device capabilities';

-- ============================================================================
-- DEVICE_CONNECTIONS
-- Physical and logical connections between devices (topology)
-- ============================================================================
CREATE TABLE device_connections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    source_device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    target_device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,

    connection_type VARCHAR(50) NOT NULL CHECK (connection_type IN (
        'ethernet', 'wifi', 'usb', 'hdmi', 'zwave_route', 'zigbee_route',
        'bluetooth', 'serial', 'power', 'other'
    )),

    -- Port information
    source_port VARCHAR(50),             -- e.g., 'LAN1', 'USB3', 'Port 24'
    target_port VARCHAR(50),

    -- Connection details
    speed VARCHAR(50),                   -- e.g., '1Gbps', 'USB 3.0'
    is_wireless BOOLEAN DEFAULT FALSE,
    signal_strength INTEGER,             -- dBm for wireless

    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    established_at TIMESTAMPTZ,

    notes TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Prevent duplicate connections
    UNIQUE(source_device_id, target_device_id, connection_type, source_port, target_port)
);

CREATE INDEX idx_device_connections_source ON device_connections(source_device_id);
CREATE INDEX idx_device_connections_target ON device_connections(target_device_id);
CREATE INDEX idx_device_connections_type ON device_connections(connection_type);

COMMENT ON TABLE device_connections IS 'Physical and logical connections between devices';
COMMENT ON COLUMN device_connections.connection_type IS 'Type of connection (ethernet, wifi, usb, mesh routes)';

-- ============================================================================
-- DEVICE_ATTRIBUTES
-- Flexible key-value attributes for devices
-- ============================================================================
CREATE TABLE device_attributes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,

    attribute_key VARCHAR(100) NOT NULL,
    attribute_value TEXT,
    value_type VARCHAR(20) DEFAULT 'string' CHECK (value_type IN (
        'string', 'number', 'boolean', 'json', 'date'
    )),

    -- Grouping
    attribute_group VARCHAR(100),        -- e.g., 'specs', 'settings', 'metrics'

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(device_id, attribute_key)
);

CREATE INDEX idx_device_attributes_device ON device_attributes(device_id);
CREATE INDEX idx_device_attributes_key ON device_attributes(attribute_key);
CREATE INDEX idx_device_attributes_group ON device_attributes(attribute_group);

COMMENT ON TABLE device_attributes IS 'Flexible key-value storage for device attributes';

-- ============================================================================
-- ADD FOREIGN KEY: networks.controller_device_id -> devices.id
-- ============================================================================
ALTER TABLE networks
    ADD CONSTRAINT fk_networks_controller
    FOREIGN KEY (controller_device_id) REFERENCES devices(id) ON DELETE SET NULL;

-- ============================================================================
-- ADD FOREIGN KEY: ip_allocations.device_id -> devices.id
-- ============================================================================
ALTER TABLE ip_allocations
    ADD CONSTRAINT fk_ip_allocations_device
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL;

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER trg_devices_updated
    BEFORE UPDATE ON devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_device_connections_updated
    BEFORE UPDATE ON device_connections
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_device_attributes_updated
    BEFORE UPDATE ON device_attributes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
