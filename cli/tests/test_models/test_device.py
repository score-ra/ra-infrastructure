"""Tests for device models."""

from datetime import datetime, timezone
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

    def test_update_partial(self):
        """Test update with partial fields."""
        update = DeviceUpdate(name="New Name", status="online")
        assert update.name == "New Name"
        assert update.status == "online"

    def test_update_invalid_status(self):
        """Test update with invalid status raises error."""
        with pytest.raises(ValueError):
            DeviceUpdate(status="invalid_status")


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
            is_active=True,
            created_at=now,
            updated_at=now,
        )
        assert device.name == "Test Device"
        assert device.status == "online"
