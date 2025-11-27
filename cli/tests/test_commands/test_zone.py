"""Tests for zone commands."""


class TestZoneList:
    """Tests for 'inv zone list' command."""

    def test_zone_list_help(self, runner, cli_app):
        """Test that zone list help displays correctly."""
        result = runner.invoke(cli_app, ["zone", "list", "--help"])
        assert result.exit_code == 0
        assert "--site" in result.stdout or "-s" in result.stdout


class TestZoneShow:
    """Tests for 'inv zone show' command."""

    def test_zone_show_help(self, runner, cli_app):
        """Test that zone show help displays correctly."""
        result = runner.invoke(cli_app, ["zone", "show", "--help"])
        assert result.exit_code == 0
        assert "SLUG" in result.stdout


class TestZoneCreate:
    """Tests for 'inv zone create' command."""

    def test_zone_create_help(self, runner, cli_app):
        """Test that zone create help displays correctly."""
        result = runner.invoke(cli_app, ["zone", "create", "--help"])
        assert result.exit_code == 0
        assert "--site" in result.stdout
        assert "--type" in result.stdout
        assert "--parent" in result.stdout


class TestZoneDelete:
    """Tests for 'inv zone delete' command."""

    def test_zone_delete_help(self, runner, cli_app):
        """Test that zone delete help displays correctly."""
        result = runner.invoke(cli_app, ["zone", "delete", "--help"])
        assert result.exit_code == 0
        assert "--yes" in result.stdout or "-y" in result.stdout


class TestZoneTypes:
    """Tests for 'inv zone types' command."""

    def test_zone_types_help(self, runner, cli_app):
        """Test that zone types help displays correctly."""
        result = runner.invoke(cli_app, ["zone", "types", "--help"])
        assert result.exit_code == 0
