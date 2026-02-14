-- Migration 006: Drop homeseer_ref column (replaced by homeassistant_entity_id from migration 003)
-- Date: 2026-02-14

DROP INDEX IF EXISTS idx_devices_homeseer;
ALTER TABLE devices DROP COLUMN IF EXISTS homeseer_ref;
CREATE INDEX IF NOT EXISTS idx_devices_ha_entity
  ON devices(homeassistant_entity_id)
  WHERE homeassistant_entity_id IS NOT NULL;
