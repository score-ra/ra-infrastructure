"""
Device repository.
"""

from typing import Any, Optional
from uuid import UUID

from inventory.db.connection import get_connection
from inventory.db.repository import BaseRepository
from inventory.models.device import Device, DeviceCreate, DeviceUpdate


class DeviceRepository(BaseRepository[Device, DeviceCreate, DeviceUpdate]):
    """Repository for device operations."""

    @property
    def table_name(self) -> str:
        return "devices"

    @property
    def model_class(self) -> type[Device]:
        return Device

    def list_with_details(
        self,
        site_slug: Optional[str] = None,
        zone_slug: Optional[str] = None,
        category_slug: Optional[str] = None,
        status: Optional[str] = None,
        limit: int = 50,
    ) -> list[dict]:
        """List devices with site, zone, and category info."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                query = """
                    SELECT
                        d.*, s.name as site_name, s.slug as site_slug,
                        z.name as zone_name, n.name as network_name,
                        c.name as category_name
                    FROM devices d
                    JOIN sites s ON d.site_id = s.id
                    LEFT JOIN zones z ON d.zone_id = z.id
                    LEFT JOIN networks n ON d.network_id = n.id
                    LEFT JOIN device_categories c ON d.category_id = c.id
                    WHERE d.is_active = TRUE
                """
                params: list[Any] = []

                if site_slug:
                    query += " AND s.slug = %s"
                    params.append(site_slug)

                if zone_slug:
                    query += " AND z.slug = %s"
                    params.append(zone_slug)

                if category_slug:
                    query += " AND c.slug = %s"
                    params.append(category_slug)

                if status:
                    query += " AND d.status = %s"
                    params.append(status)

                query += " ORDER BY d.name LIMIT %s"
                params.append(limit)

                cur.execute(query, params)
                return cur.fetchall()

    def get_with_details(self, slug: str) -> Optional[dict]:
        """Get device with all related info."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT
                        d.*, s.name as site_name, z.name as zone_name,
                        n.name as network_name, c.name as category_name
                    FROM devices d
                    JOIN sites s ON d.site_id = s.id
                    LEFT JOIN zones z ON d.zone_id = z.id
                    LEFT JOIN networks n ON d.network_id = n.id
                    LEFT JOIN device_categories c ON d.category_id = c.id
                    WHERE d.slug = %s
                    """,
                    (slug,),
                )
                return cur.fetchone()

    def count_by_group(
        self, group_by: str = "category", site_slug: Optional[str] = None
    ) -> list[dict]:
        """Count devices grouped by category, type, zone, or status."""
        group_column = {
            "category": "c.name",
            "type": "d.device_type",
            "zone": "z.name",
            "status": "d.status",
        }.get(group_by, "c.name")

        with get_connection() as conn:
            with conn.cursor() as cur:
                query = f"""
                    SELECT
                        COALESCE({group_column}, 'Unassigned') as group_name,
                        COUNT(*) as count
                    FROM devices d
                    JOIN sites s ON d.site_id = s.id
                    LEFT JOIN zones z ON d.zone_id = z.id
                    LEFT JOIN device_categories c ON d.category_id = c.id
                    WHERE d.is_active = TRUE
                """
                params: list[Any] = []

                if site_slug:
                    query += " AND s.slug = %s"
                    params.append(site_slug)

                query += f" GROUP BY {group_column} ORDER BY count DESC"

                cur.execute(query, params)
                return cur.fetchall()

    def get_site_id(self, site_slug: str) -> Optional[UUID]:
        """Get site ID by slug."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT id FROM sites WHERE slug = %s", (site_slug,))
                row = cur.fetchone()
                return row["id"] if row else None

    def get_zone_id(self, zone_slug: str, site_id: UUID) -> Optional[UUID]:
        """Get zone ID by slug within a site."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id FROM zones WHERE slug = %s AND site_id = %s",
                    (zone_slug, site_id),
                )
                row = cur.fetchone()
                return row["id"] if row else None

    def get_category_id(self, category_slug: str) -> Optional[UUID]:
        """Get category ID by slug."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id FROM device_categories WHERE slug = %s",
                    (category_slug,),
                )
                row = cur.fetchone()
                return row["id"] if row else None
