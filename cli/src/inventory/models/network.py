"""
Network model.
"""

from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field

from inventory.models.base import BaseEntity, SlugMixin

NetworkType = Literal[
    "ethernet", "wifi", "zwave", "zigbee", "bluetooth", "thread", "matter", "other"
]


class NetworkBase(BaseModel):
    """Base network fields."""

    name: str = Field(..., min_length=1, max_length=255)
    network_type: NetworkType
    cidr: Optional[str] = None
    gateway_ip: Optional[str] = None
    vlan_id: Optional[int] = Field(None, ge=1, le=4094)
    ssid: Optional[str] = None
    frequency: Optional[str] = None
    security_type: Optional[str] = None
    channel: Optional[int] = None
    pan_id: Optional[str] = None
    is_primary: bool = False
    is_active: bool = True


class NetworkCreate(NetworkBase):
    """Fields for creating a network."""

    site_id: UUID
    controller_device_id: Optional[UUID] = None


class Network(NetworkBase, SlugMixin, BaseEntity):
    """Full network entity."""

    site_id: UUID
    controller_device_id: Optional[UUID] = None
