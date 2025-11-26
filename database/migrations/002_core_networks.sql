-- Migration: 002_core_networks
-- Description: Network infrastructure (WiFi, Ethernet, Z-Wave, Zigbee, Bluetooth)
-- Created: 2025-11-25

-- ============================================================================
-- NETWORKS
-- Network segments at a site (IP networks, mesh networks, wireless)
-- ============================================================================
CREATE TABLE networks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,

    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    network_type VARCHAR(50) NOT NULL CHECK (network_type IN (
        'ethernet', 'wifi', 'zwave', 'zigbee', 'bluetooth', 'thread', 'matter', 'other'
    )),

    -- IP Networks (Ethernet, WiFi)
    cidr VARCHAR(18),                -- e.g., '192.168.68.0/24'
    gateway_ip INET,
    dns_servers INET[],
    vlan_id INTEGER,

    -- Wireless Networks (WiFi)
    ssid VARCHAR(100),
    frequency VARCHAR(20),           -- '2.4GHz', '5GHz', '6GHz'
    security_type VARCHAR(50),       -- 'WPA2', 'WPA3', 'Open'

    -- Mesh Networks (Z-Wave, Zigbee)
    controller_device_id UUID,       -- References devices table (added later)
    pan_id VARCHAR(20),              -- Personal Area Network ID
    channel INTEGER,
    home_id VARCHAR(20),             -- Z-Wave Home ID

    -- Status
    is_primary BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,

    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(site_id, slug)
);

CREATE INDEX idx_networks_site ON networks(site_id);
CREATE INDEX idx_networks_type ON networks(network_type);
CREATE INDEX idx_networks_cidr ON networks(cidr);

COMMENT ON TABLE networks IS 'Network segments (IP subnets, mesh networks, WiFi)';
COMMENT ON COLUMN networks.network_type IS 'Protocol type: ethernet, wifi, zwave, zigbee, bluetooth, thread, matter';
COMMENT ON COLUMN networks.controller_device_id IS 'Device acting as mesh controller (Z-Wave/Zigbee stick)';

-- ============================================================================
-- IP_ALLOCATIONS
-- IP address assignments within a network
-- ============================================================================
CREATE TABLE ip_allocations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    network_id UUID NOT NULL REFERENCES networks(id) ON DELETE CASCADE,
    device_id UUID,                  -- References devices table (added later via FK)

    ip_address INET NOT NULL,
    allocation_type VARCHAR(20) NOT NULL CHECK (allocation_type IN (
        'static', 'dhcp_reservation', 'dynamic', 'reserved'
    )),

    -- DNS
    hostname VARCHAR(255),
    dns_names TEXT[],                -- Array of DNS aliases

    -- DHCP
    mac_address MACADDR,
    lease_start TIMESTAMPTZ,
    lease_end TIMESTAMPTZ,

    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    last_seen TIMESTAMPTZ,

    notes TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(network_id, ip_address)
);

CREATE INDEX idx_ip_allocations_network ON ip_allocations(network_id);
CREATE INDEX idx_ip_allocations_device ON ip_allocations(device_id);
CREATE INDEX idx_ip_allocations_ip ON ip_allocations(ip_address);
CREATE INDEX idx_ip_allocations_mac ON ip_allocations(mac_address);

COMMENT ON TABLE ip_allocations IS 'IP address assignments and DHCP reservations';
COMMENT ON COLUMN ip_allocations.allocation_type IS 'How IP was assigned: static, dhcp_reservation, dynamic, reserved';
COMMENT ON COLUMN ip_allocations.dns_names IS 'Array of DNS names pointing to this IP';

-- ============================================================================
-- NETWORK_VLANS
-- VLAN definitions for segmentation
-- ============================================================================
CREATE TABLE network_vlans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,

    vlan_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,

    -- Associated network
    network_id UUID REFERENCES networks(id) ON DELETE SET NULL,

    -- Purpose
    vlan_type VARCHAR(50) CHECK (vlan_type IN (
        'management', 'iot', 'guest', 'security', 'servers', 'workstations', 'other'
    )),

    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(site_id, vlan_id)
);

CREATE INDEX idx_network_vlans_site ON network_vlans(site_id);

COMMENT ON TABLE network_vlans IS 'VLAN definitions for network segmentation';

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER trg_networks_updated
    BEFORE UPDATE ON networks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_ip_allocations_updated
    BEFORE UPDATE ON ip_allocations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_network_vlans_updated
    BEFORE UPDATE ON network_vlans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
