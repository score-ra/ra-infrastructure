"""
Entity-specific repositories.
"""

from inventory.db.repositories.device import DeviceRepository
from inventory.db.repositories.network import NetworkRepository
from inventory.db.repositories.organization import OrganizationRepository
from inventory.db.repositories.site import SiteRepository
from inventory.db.repositories.zone import ZoneRepository

__all__ = [
    "OrganizationRepository",
    "SiteRepository",
    "ZoneRepository",
    "DeviceRepository",
    "NetworkRepository",
]
