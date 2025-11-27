"""
Network repository.
"""

from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel

from inventory.db.connection import get_connection
from inventory.db.repository import BaseRepository
from inventory.models.network import Network, NetworkCreate


class NetworkUpdate(BaseModel):
    """Fields for updating a network."""

    name: Optional[str] = None
    cidr: Optional[str] = None
    gateway_ip: Optional[str] = None
    vlan_id: Optional[int] = None
    ssid: Optional[str] = None
    is_primary: Optional[bool] = None
    is_active: Optional[bool] = None


class NetworkRepository(BaseRepository[Network, NetworkCreate, NetworkUpdate]):
    """Repository for network operations."""

    @property
    def table_name(self) -> str:
        return "networks"

    @property
    def model_class(self) -> type[Network]:
        return Network

    def list_with_details(
        self,
        site_slug: Optional[str] = None,
        network_type: Optional[str] = None,
    ) -> list[dict]:
        """List networks with site and device count."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                query = """
                    SELECT
                        n.*, s.name as site_name, s.slug as site_slug,
                        (SELECT COUNT(*) FROM devices d WHERE d.network_id = n.id) as device_count
                    FROM networks n
                    JOIN sites s ON n.site_id = s.id
                    WHERE n.is_active = TRUE
                """
                params: list[Any] = []

                if site_slug:
                    query += " AND s.slug = %s"
                    params.append(site_slug)

                if network_type:
                    query += " AND n.network_type = %s"
                    params.append(network_type)

                query += " ORDER BY s.name, n.name"

                cur.execute(query, params)
                return cur.fetchall()

    def get_with_details(self, slug: str) -> Optional[dict]:
        """Get network with site and controller info."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT
                        n.*, s.name as site_name,
                        d.name as controller_name
                    FROM networks n
                    JOIN sites s ON n.site_id = s.id
                    LEFT JOIN devices d ON n.controller_device_id = d.id
                    WHERE n.slug = %s
                    """,
                    (slug,),
                )
                network = cur.fetchone()

                if network:
                    # Get device count
                    cur.execute(
                        "SELECT COUNT(*) as count FROM devices WHERE network_id = %s",
                        (network["id"],),
                    )
                    network["device_count"] = cur.fetchone()["count"]

                    # Get IP allocation count
                    cur.execute(
                        "SELECT COUNT(*) as count FROM ip_allocations WHERE network_id = %s",
                        (network["id"],),
                    )
                    network["ip_count"] = cur.fetchone()["count"]

                return network

    def list_ip_allocations(self, network_slug: str) -> list[dict]:
        """List IP allocations for a network."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                # Get network
                cur.execute(
                    "SELECT id, cidr FROM networks WHERE slug = %s",
                    (network_slug,),
                )
                network = cur.fetchone()

                if not network or not network["cidr"]:
                    return []

                cur.execute(
                    """
                    SELECT
                        ip.ip_address, ip.allocation_type, ip.hostname,
                        ip.is_active, ip.last_seen, d.name as device_name
                    FROM ip_allocations ip
                    LEFT JOIN devices d ON ip.device_id = d.id
                    WHERE ip.network_id = %s
                    ORDER BY ip.ip_address
                    """,
                    (network["id"],),
                )
                return cur.fetchall()

    def get_site_id(self, site_slug: str) -> Optional[UUID]:
        """Get site ID by slug."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT id FROM sites WHERE slug = %s", (site_slug,))
                row = cur.fetchone()
                return row["id"] if row else None
