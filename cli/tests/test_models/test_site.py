"""Tests for site models."""

from datetime import datetime, timezone
from uuid import uuid4

import pytest

from inventory.models.site import Site, SiteCreate


class TestSiteCreate:
    """Tests for SiteCreate model."""

    def test_create_with_required_fields(self):
        """Test creating site with only required fields."""
        site = SiteCreate(name="Test Site", organization_id=uuid4())
        assert site.name == "Test Site"
        assert site.site_type == "residence"
        assert site.timezone == "America/Los_Angeles"
        assert site.is_primary is False

    def test_create_with_all_fields(self):
        """Test creating site with all fields."""
        org_id = uuid4()
        site = SiteCreate(
            name="Test Site",
            organization_id=org_id,
            site_type="office",
            city="San Francisco",
            state="CA",
            country="USA",
            timezone="America/New_York",
            is_primary=True,
        )
        assert site.name == "Test Site"
        assert site.organization_id == org_id
        assert site.site_type == "office"
        assert site.city == "San Francisco"
        assert site.is_primary is True

    def test_create_with_invalid_type(self):
        """Test that invalid site type raises error."""
        with pytest.raises(ValueError):
            SiteCreate(name="Test", organization_id=uuid4(), site_type="invalid")

    def test_all_valid_site_types(self):
        """Test all valid site types."""
        org_id = uuid4()
        for site_type in ["residence", "office", "datacenter", "warehouse", "other"]:
            site = SiteCreate(name="Test", organization_id=org_id, site_type=site_type)
            assert site.site_type == site_type


class TestSite:
    """Tests for Site model."""

    def test_full_site(self):
        """Test full site entity."""
        now = datetime.now(timezone.utc)
        site = Site(
            id=uuid4(),
            name="Test Site",
            slug="test-site",
            organization_id=uuid4(),
            site_type="residence",
            is_active=True,
            is_primary=False,
            timezone="America/Los_Angeles",
            created_at=now,
            updated_at=now,
        )
        assert site.name == "Test Site"
        assert site.slug == "test-site"
