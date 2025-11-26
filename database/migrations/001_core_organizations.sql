-- Migration: 001_core_organizations
-- Description: Core organization hierarchy (orgs, sites, zones)
-- Created: 2025-11-25

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- ORGANIZATIONS
-- Top-level entity for multi-tenant support (home, business, lab)
-- ============================================================================
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('home', 'business', 'lab', 'other')),
    description TEXT,
    metadata JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_organizations_slug ON organizations(slug);
CREATE INDEX idx_organizations_type ON organizations(type);

COMMENT ON TABLE organizations IS 'Top-level organizational units (families, companies, labs)';
COMMENT ON COLUMN organizations.slug IS 'URL-friendly identifier (e.g., anand-family)';
COMMENT ON COLUMN organizations.type IS 'Organization type: home, business, lab, other';
COMMENT ON COLUMN organizations.metadata IS 'Flexible JSON for additional attributes';

-- ============================================================================
-- SITES
-- Physical locations belonging to an organization
-- ============================================================================
CREATE TABLE sites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    site_type VARCHAR(50) CHECK (site_type IN ('residence', 'office', 'datacenter', 'warehouse', 'other')),

    -- Address
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(50),
    postal_code VARCHAR(20),
    country VARCHAR(3) DEFAULT 'USA',

    -- Geolocation (optional)
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),

    -- Settings
    timezone VARCHAR(50) DEFAULT 'America/Los_Angeles',
    is_primary BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,

    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(organization_id, slug)
);

CREATE INDEX idx_sites_organization ON sites(organization_id);
CREATE INDEX idx_sites_slug ON sites(slug);
CREATE INDEX idx_sites_type ON sites(site_type);

COMMENT ON TABLE sites IS 'Physical locations (homes, offices, datacenters)';
COMMENT ON COLUMN sites.slug IS 'URL-friendly identifier unique within organization';
COMMENT ON COLUMN sites.is_primary IS 'Primary site for the organization';

-- ============================================================================
-- ZONES
-- Logical areas within a site (rooms, floors, closets)
-- Supports hierarchical zones (floor > room > area)
-- ============================================================================
CREATE TABLE zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    parent_zone_id UUID REFERENCES zones(id) ON DELETE SET NULL,

    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    zone_type VARCHAR(50) CHECK (zone_type IN ('building', 'floor', 'room', 'closet', 'outdoor', 'garage', 'other')),

    -- Physical attributes
    floor_number INTEGER,
    area_sqft DECIMAL(10, 2),

    -- Display
    sort_order INTEGER DEFAULT 0,
    icon VARCHAR(50),
    color VARCHAR(7),  -- Hex color for UI

    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(site_id, slug)
);

CREATE INDEX idx_zones_site ON zones(site_id);
CREATE INDEX idx_zones_parent ON zones(parent_zone_id);
CREATE INDEX idx_zones_type ON zones(zone_type);

COMMENT ON TABLE zones IS 'Logical areas within sites (rooms, floors, closets)';
COMMENT ON COLUMN zones.parent_zone_id IS 'Hierarchical parent (e.g., floor contains rooms)';
COMMENT ON COLUMN zones.floor_number IS 'Floor number (0=ground, negative=basement)';

-- ============================================================================
-- HELPER FUNCTION: Update timestamp trigger
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers
CREATE TRIGGER trg_organizations_updated
    BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_sites_updated
    BEFORE UPDATE ON sites
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_zones_updated
    BEFORE UPDATE ON zones
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
