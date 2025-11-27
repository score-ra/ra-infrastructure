"""
Device model.
"""

import re
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from inventory.models.base import BaseEntity, SlugMixin

DeviceStatus = Literal["online", "offline", "unknown", "maintenance"]


class DeviceBase(BaseModel):
    """Base device fields."""

    name: str = Field(..., min_length=1, max_length=255)
    device_type: str = Field(..., min_length=1, max_length=100)
    status: DeviceStatus = "unknown"
    manufacturer: Optional[str] = None
    model: Optional[str] = None
    serial_number: Optional[str] = None
    firmware_version: Optional[str] = None
    hostname: Optional[str] = None
    mac_address: Optional[str] = None
    ip_address: Optional[str] = None
    is_active: bool = True

    @field_validator("mac_address")
    @classmethod
    def validate_mac(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        # Accept various MAC formats and normalize
        mac = re.sub(r"[^0-9A-Fa-f]", "", v)
        if len(mac) != 12:
            raise ValueError("MAC address must be 12 hex characters")
        return ":".join(mac[i : i + 2].upper() for i in range(0, 12, 2))


class DeviceCreate(DeviceBase):
    """Fields for creating a device."""

    site_id: UUID
    zone_id: Optional[UUID] = None
    network_id: Optional[UUID] = None
    category_id: Optional[UUID] = None


class DeviceUpdate(BaseModel):
    """Fields for updating a device."""

    name: Optional[str] = Field(None, min_length=1, max_length=255)
    status: Optional[DeviceStatus] = None
    zone_id: Optional[UUID] = None
    manufacturer: Optional[str] = None
    model: Optional[str] = None
    serial_number: Optional[str] = None
    firmware_version: Optional[str] = None
    mac_address: Optional[str] = None
    ip_address: Optional[str] = None

    @field_validator("mac_address")
    @classmethod
    def validate_mac(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        mac = re.sub(r"[^0-9A-Fa-f]", "", v)
        if len(mac) != 12:
            raise ValueError("MAC address must be 12 hex characters")
        return ":".join(mac[i : i + 2].upper() for i in range(0, 12, 2))


class Device(DeviceBase, SlugMixin, BaseEntity):
    """Full device entity."""

    site_id: UUID
    zone_id: Optional[UUID] = None
    network_id: Optional[UUID] = None
    category_id: Optional[UUID] = None
    zwave_node_id: Optional[int] = None
    zigbee_ieee_address: Optional[str] = None
    homeseer_ref: Optional[int] = None
