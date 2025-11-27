"""
Site model.
"""

from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field

from inventory.models.base import BaseEntity, SlugMixin

SiteType = Literal["residence", "office", "datacenter", "warehouse", "other"]


class SiteBase(BaseModel):
    """Base site fields."""

    name: str = Field(..., min_length=1, max_length=255)
    site_type: Optional[SiteType] = "residence"
    address_line1: Optional[str] = None
    address_line2: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    postal_code: Optional[str] = None
    country: str = "USA"
    timezone: str = "America/Los_Angeles"
    is_primary: bool = False
    is_active: bool = True


class SiteCreate(SiteBase):
    """Fields for creating a site."""

    organization_id: UUID


class Site(SiteBase, SlugMixin, BaseEntity):
    """Full site entity."""

    organization_id: UUID
    latitude: Optional[float] = None
    longitude: Optional[float] = None
