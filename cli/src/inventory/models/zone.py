"""
Zone model.
"""

from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field

from inventory.models.base import BaseEntity, SlugMixin

ZoneType = Literal["building", "floor", "room", "closet", "outdoor", "garage", "other"]


class ZoneBase(BaseModel):
    """Base zone fields."""

    name: str = Field(..., min_length=1, max_length=255)
    zone_type: Optional[ZoneType] = "room"
    floor_number: Optional[int] = None
    area_sqft: Optional[float] = None
    sort_order: int = 0
    icon: Optional[str] = None
    color: Optional[str] = Field(None, pattern=r"^#[0-9A-Fa-f]{6}$")
    is_active: bool = True


class ZoneCreate(ZoneBase):
    """Fields for creating a zone."""

    site_id: UUID
    parent_zone_id: Optional[UUID] = None


class Zone(ZoneBase, SlugMixin, BaseEntity):
    """Full zone entity."""

    site_id: UUID
    parent_zone_id: Optional[UUID] = None
