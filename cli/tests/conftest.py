"""Pytest fixtures for ra-inventory CLI tests."""

import pytest
from typer.testing import CliRunner

from inventory.main import app


@pytest.fixture
def runner():
    """Create a CLI test runner."""
    return CliRunner()


@pytest.fixture
def cli_app():
    """Return the Typer app for testing."""
    return app


@pytest.fixture
def mock_db_connection(mocker):
    """Mock database connection for unit tests."""
    mock_conn = mocker.MagicMock()
    mock_cursor = mocker.MagicMock()
    mock_conn.__enter__ = mocker.MagicMock(return_value=mock_conn)
    mock_conn.__exit__ = mocker.MagicMock(return_value=False)
    mock_conn.cursor.return_value.__enter__ = mocker.MagicMock(return_value=mock_cursor)
    mock_conn.cursor.return_value.__exit__ = mocker.MagicMock(return_value=False)
    return mock_conn, mock_cursor
