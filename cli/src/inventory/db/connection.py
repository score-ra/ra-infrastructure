"""
Database connection management.
"""

from contextlib import contextmanager
from typing import Any, Generator

import psycopg
from psycopg.rows import dict_row

from inventory.config import get_settings


@contextmanager
def get_connection() -> Generator[psycopg.Connection, None, None]:
    """Get a database connection context manager."""
    settings = get_settings()
    conn = psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        dbname=settings.db_name,
        user=settings.db_user,
        password=settings.db_password,
        row_factory=dict_row,
    )
    try:
        yield conn
    finally:
        conn.close()


def get_connection_status() -> dict[str, Any]:
    """Check database connection status."""
    settings = get_settings()

    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT version()")
                version = cur.fetchone()

                return {
                    "connected": True,
                    "host": settings.db_host,
                    "port": settings.db_port,
                    "database": settings.db_name,
                    "version": version["version"] if version else "Unknown",
                    "error": None,
                }
    except Exception as e:
        return {
            "connected": False,
            "host": settings.db_host,
            "port": settings.db_port,
            "database": settings.db_name,
            "version": None,
            "error": str(e),
        }
