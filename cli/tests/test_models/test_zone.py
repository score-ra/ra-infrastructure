"""Tests for zone models."""

from datetime import datetime, timezone
from uuid import uuid4

import pytest

from inventory.models.zone import Zone, ZoneCreate


class TestZoneCreate:
    """Tests for ZoneCreate model."""

    def test_create_with_required_fields(self):
        """Test creating zone with only required fields."""
        zone = ZoneCreate(name="Test Zone", site_id=uuid4())
        assert zone.name == "Test Zone"
        assert zone.zone_type == "room"
        assert zone.floor_number is None
        assert zone.parent_zone_id is None

    def test_create_with_all_fields(self):
        """Test creating zone with all fields."""
        site_id = uuid4()
        parent_id = uuid4()
        zone = ZoneCreate(
            name="Test Zone",
            site_id=site_id,
            parent_zone_id=parent_id,
            zone_type="floor",
            floor_number=2,
            area_sqft=500.5,
        )
        assert zone.name == "Test Zone"
        assert zone.site_id == site_id
        assert zone.parent_zone_id == parent_id
        assert zone.zone_type == "floor"
        assert zone.floor_number == 2
        assert zone.area_sqft == 500.5

    def test_create_with_invalid_type(self):
        """Test that invalid zone type raises error."""
        with pytest.raises(ValueError):
            ZoneCreate(name="Test", site_id=uuid4(), zone_type="invalid")

    def test_all_valid_zone_types(self):
        """Test all valid zone types."""
        site_id = uuid4()
        for zone_type in [
            "building",
            "floor",
            "room",
            "closet",
            "outdoor",
            "garage",
            "other",
        ]:
            zone = ZoneCreate(name="Test", site_id=site_id, zone_type=zone_type)
            assert zone.zone_type == zone_type

    def test_color_validation_valid(self):
        """Test valid hex color."""
        zone = ZoneCreate(name="Test", site_id=uuid4(), color="#FF0000")
        assert zone.color == "#FF0000"

    def test_color_validation_invalid(self):
        """Test that invalid color raises error."""
        with pytest.raises(ValueError):
            ZoneCreate(name="Test", site_id=uuid4(), color="red")


class TestZone:
    """Tests for Zone model."""

    def test_full_zone(self):
        """Test full zone entity."""
        now = datetime.now(timezone.utc)
        zone = Zone(
            id=uuid4(),
            name="Test Zone",
            slug="test-zone",
            site_id=uuid4(),
            zone_type="room",
            is_active=True,
            sort_order=0,
            created_at=now,
            updated_at=now,
        )
        assert zone.name == "Test Zone"
        assert zone.slug == "test-zone"
