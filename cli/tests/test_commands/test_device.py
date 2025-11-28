"""Tests for device commands."""


class TestDeviceList:
    """Tests for 'inv device list' command."""

    def test_device_list_help(self, runner, cli_app):
        """Test that device list help displays correctly."""
        result = runner.invoke(cli_app, ["device", "list", "--help"])
        assert result.exit_code == 0
        assert "--site" in result.stdout or "-s" in result.stdout
        assert "--zone" in result.stdout or "-z" in result.stdout

    def test_device_list_has_usage_status_option(self, runner, cli_app):
        """Test that device list has --usage-status option."""
        result = runner.invoke(cli_app, ["device", "list", "--help"])
        assert result.exit_code == 0
        assert "--usage-status" in result.stdout or "-u" in result.stdout


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

    def test_device_count_supports_usage_grouping(self, runner, cli_app):
        """Test that device count supports grouping by usage."""
        result = runner.invoke(cli_app, ["device", "count", "--help"])
        assert result.exit_code == 0
        assert "usage" in result.stdout


# ============================================================================
# Usage Status Commands
# ============================================================================


class TestDeviceStore:
    """Tests for 'inv device store' command."""

    def test_device_store_help(self, runner, cli_app):
        """Test that device store help displays correctly."""
        result = runner.invoke(cli_app, ["device", "store", "--help"])
        assert result.exit_code == 0
        assert "SLUG" in result.stdout
        assert "--location" in result.stdout or "-l" in result.stdout


class TestDeviceActivate:
    """Tests for 'inv device activate' command."""

    def test_device_activate_help(self, runner, cli_app):
        """Test that device activate help displays correctly."""
        result = runner.invoke(cli_app, ["device", "activate", "--help"])
        assert result.exit_code == 0
        assert "SLUG" in result.stdout


class TestDeviceFail:
    """Tests for 'inv device fail' command."""

    def test_device_fail_help(self, runner, cli_app):
        """Test that device fail help displays correctly."""
        result = runner.invoke(cli_app, ["device", "fail", "--help"])
        assert result.exit_code == 0
        assert "SLUG" in result.stdout
        assert "--reason" in result.stdout or "-r" in result.stdout
        assert "--rma" in result.stdout


class TestDeviceRetire:
    """Tests for 'inv device retire' command."""

    def test_device_retire_help(self, runner, cli_app):
        """Test that device retire help displays correctly."""
        result = runner.invoke(cli_app, ["device", "retire", "--help"])
        assert result.exit_code == 0
        assert "SLUG" in result.stdout
        assert "--yes" in result.stdout or "-y" in result.stdout


class TestDevicePending:
    """Tests for 'inv device pending' command."""

    def test_device_pending_help(self, runner, cli_app):
        """Test that device pending help displays correctly."""
        result = runner.invoke(cli_app, ["device", "pending", "--help"])
        assert result.exit_code == 0
        assert "SLUG" in result.stdout
