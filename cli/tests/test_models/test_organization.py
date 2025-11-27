"""Tests for organization models."""

from datetime import datetime, timezone
from uuid import uuid4

import pytest

from inventory.models.organization import Organization, OrganizationCreate


class TestOrganizationCreate:
    """Tests for OrganizationCreate model."""

    def test_create_with_required_fields(self):
        """Test creating org with only required fields."""
        org = OrganizationCreate(name="Test Org")
        assert org.name == "Test Org"
        assert org.type == "home"
        assert org.description is None
        assert org.is_active is True

    def test_create_with_all_fields(self):
        """Test creating org with all fields."""
        org = OrganizationCreate(
            name="Test Org",
            type="business",
            description="A test organization",
            is_active=False,
        )
        assert org.name == "Test Org"
        assert org.type == "business"
        assert org.description == "A test organization"
        assert org.is_active is False

    def test_create_with_invalid_type(self):
        """Test that invalid org type raises error."""
        with pytest.raises(ValueError):
            OrganizationCreate(name="Test", type="invalid")

    def test_create_with_empty_name(self):
        """Test that empty name raises error."""
        with pytest.raises(ValueError):
            OrganizationCreate(name="")

    def test_all_valid_types(self):
        """Test all valid organization types."""
        for org_type in ["home", "business", "lab", "other"]:
            org = OrganizationCreate(name="Test", type=org_type)
            assert org.type == org_type


class TestOrganization:
    """Tests for Organization model."""

    def test_full_organization(self):
        """Test full organization entity."""
        now = datetime.now(timezone.utc)
        org = Organization(
            id=uuid4(),
            name="Test Org",
            slug="test-org",
            type="home",
            is_active=True,
            created_at=now,
            updated_at=now,
        )
        assert org.name == "Test Org"
        assert org.slug == "test-org"
        assert org.type == "home"
