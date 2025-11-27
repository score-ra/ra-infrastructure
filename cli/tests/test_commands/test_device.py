"""Tests for device commands."""


class TestDeviceList:
    """Tests for 'inv device list' command."""

    def test_device_list_help(self, runner, cli_app):
        """Test that device list help displays correctly."""
        result = runner.invoke(cli_app, ["device", "list", "--help"])
        assert result.exit_code == 0
        assert "--site" in result.stdout or "-s" in result.stdout
        assert "--zone" in result.stdout or "-z" in result.stdout


class TestDeviceShow:
    """Tests for 'inv device show' command."""

    def test_device_show_help(self, runner, cli_app):
        """Test that device show help displays correctly."""
        result = runner.invoke(cli_app, ["device", "show", "--help"])
        assert result.exit_code == 0
        assert "SLUG" in result.stdout


class TestDeviceCreate:
    """Tests for 'inv device create' command."""

    def test_device_create_help(self, runner, cli_app):
        """Test that device create help displays correctly."""
        result = runner.invoke(cli_app, ["device", "create", "--help"])
        assert result.exit_code == 0
        assert "--type" in result.stdout
        assert "--site" in result.stdout


class TestDeviceUpdate:
    """Tests for 'inv device update' command."""

    def test_device_update_help(self, runner, cli_app):
        """Test that device update help displays correctly."""
        result = runner.invoke(cli_app, ["device", "update", "--help"])
        assert result.exit_code == 0
        assert "--name" in result.stdout
        assert "--status" in result.stdout


class TestDeviceDelete:
    """Tests for 'inv device delete' command."""

    def test_device_delete_help(self, runner, cli_app):
        """Test that device delete help displays correctly."""
        result = runner.invoke(cli_app, ["device", "delete", "--help"])
        assert result.exit_code == 0
        assert "--yes" in result.stdout or "-y" in result.stdout


class TestDeviceCount:
    """Tests for 'inv device count' command."""

    def test_device_count_help(self, runner, cli_app):
        """Test that device count help displays correctly."""
        result = runner.invoke(cli_app, ["device", "count", "--help"])
        assert result.exit_code == 0
        assert "--by" in result.stdout
