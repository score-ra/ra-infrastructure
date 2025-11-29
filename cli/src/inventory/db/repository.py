"""
Base repository pattern for database operations.
"""

import re
from abc import ABC, abstractmethod
from typing import Any, Generic, Optional, TypeVar
from uuid import UUID

from pydantic import BaseModel

from inventory.db.connection import get_connection

T = TypeVar("T", bound=BaseModel)
CreateT = TypeVar("CreateT", bound=BaseModel)
UpdateT = TypeVar("UpdateT", bound=BaseModel)


class BaseRepository(ABC, Generic[T, CreateT, UpdateT]):
    """Abstract base repository with common CRUD operations."""

    @property
    @abstractmethod
    def table_name(self) -> str:
        """Table name for this repository."""
        pass

    @property
    @abstractmethod
    def model_class(self) -> type[T]:
        """Model class for this repository."""
        pass

    @staticmethod
    def generate_slug(name: str) -> str:
        """Generate a URL-friendly slug from a name."""
        return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")

    def get_by_id(self, id: UUID) -> Optional[T]:
        """Get entity by ID."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"SELECT * FROM {self.table_name} WHERE id = %s", (id,)
                )
                row = cur.fetchone()
                return self.model_class(**row) if row else None

    def get_by_slug(self, slug: str) -> Optional[T]:
        """Get entity by slug."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"SELECT * FROM {self.table_name} WHERE slug = %s", (slug,)
                )
                row = cur.fetchone()
                return self.model_class(**row) if row else None

    def list_all(
        self,
        filters: Optional[dict[str, Any]] = None,
        order_by: str = "name",
        limit: int = 100,
    ) -> list[T]:
        """List all entities with optional filters."""
        query = f"SELECT * FROM {self.table_name}"
        params: list[Any] = []

        if filters:
            where_clauses = []
            for key, value in filters.items():
                where_clauses.append(f"{key} = %s")
                params.append(value)
            query += " WHERE " + " AND ".join(where_clauses)

        query += f" ORDER BY {order_by} LIMIT %s"
        params.append(limit)

        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, params)
                rows = cur.fetchall()
                return [self.model_class(**row) for row in rows]

    def create(self, data: CreateT) -> T:
        """Create a new entity."""
        fields = data.model_dump(exclude_none=True)

        # Generate slug from name if not provided
        if "slug" not in fields and "name" in fields:
            fields["slug"] = self.generate_slug(fields["name"])

        columns = ", ".join(fields.keys())
        placeholders = ", ".join(["%s"] * len(fields))
        values = list(fields.values())

        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"""
                    INSERT INTO {self.table_name} ({columns})
                    VALUES ({placeholders})
                    RETURNING *
                    """,
                    values,
                )
                row = cur.fetchone()
                conn.commit()
                return self.model_class(**row)

    def update(self, slug: str, data: UpdateT) -> Optional[T]:
        """Update an entity by slug."""
        fields = data.model_dump(exclude_none=True, exclude_unset=True)

        if not fields:
            return self.get_by_slug(slug)

        set_clause = ", ".join(f"{k} = %s" for k in fields.keys())
        values = list(fields.values()) + [slug]

        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"""
                    UPDATE {self.table_name}
                    SET {set_clause}
                    WHERE slug = %s
                    RETURNING *
                    """,
                    values,
                )
                row = cur.fetchone()
                conn.commit()
                return self.model_class(**row) if row else None

    def delete(self, slug: str) -> bool:
        """Delete an entity by slug."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"DELETE FROM {self.table_name} WHERE slug = %s RETURNING id",
                    (slug,),
                )
                result = cur.fetchone()
                conn.commit()
                return result is not None

    def exists(self, slug: str) -> bool:
        """Check if entity exists by slug."""
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"SELECT 1 FROM {self.table_name} WHERE slug = %s LIMIT 1",
                    (slug,),
                )
                return cur.fetchone() is not None

    def count(self, filters: Optional[dict[str, Any]] = None) -> int:
        """Count entities with optional filters."""
        query = f"SELECT COUNT(*) as count FROM {self.table_name}"
        params: list[Any] = []

        if filters:
            where_clauses = []
            for key, value in filters.items():
                where_clauses.append(f"{key} = %s")
                params.append(value)
            query += " WHERE " + " AND ".join(where_clauses)

        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, params)
                row = cur.fetchone()
                return row["count"] if row else 0
