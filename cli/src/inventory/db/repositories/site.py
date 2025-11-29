"""
Site repository.
"""

from typing import Optional
from uuid import UUID

from pydantic import BaseModel

from inventory.db.connection import get_connection
from inventory.db.repository import BaseRepository
from inventory.models.site import Site, SiteCreate


class SiteUpdate(BaseModel):
    """Fields for updating a site."""

    name: Optional[str] = None
    site_type: Optional[str] = None
    city: Optional[str] = None
    timezone: Optional[str] = None
    is_primary: Optional[bool] = None
    is_active: Optional[bool] = None


class SiteRepository(BaseRepository[Site, SiteCreate, SiteUpdate]):
    """Repository for site operations."""

    @property
    def table_name(self) -> str:
        return "sites"

    @property
    def model_class(self) -> type[Site]:
        return Site

    def list_by_organization(self, org_slug: str) -> list[dict]:
        """List sites for an organization with organization name."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT s.*, o.name as org_name, o.slug as org_slug
                    FROM sites s
                    JOIN organizations o ON s.organization_id = o.id
                    WHERE o.slug = %s
                    ORDER BY s.name
                    """,
                    (org_slug,),
                )
                return cur.fetchall()

    def list_all_with_org(self) -> list[dict]:
        """List all sites with organization info."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT s.*, o.name as org_name, o.slug as org_slug
                    FROM sites s
                    JOIN organizations o ON s.organization_id = o.id
                    ORDER BY o.name, s.name
                    """
                )
                return cur.fetchall()

    def get_with_counts(self, slug: str) -> Optional[dict]:
        """Get site with zone, network, and device counts."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT s.*, o.name as org_name,
                        (SELECT COUNT(*) FROM zones z WHERE z.site_id = s.id) as zone_count,
                        (SELECT COUNT(*) FROM networks n WHERE n.site_id = s.id) as network_count,
                        (SELECT COUNT(*) FROM devices d WHERE d.site_id = s.id) as device_count
                    FROM sites s
                    JOIN organizations o ON s.organization_id = o.id
                    WHERE s.slug = %s
                    """,
                    (slug,),
                )
                return cur.fetchone()

    def get_organization_id(self, org_slug: str) -> Optional[UUID]:
        """Get organization ID by slug."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id FROM organizations WHERE slug = %s",
                    (org_slug,),
                )
                row = cur.fetchone()
                return row["id"] if row else None
