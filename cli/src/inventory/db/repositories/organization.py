"""
Organization repository.
"""

from typing import Optional

from pydantic import BaseModel

from inventory.db.connection import get_connection
from inventory.db.repository import BaseRepository
from inventory.models.organization import Organization, OrganizationCreate


class OrganizationUpdate(BaseModel):
    """Fields for updating an organization."""

    name: Optional[str] = None
    description: Optional[str] = None
    is_active: Optional[bool] = None


class OrganizationRepository(BaseRepository[Organization, OrganizationCreate, OrganizationUpdate]):
    """Repository for organization operations."""

    @property
    def table_name(self) -> str:
        return "organizations"

    @property
    def model_class(self) -> type[Organization]:
        return Organization

    def get_with_site_count(self, slug: str) -> Optional[dict]:
        """Get organization with site count."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT o.*, COUNT(s.id) as site_count
                    FROM organizations o
                    LEFT JOIN sites s ON o.id = s.organization_id
                    WHERE o.slug = %s
                    GROUP BY o.id
                    """,
                    (slug,),
                )
                return cur.fetchone()

    def list_active(self) -> list[Organization]:
        """List only active organizations."""
        return self.list_all(filters={"is_active": True})
