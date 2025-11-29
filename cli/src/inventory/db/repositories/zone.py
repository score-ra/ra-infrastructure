"""
Zone repository.
"""

from typing import Optional
from uuid import UUID

from pydantic import BaseModel

from inventory.db.connection import get_connection
from inventory.db.repository import BaseRepository
from inventory.models.zone import Zone, ZoneCreate


class ZoneUpdate(BaseModel):
    """Fields for updating a zone."""

    name: Optional[str] = None
    zone_type: Optional[str] = None
    floor_number: Optional[int] = None
    parent_zone_id: Optional[UUID] = None
    is_active: Optional[bool] = None


class ZoneRepository(BaseRepository[Zone, ZoneCreate, ZoneUpdate]):
    """Repository for zone operations."""

    @property
    def table_name(self) -> str:
        return "zones"

    @property
    def model_class(self) -> type[Zone]:
        return Zone

    def list_by_site(self, site_slug: str, zone_type: Optional[str] = None) -> list[dict]:
        """List zones for a site with parent info."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                query = """
                    SELECT
                        z.*, s.name as site_name, s.slug as site_slug,
                        p.name as parent_name,
                        (SELECT COUNT(*) FROM devices d WHERE d.zone_id = z.id) as device_count
                    FROM zones z
                    JOIN sites s ON z.site_id = s.id
                    LEFT JOIN zones p ON z.parent_zone_id = p.id
                    WHERE s.slug = %s AND z.is_active = TRUE
                """
                params = [site_slug]

                if zone_type:
                    query += " AND z.zone_type = %s"
                    params.append(zone_type)

                query += " ORDER BY z.sort_order, z.name"

                cur.execute(query, params)
                return cur.fetchall()

    def list_all_with_details(
        self, site_slug: Optional[str] = None, zone_type: Optional[str] = None
    ) -> list[dict]:
        """List all zones with site and parent info."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                query = """
                    SELECT
                        z.*, s.name as site_name, s.slug as site_slug,
                        p.name as parent_name,
                        (SELECT COUNT(*) FROM devices d WHERE d.zone_id = z.id) as device_count
                    FROM zones z
                    JOIN sites s ON z.site_id = s.id
                    LEFT JOIN zones p ON z.parent_zone_id = p.id
                    WHERE z.is_active = TRUE
                """
                params = []

                if site_slug:
                    query += " AND s.slug = %s"
                    params.append(site_slug)

                if zone_type:
                    query += " AND z.zone_type = %s"
                    params.append(zone_type)

                query += " ORDER BY s.name, z.sort_order, z.name"

                cur.execute(query, params)
                return cur.fetchall()

    def get_with_details(self, slug: str) -> Optional[dict]:
        """Get zone with site name and child zones."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT z.*, s.name as site_name, p.name as parent_name
                    FROM zones z
                    JOIN sites s ON z.site_id = s.id
                    LEFT JOIN zones p ON z.parent_zone_id = p.id
                    WHERE z.slug = %s
                    """,
                    (slug,),
                )
                zone = cur.fetchone()

                if zone:
                    # Get device count
                    cur.execute(
                        "SELECT COUNT(*) as count FROM devices WHERE zone_id = %s",
                        (zone["id"],),
                    )
                    zone["device_count"] = cur.fetchone()["count"]

                    # Get child zones
                    cur.execute(
                        """
                        SELECT name, slug FROM zones
                        WHERE parent_zone_id = %s
                        ORDER BY sort_order, name
                        """,
                        (zone["id"],),
                    )
                    zone["child_zones"] = cur.fetchall()

                return zone

    def get_site_id(self, site_slug: str) -> Optional[UUID]:
        """Get site ID by slug."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id FROM sites WHERE slug = %s",
                    (site_slug,),
                )
                row = cur.fetchone()
                return row["id"] if row else None

    def get_parent_id(self, parent_slug: str, site_id: UUID) -> Optional[UUID]:
        """Get parent zone ID by slug within a site."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id FROM zones WHERE slug = %s AND site_id = %s",
                    (parent_slug, site_id),
                )
                row = cur.fetchone()
                return row["id"] if row else None
