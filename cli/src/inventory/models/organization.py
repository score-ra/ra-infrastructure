"""
Organization model.
"""

from typing import Literal, Optional

from pydantic import BaseModel, Field

from inventory.models.base import BaseEntity, SlugMixin

OrgType = Literal["home", "business", "lab", "other"]


class OrganizationBase(BaseModel):
    """Base organization fields."""

    name: str = Field(..., min_length=1, max_length=255)
    type: OrgType = "home"
    description: Optional[str] = None
    is_active: bool = True


class OrganizationCreate(OrganizationBase):
    """Fields for creating an organization."""

    pass


class Organization(OrganizationBase, SlugMixin, BaseEntity):
    """Full organization entity."""

    pass
