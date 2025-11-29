"""
Base model with common fields.
"""

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class BaseEntity(BaseModel):
    """Base entity with common fields."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    updated_at: datetime
    metadata: dict[str, Any] = {}


class SlugMixin(BaseModel):
    """Mixin for entities with slug field."""

    slug: str
