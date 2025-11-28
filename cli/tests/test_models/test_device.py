"""Tests for device models."""

from datetime import date, datetime, timezone
from uuid import uuid4

import pytest

from inventory.models.device import Device, DeviceCreate, DeviceUpdate


class TestDeviceCreate:
    """Tests for DeviceCreate model."""

    def test_create_with_required_fields(self):
        """Test creating device with only required fields."""
        device = DeviceCreate(
            name="Test Device",
            device_type="sensor",
            site_id=uuid4(),
        )
        assert device.name == "Test Device"
        assert device.device_type == "sensor"
        assert device.status == "unknown"
        assert device.usage_status == "active"

    def test_create_with_usage_status(self):
        """Test creating device with usage status."""
        device = DeviceCreate(
            name="Spare Switch",
            device_type="switch",
            site_id=uuid4(),
            usage_status="stored",
            storage_location="Server closet shelf 3",
        )
        assert device.usage_status == "stored"
        assert device.storage_location == "Server closet shelf 3"

    def test_create_with_failure_info(self):
        """Test creating device with failure information."""
        device = DeviceCreate(
            name="Dead Sensor",
            device_type="sensor",
            site_id=uuid4(),
            usage_status="failed",
            failure_date=date(2025, 11, 1),
            failure_reason="Stopped responding, no LED",
            rma_reference="RMA-12345",
        )
        assert device.usage_status == "failed"
        assert device.failure_date == date(2025, 11, 1)
        assert device.failure_reason == "Stopped responding, no LED"
        assert device.rma_reference == "RMA-12345"

    def test_mac_address_validation_colon_format(self):
        """Test MAC address validation with colons."""
        device = DeviceCreate(
            name="Test",
            device_type="router",
            site_id=uuid4(),
            mac_address="00:1A:2B:3C:4D:5E",
        )
        assert device.mac_address == "00:1A:2B:3C:4D:5E"

    def test_mac_address_validation_dash_format(self):
        """Test MAC address validation with dashes."""
        device = DeviceCreate(
            name="Test",
            device_type="router",
            site_id=uuid4(),
            mac_address="00-1A-2B-3C-4D-5E",
        )
        assert device.mac_address == "00:1A:2B:3C:4D:5E"

    def test_mac_address_validation_no_separator(self):
        """Test MAC address validation without separators."""
        device = DeviceCreate(
            name="Test",
            device_type="router",
            site_id=uuid4(),
            mac_address="001A2B3C4D5E",
        )
        assert device.mac_address == "00:1A:2B:3C:4D:5E"

    def test_mac_address_validation_lowercase(self):
        """Test MAC address validation normalizes to uppercase."""
        device = DeviceCreate(
            name="Test",
            device_type="router",
            site_id=uuid4(),
            mac_address="00:1a:2b:3c:4d:5e",
        )
        assert device.mac_address == "00:1A:2B:3C:4D:5E"

    def test_mac_address_validation_invalid(self):
        """Test that invalid MAC address raises error."""
        with pytest.raises(ValueError):
            DeviceCreate(
                name="Test",
                device_type="router",
                site_id=uuid4(),
                mac_address="invalid",
            )

    def test_mac_address_validation_too_short(self):
        """Test that short MAC address raises error."""
        with pytest.raises(ValueError):
            DeviceCreate(
                name="Test",
                device_type="router",
                site_id=uuid4(),
                mac_address="00:1A:2B",
            )


class TestDeviceUpdate:
    """Tests for DeviceUpdate model."""

    def test_update_empty(self):
        """Test update with no fields."""
        update = DeviceUpdate()
        assert update.name is None
        assert update.status is None
        assert update.usage_status is None

    def test_update_partial(self):
        """Test update with partial fields."""
        update = DeviceUpdate(name="New Name", status="online")
        assert update.name == "New Name"
        assert update.status == "online"

    def test_update_usage_status(self):
        """Test update with usage status."""
        update = DeviceUpdate(usage_status="stored", storage_location="Garage shelf")
        assert update.usage_status == "stored"
        assert update.storage_location == "Garage shelf"

    def test_update_failure_info(self):
        """Test update with failure information."""
        update = DeviceUpdate(
            usage_status="failed",
            failure_date=date(2025, 11, 15),
            failure_reason="Power surge damage",
            rma_reference="RMA-99999",
        )
        assert update.usage_status == "failed"
        assert update.failure_date == date(2025, 11, 15)
        assert update.failure_reason == "Power surge damage"
        assert update.rma_reference == "RMA-99999"

    def test_update_invalid_status(self):
        """Test update with invalid status raises error."""
        with pytest.raises(ValueError):
            DeviceUpdate(status="invalid_status")

    def test_update_invalid_usage_status(self):
        """Test update with invalid usage status raises error."""
        with pytest.raises(ValueError):
            DeviceUpdate(usage_status="invalid_usage")


class TestDevice:
    """Tests for Device model."""

    def test_full_device(self):
        """Test full device entity."""
        now = datetime.now(timezone.utc)
        device = Device(
            id=uuid4(),
            name="Test Device",
            slug="test-device",
            device_type="sensor",
            site_id=uuid4(),
            status="online",
            usage_status="active",
            is_active=True,
            created_at=now,
            updated_at=now,
        )
        assert device.name == "Test Device"
        assert device.status == "online"
        assert device.usage_status == "active"

    def test_device_with_usage_status_values(self):
        """Test device with different usage status values."""
        now = datetime.now(timezone.utc)

        # Test each valid usage status
        for usage_status in ["active", "stored", "failed", "retired", "pending"]:
            device = Device(
                id=uuid4(),
                name=f"Test {usage_status}",
                slug=f"test-{usage_status}",
                device_type="sensor",
                site_id=uuid4(),
                status="unknown",
                usage_status=usage_status,
                is_active=True,
                created_at=now,
                updated_at=now,
            )
            assert device.usage_status == usage_status

    def test_device_with_storage_info(self):
        """Test device with storage location."""
        now = datetime.now(timezone.utc)
        device = Device(
            id=uuid4(),
            name="Spare Router",
            slug="spare-router",
            device_type="router",
            site_id=uuid4(),
            status="offline",
            usage_status="stored",
            storage_location="IT closet, shelf B",
            is_active=True,
            created_at=now,
            updated_at=now,
        )
        assert device.usage_status == "stored"
        assert device.storage_location == "IT closet, shelf B"

    def test_device_with_failure_info(self):
        """Test device with failure information."""
        now = datetime.now(timezone.utc)
        device = Device(
            id=uuid4(),
            name="Dead Switch",
            slug="dead-switch",
            device_type="switch",
            site_id=uuid4(),
            status="offline",
            usage_status="failed",
            failure_date=date(2025, 10, 15),
            failure_reason="Lightning strike",
            rma_reference="RMA-2025-001",
            is_active=True,
            created_at=now,
            updated_at=now,
        )
        assert device.usage_status == "failed"
        assert device.failure_date == date(2025, 10, 15)
        assert device.failure_reason == "Lightning strike"
        assert device.rma_reference == "RMA-2025-001"
