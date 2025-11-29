"""Tests for network commands."""


class TestNetworkList:
    """Tests for 'inv network list' command."""

    def test_network_list_help(self, runner, cli_app):
        """Test that network list help displays correctly."""
        result = runner.invoke(cli_app, ["network", "list", "--help"])
        assert result.exit_code == 0
        assert "--site" in result.stdout or "-s" in result.stdout


class TestNetworkShow:
    """Tests for 'inv network show' command."""

    def test_network_show_help(self, runner, cli_app):
        """Test that network show help displays correctly."""
        result = runner.invoke(cli_app, ["network", "show", "--help"])
        assert result.exit_code == 0
        assert "SLUG" in result.stdout


class TestNetworkCreate:
    """Tests for 'inv network create' command."""

    def test_network_create_help(self, runner, cli_app):
        """Test that network create help displays correctly."""
        result = runner.invoke(cli_app, ["network", "create", "--help"])
        assert result.exit_code == 0
        assert "--type" in result.stdout
        assert "--site" in result.stdout


class TestNetworkDelete:
    """Tests for 'inv network delete' command."""

    def test_network_delete_help(self, runner, cli_app):
        """Test that network delete help displays correctly."""
        result = runner.invoke(cli_app, ["network", "delete", "--help"])
        assert result.exit_code == 0
        assert "--yes" in result.stdout or "-y" in result.stdout


class TestNetworkTypes:
    """Tests for 'inv network types' command."""

    def test_network_types_help(self, runner, cli_app):
        """Test that network types help displays correctly."""
        result = runner.invoke(cli_app, ["network", "types", "--help"])
        assert result.exit_code == 0


class TestNetworkIps:
    """Tests for 'inv network ips' command."""

    def test_network_ips_help(self, runner, cli_app):
        """Test that network ips help displays correctly."""
        result = runner.invoke(cli_app, ["network", "ips", "--help"])
        assert result.exit_code == 0
        assert "NETWORK" in result.stdout
