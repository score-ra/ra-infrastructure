"""Tests for site commands."""


class TestSiteList:
    """Tests for 'inv site list' command."""

    def test_site_list_help(self, runner, cli_app):
        """Test that site list help displays correctly."""
        result = runner.invoke(cli_app, ["site", "list", "--help"])
        assert result.exit_code == 0
        assert "--org" in result.stdout or "-o" in result.stdout


class TestSiteShow:
    """Tests for 'inv site show' command."""

    def test_site_show_help(self, runner, cli_app):
        """Test that site show help displays correctly."""
        result = runner.invoke(cli_app, ["site", "show", "--help"])
        assert result.exit_code == 0
        assert "SLUG" in result.stdout


class TestSiteCreate:
    """Tests for 'inv site create' command."""

    def test_site_create_help(self, runner, cli_app):
        """Test that site create help displays correctly."""
        result = runner.invoke(cli_app, ["site", "create", "--help"])
        assert result.exit_code == 0
        assert "--org" in result.stdout
        assert "--type" in result.stdout


class TestSiteDelete:
    """Tests for 'inv site delete' command."""

    def test_site_delete_help(self, runner, cli_app):
        """Test that site delete help displays correctly."""
        result = runner.invoke(cli_app, ["site", "delete", "--help"])
        assert result.exit_code == 0
        assert "--yes" in result.stdout or "-y" in result.stdout
