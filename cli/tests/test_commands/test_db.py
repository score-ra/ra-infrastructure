"""Tests for database commands."""

import pytest


class TestDbMigrate:
    """Tests for 'inv db migrate' command."""

    def test_db_migrate_help(self, runner, cli_app):
        """Test that db migrate help displays correctly."""
        result = runner.invoke(cli_app, ["db", "migrate", "--help"])
        assert result.exit_code == 0


class TestDbStats:
    """Tests for 'inv db stats' command."""

    def test_db_stats_help(self, runner, cli_app):
        """Test that db stats help displays correctly."""
        result = runner.invoke(cli_app, ["db", "stats", "--help"])
        assert result.exit_code == 0


class TestDbTables:
    """Tests for 'inv db tables' command."""

    def test_db_tables_help(self, runner, cli_app):
        """Test that db tables help displays correctly."""
        result = runner.invoke(cli_app, ["db", "tables", "--help"])
        assert result.exit_code == 0
