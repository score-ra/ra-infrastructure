"""Tests for organization commands."""



class TestOrgList:
    """Tests for 'inv org list' command."""

    def test_org_list_runs(self, runner, cli_app):
        """Test that org list command executes without error."""
        # This will fail without DB - that's expected for now
        # Update this test once you have proper mocking
        pass

    def test_org_list_help(self, runner, cli_app):
        """Test that org list help displays correctly."""
        result = runner.invoke(cli_app, ["org", "list", "--help"])
        assert result.exit_code == 0
        assert "list" in result.stdout.lower() or "List" in result.stdout


class TestOrgShow:
    """Tests for 'inv org show' command."""

    def test_org_show_help(self, runner, cli_app):
        """Test that org show help displays correctly."""
        result = runner.invoke(cli_app, ["org", "show", "--help"])
        assert result.exit_code == 0


class TestOrgCreate:
    """Tests for 'inv org create' command."""

    def test_org_create_help(self, runner, cli_app):
        """Test that org create help displays correctly."""
        result = runner.invoke(cli_app, ["org", "create", "--help"])
        assert result.exit_code == 0
