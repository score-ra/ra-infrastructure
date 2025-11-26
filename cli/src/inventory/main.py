"""
Main CLI entry point for the inventory management tool.
"""

import typer
from rich.console import Console

from inventory import __version__
from inventory.commands import db, device, network, org, site

# Create main app
app = typer.Typer(
    name="inv",
    help="Device inventory and infrastructure management CLI",
    no_args_is_help=True,
    rich_markup_mode="rich",
)

# Console for rich output
console = Console()

# Register command groups
app.add_typer(org.app, name="org", help="Organization management")
app.add_typer(site.app, name="site", help="Site management")
app.add_typer(device.app, name="device", help="Device management")
app.add_typer(network.app, name="network", help="Network management")
app.add_typer(db.app, name="db", help="Database operations")


@app.command()
def version():
    """Show version information."""
    console.print(f"[bold]ra-inventory[/bold] v{__version__}")


@app.command()
def status():
    """Show system status and database connection."""
    from inventory.db.connection import get_connection_status

    status = get_connection_status()

    if status["connected"]:
        console.print("[green]✓[/green] Database connected")
        console.print(f"  Host: {status['host']}")
        console.print(f"  Database: {status['database']}")
        console.print(f"  Version: {status['version']}")
    else:
        console.print("[red]✗[/red] Database not connected")
        console.print(f"  Error: {status['error']}")


if __name__ == "__main__":
    app()
