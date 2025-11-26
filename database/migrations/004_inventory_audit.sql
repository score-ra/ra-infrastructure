-- Migration: 004_inventory_audit
-- Description: Audit logging and change tracking
-- Created: 2025-11-25

-- ============================================================================
-- AUDIT_LOG
-- Track all changes to important entities
-- ============================================================================
CREATE TABLE audit_log (
    id BIGSERIAL PRIMARY KEY,

    -- Context
    organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
    site_id UUID REFERENCES sites(id) ON DELETE SET NULL,

    -- What changed
    entity_type VARCHAR(100) NOT NULL,   -- 'device', 'network', 'zone', etc.
    entity_id UUID NOT NULL,
    entity_name VARCHAR(255),            -- Snapshot of name at time of change

    -- Change details
    action VARCHAR(50) NOT NULL CHECK (action IN (
        'create', 'update', 'delete', 'status_change',
        'import', 'export', 'sync', 'bulk_update'
    )),

    -- Who/what made the change
    actor_type VARCHAR(50) DEFAULT 'user' CHECK (actor_type IN (
        'user', 'system', 'api', 'sync', 'import'
    )),
    actor_id VARCHAR(255),               -- User ID, API key, etc.
    actor_name VARCHAR(255),             -- Human-readable actor name
    actor_ip INET,                       -- IP address if applicable

    -- Change data
    old_values JSONB,                    -- Previous state
    new_values JSONB,                    -- New state
    changed_fields TEXT[],               -- List of changed field names

    -- Metadata
    notes TEXT,
    request_id VARCHAR(100),             -- Correlation ID for tracing
    user_agent TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX idx_audit_log_org ON audit_log(organization_id);
CREATE INDEX idx_audit_log_site ON audit_log(site_id);
CREATE INDEX idx_audit_log_entity ON audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_log_action ON audit_log(action);
CREATE INDEX idx_audit_log_actor ON audit_log(actor_type, actor_id);
CREATE INDEX idx_audit_log_created ON audit_log(created_at DESC);

-- Partition by month for performance (optional, enable if needed)
-- CREATE INDEX idx_audit_log_created_month ON audit_log(date_trunc('month', created_at));

COMMENT ON TABLE audit_log IS 'Audit trail for all entity changes';
COMMENT ON COLUMN audit_log.entity_type IS 'Type of entity (device, network, zone, etc)';
COMMENT ON COLUMN audit_log.changed_fields IS 'Array of field names that changed';

-- ============================================================================
-- SYNC_HISTORY
-- Track synchronization with external systems
-- ============================================================================
CREATE TABLE sync_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- What was synced
    sync_source VARCHAR(100) NOT NULL,   -- 'homeseer', 'homeassistant', 'network_scan'
    site_id UUID REFERENCES sites(id) ON DELETE CASCADE,

    -- Sync details
    sync_type VARCHAR(50) NOT NULL CHECK (sync_type IN (
        'full', 'incremental', 'manual', 'scheduled'
    )),
    direction VARCHAR(20) CHECK (direction IN ('import', 'export', 'bidirectional')),

    -- Results
    status VARCHAR(50) NOT NULL CHECK (status IN (
        'pending', 'running', 'completed', 'failed', 'partial'
    )),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    duration_ms INTEGER,

    -- Counts
    items_total INTEGER DEFAULT 0,
    items_created INTEGER DEFAULT 0,
    items_updated INTEGER DEFAULT 0,
    items_deleted INTEGER DEFAULT 0,
    items_skipped INTEGER DEFAULT 0,
    items_failed INTEGER DEFAULT 0,

    -- Error handling
    error_message TEXT,
    error_details JSONB,
    warnings JSONB,                      -- Array of warning messages

    -- Metadata
    initiated_by VARCHAR(255),
    metadata JSONB DEFAULT '{}',

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sync_history_source ON sync_history(sync_source);
CREATE INDEX idx_sync_history_site ON sync_history(site_id);
CREATE INDEX idx_sync_history_status ON sync_history(status);
CREATE INDEX idx_sync_history_started ON sync_history(started_at DESC);

COMMENT ON TABLE sync_history IS 'History of synchronizations with external systems';

-- ============================================================================
-- IMPORT_BATCHES
-- Track bulk import operations
-- ============================================================================
CREATE TABLE import_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Context
    site_id UUID REFERENCES sites(id) ON DELETE CASCADE,
    import_source VARCHAR(100) NOT NULL, -- 'csv', 'json', 'homeseer_export', etc.
    filename VARCHAR(255),

    -- Status
    status VARCHAR(50) NOT NULL CHECK (status IN (
        'pending', 'validating', 'importing', 'completed', 'failed', 'rolled_back'
    )),

    -- Timestamps
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,

    -- Counts
    total_rows INTEGER DEFAULT 0,
    valid_rows INTEGER DEFAULT 0,
    imported_rows INTEGER DEFAULT 0,
    failed_rows INTEGER DEFAULT 0,
    skipped_rows INTEGER DEFAULT 0,

    -- Errors
    validation_errors JSONB,             -- Row-level validation errors
    import_errors JSONB,

    -- Metadata
    column_mapping JSONB,                -- How source columns map to DB fields
    options JSONB,                       -- Import options used
    initiated_by VARCHAR(255),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_import_batches_site ON import_batches(site_id);
CREATE INDEX idx_import_batches_status ON import_batches(status);
CREATE INDEX idx_import_batches_created ON import_batches(created_at DESC);

COMMENT ON TABLE import_batches IS 'Bulk import operation tracking';

-- ============================================================================
-- FUNCTION: Log audit entry
-- ============================================================================
CREATE OR REPLACE FUNCTION log_audit(
    p_org_id UUID,
    p_site_id UUID,
    p_entity_type VARCHAR,
    p_entity_id UUID,
    p_entity_name VARCHAR,
    p_action VARCHAR,
    p_actor_type VARCHAR,
    p_actor_id VARCHAR,
    p_actor_name VARCHAR,
    p_old_values JSONB,
    p_new_values JSONB,
    p_changed_fields TEXT[]
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO audit_log (
        organization_id, site_id, entity_type, entity_id, entity_name,
        action, actor_type, actor_id, actor_name,
        old_values, new_values, changed_fields
    ) VALUES (
        p_org_id, p_site_id, p_entity_type, p_entity_id, p_entity_name,
        p_action, p_actor_type, p_actor_id, p_actor_name,
        p_old_values, p_new_values, p_changed_fields
    ) RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION log_audit IS 'Helper function to create audit log entries';

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER trg_import_batches_updated
    BEFORE UPDATE ON import_batches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
