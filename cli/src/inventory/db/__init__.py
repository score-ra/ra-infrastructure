"""
Database access layer.
"""

from inventory.db.connection import get_connection, get_connection_status

__all__ = ["get_connection", "get_connection_status"]
