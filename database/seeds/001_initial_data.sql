-- Seed: 001_initial_data
-- Description: Initial organization, site, and sample data
-- Created: 2025-11-25

-- ============================================================================
-- SAMPLE ORGANIZATION
-- ============================================================================
INSERT INTO organizations (id, name, slug, type, description, metadata) VALUES
(
    'a0000000-0000-0000-0000-000000000001',
    'Anand Family',
    'anand-family',
    'home',
    'Primary residential organization',
    '{"owner": "Rohit Anand", "established": "2024"}'
);

-- ============================================================================
-- SAMPLE SITES
-- ============================================================================

-- Primary Residence
INSERT INTO sites (id, organization_id, name, slug, site_type, timezone, is_primary, metadata) VALUES
(
    'b0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    'Primary Residence',
    'primary-residence',
    'residence',
    'America/Los_Angeles',
    TRUE,
    '{"homeseer_url": "http://192.168.68.56", "blueiris_url": "http://192.168.68.56:81"}'
);

-- ============================================================================
-- SAMPLE ZONES (for Primary Residence)
-- ============================================================================

-- Floors
INSERT INTO zones (id, site_id, name, slug, zone_type, floor_number, sort_order) VALUES
('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'First Floor', 'first-floor', 'floor', 1, 10),
('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'Second Floor', 'second-floor', 'floor', 2, 20),
('c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'Basement', 'basement', 'floor', 0, 5),
('c0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 'Garage', 'garage', 'garage', 1, 30),
('c0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000001', 'Outdoor', 'outdoor', 'outdoor', 0, 40);

-- Rooms (First Floor)
INSERT INTO zones (id, site_id, parent_zone_id, name, slug, zone_type, floor_number, sort_order) VALUES
('c0000000-0000-0000-0000-000000000010', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Living Room', 'living-room', 'room', 1, 11),
('c0000000-0000-0000-0000-000000000011', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Kitchen', 'kitchen', 'room', 1, 12),
('c0000000-0000-0000-0000-000000000012', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Dining Room', 'dining-room', 'room', 1, 13),
('c0000000-0000-0000-0000-000000000013', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Office', 'office', 'room', 1, 14);

-- Rooms (Second Floor)
INSERT INTO zones (id, site_id, parent_zone_id, name, slug, zone_type, floor_number, sort_order) VALUES
('c0000000-0000-0000-0000-000000000020', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'Master Bedroom', 'master-bedroom', 'room', 2, 21),
('c0000000-0000-0000-0000-000000000021', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'Bedroom 2', 'bedroom-2', 'room', 2, 22),
('c0000000-0000-0000-0000-000000000022', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'Bedroom 3', 'bedroom-3', 'room', 2, 23);

-- Utility Areas (Basement)
INSERT INTO zones (id, site_id, parent_zone_id, name, slug, zone_type, floor_number, sort_order) VALUES
('c0000000-0000-0000-0000-000000000030', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000003', 'Server Closet', 'server-closet', 'closet', 0, 1),
('c0000000-0000-0000-0000-000000000031', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000003', 'Utility Room', 'utility-room', 'room', 0, 2);

-- ============================================================================
-- SAMPLE NETWORKS
-- ============================================================================

-- Main LAN
INSERT INTO networks (id, site_id, name, slug, network_type, cidr, gateway_ip, vlan_id, is_primary, metadata) VALUES
(
    'd0000000-0000-0000-0000-000000000001',
    'b0000000-0000-0000-0000-000000000001',
    'Main LAN',
    'main-lan',
    'ethernet',
    '192.168.68.0/24',
    '192.168.68.1',
    1,
    TRUE,
    '{"router": "Ubiquiti UDM Pro"}'
);

-- WiFi Networks
INSERT INTO networks (id, site_id, name, slug, network_type, ssid, frequency, security_type, metadata) VALUES
(
    'd0000000-0000-0000-0000-000000000002',
    'b0000000-0000-0000-0000-000000000001',
    'Main WiFi',
    'main-wifi',
    'wifi',
    'HomeNet',
    '5GHz',
    'WPA3',
    '{}'
),
(
    'd0000000-0000-0000-0000-000000000003',
    'b0000000-0000-0000-0000-000000000001',
    'IoT WiFi',
    'iot-wifi',
    'wifi',
    'HomeNet-IoT',
    '2.4GHz',
    'WPA2',
    '{"purpose": "IoT devices"}'
);

-- Z-Wave Network
INSERT INTO networks (id, site_id, name, slug, network_type, channel, metadata) VALUES
(
    'd0000000-0000-0000-0000-000000000004',
    'b0000000-0000-0000-0000-000000000001',
    'Z-Wave Network',
    'zwave',
    'zwave',
    NULL,
    '{"controller": "Nortek HUSBZB-1", "com_port": "COM3"}'
);

-- Zigbee Network
INSERT INTO networks (id, site_id, name, slug, network_type, channel, metadata) VALUES
(
    'd0000000-0000-0000-0000-000000000005',
    'b0000000-0000-0000-0000-000000000001',
    'Zigbee Network',
    'zigbee',
    'zigbee',
    NULL,
    '{"controller": "Nortek HUSBZB-1", "com_port": "COM4"}'
);

-- ============================================================================
-- SAMPLE DEVICES (Infrastructure)
-- ============================================================================

-- HomeSeer Server
INSERT INTO devices (
    id, site_id, zone_id, network_id, name, slug, device_type, category_id,
    manufacturer, model, ip_address, hostname, status, homeseer_ref, is_controller, metadata
) VALUES (
    'e0000000-0000-0000-0000-000000000001',
    'b0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000030',  -- Server Closet
    'd0000000-0000-0000-0000-000000000001',  -- Main LAN
    'HomeSeer Server',
    'homeseer-server',
    'home_automation_hub',
    (SELECT id FROM device_categories WHERE slug = 'automation'),
    'HomeSeer',
    'HS4',
    '192.168.68.56',
    'homeseer',
    'online',
    'HS4-SERVER',
    TRUE,
    '{"version": "4.2.22.4", "os": "Windows 11", "port": 80}'
);

-- Z-Wave Controller (USB Stick)
INSERT INTO devices (
    id, site_id, zone_id, network_id, name, slug, device_type, category_id,
    manufacturer, model, status, is_controller, metadata
) VALUES (
    'e0000000-0000-0000-0000-000000000002',
    'b0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000030',
    'd0000000-0000-0000-0000-000000000004',  -- Z-Wave Network
    'Z-Wave USB Controller',
    'zwave-controller',
    'zwave_controller',
    (SELECT id FROM device_categories WHERE slug = 'automation'),
    'Nortek',
    'HUSBZB-1',
    'online',
    TRUE,
    '{"com_port": "COM3", "type": "Z-Wave"}'
);

-- Zigbee Controller (USB Stick)
INSERT INTO devices (
    id, site_id, zone_id, network_id, name, slug, device_type, category_id,
    manufacturer, model, status, is_controller, metadata
) VALUES (
    'e0000000-0000-0000-0000-000000000003',
    'b0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000030',
    'd0000000-0000-0000-0000-000000000005',  -- Zigbee Network
    'Zigbee USB Controller',
    'zigbee-controller',
    'zigbee_coordinator',
    (SELECT id FROM device_categories WHERE slug = 'automation'),
    'Nortek',
    'HUSBZB-1',
    'online',
    TRUE,
    '{"com_port": "COM4", "type": "Zigbee"}'
);

-- Update network controller references
UPDATE networks SET controller_device_id = 'e0000000-0000-0000-0000-000000000002'
WHERE id = 'd0000000-0000-0000-0000-000000000004';

UPDATE networks SET controller_device_id = 'e0000000-0000-0000-0000-000000000003'
WHERE id = 'd0000000-0000-0000-0000-000000000005';

-- ============================================================================
-- SAMPLE IP ALLOCATIONS
-- ============================================================================
INSERT INTO ip_allocations (network_id, device_id, ip_address, allocation_type, hostname) VALUES
(
    'd0000000-0000-0000-0000-000000000001',
    'e0000000-0000-0000-0000-000000000001',
    '192.168.68.56',
    'static',
    'homeseer'
);

-- ============================================================================
-- AUDIT LOG: Record initial setup
-- ============================================================================
INSERT INTO audit_log (
    organization_id, entity_type, entity_id, entity_name, action,
    actor_type, actor_name, new_values
) VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'organization',
    'a0000000-0000-0000-0000-000000000001',
    'Anand Family',
    'create',
    'system',
    'Database Seed',
    '{"note": "Initial database setup"}'
);
