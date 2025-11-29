-- Migration: 005_device_usage_status
-- Description: Add usage_status column to track device deployment state
-- Created: 2025-11-27
-- Reference: CR-001 Device Usage Status Enhancement

-- ============================================================================
-- ADD USAGE_STATUS COLUMN
-- Tracks deployment state (active, stored, failed, retired, pending)
-- This is orthogonal to the existing 'status' column (operational state)
-- ============================================================================

-- Add usage_status column with default 'active'
ALTER TABLE devices
ADD COLUMN usage_status VARCHAR(50) DEFAULT 'active';

-- All existing devices are assumed active
UPDATE devices SET usage_status = 'active' WHERE usage_status IS NULL;

-- Add NOT NULL constraint after backfill
ALTER TABLE devices
ALTER COLUMN usage_status SET NOT NULL;

-- Add check constraint for allowed values
ALTER TABLE devices
ADD CONSTRAINT devices_usage_status_check
CHECK (usage_status IN (
    'active',      -- Currently installed and in use
    'stored',      -- Functional, in storage (spare, seasonal, awaiting deployment)
    'failed',      -- Hardware failure, out of service (may be under warranty/RMA)
    'retired',     -- Permanently out of service, kept for records
    'pending'      -- Newly acquired, not yet deployed
));

-- Add index for querying by usage status
CREATE INDEX idx_devices_usage_status ON devices(usage_status);

-- ============================================================================
-- ADD OPTIONAL TRACKING FIELDS
-- For storage location and failure tracking
-- ============================================================================

-- Storage location for tracking where stored devices are
ALTER TABLE devices
ADD COLUMN storage_location VARCHAR(255);

-- Failure tracking fields
ALTER TABLE devices
ADD COLUMN failure_date DATE;

ALTER TABLE devices
ADD COLUMN failure_reason TEXT;

ALTER TABLE devices
ADD COLUMN rma_reference VARCHAR(100);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON COLUMN devices.usage_status IS 'Deployment state: active (in use), stored (in storage), failed (broken), retired (out of service), pending (new)';
COMMENT ON COLUMN devices.storage_location IS 'Physical location when device is stored (e.g., "Server closet shelf 3")';
COMMENT ON COLUMN devices.failure_date IS 'Date when device failed (for failed status)';
COMMENT ON COLUMN devices.failure_reason IS 'Description of failure cause';
COMMENT ON COLUMN devices.rma_reference IS 'RMA/warranty claim reference number';
