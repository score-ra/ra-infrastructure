"""
Site management commands.
"""

import typer
from rich.console import Console
from rich.table import Table

from inventory.db.connection import get_connection

app = typer.Typer(help="Site management")
console = Console()


@app.command("list")
def list_sites(
    org: str = typer.Option(None, "--org", "-o", help="Filter by organization slug"),
):
    """List all sites."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            if org:
                cur.execute(
                    """
                    SELECT s.*, o.name as org_name, o.slug as org_slug
                    FROM sites s
                    JOIN organizations o ON s.organization_id = o.id
                    WHERE o.slug = %s
                    ORDER BY s.name
                """,
                    (org,),
                )
            else:
                cur.execute("""
                    SELECT s.*, o.name as org_name, o.slug as org_slug
                    FROM sites s
                    JOIN organizations o ON s.organization_id = o.id
                    ORDER BY o.name, s.name
                """)
            rows = cur.fetchall()

    if not rows:
        console.print("[yellow]No sites found[/yellow]")
        return

    table = Table(title="Sites")
    table.add_column("Name", style="cyan")
    table.add_column("Slug")
    table.add_column("Organization")
    table.add_column("Type")
    table.add_column("Primary")
    table.add_column("City")

    for row in rows:
        table.add_row(
            row["name"],
            row["slug"],
            row["org_name"],
            row["site_type"] or "-",
            "Yes" if row["is_primary"] else "",
            row["city"] or "-",
        )

    console.print(table)


@app.command()
def show(slug: str = typer.Argument(..., help="Site slug")):
    """Show site details."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT s.*, o.name as org_name
                FROM sites s
                JOIN organizations o ON s.organization_id = o.id
                WHERE s.slug = %s
            """,
                (slug,),
            )
            site = cur.fetchone()

            if not site:
                console.print(f"[red]Site not found:[/red] {slug}")
                raise typer.Exit(1)

            # Get counts
            cur.execute(
                "SELECT COUNT(*) as count FROM zones WHERE site_id = %s",
                (site["id"],),
            )
            zone_count = cur.fetchone()["count"]

            cur.execute(
                "SELECT COUNT(*) as count FROM networks WHERE site_id = %s",
                (site["id"],),
            )
            network_count = cur.fetchone()["count"]

            cur.execute(
                "SELECT COUNT(*) as count FROM devices WHERE site_id = %s",
                (site["id"],),
            )
            device_count = cur.fetchone()["count"]

    console.print(f"\n[bold]{site['name']}[/bold]")
    console.print(f"  Slug: {site['slug']}")
    console.print(f"  Organization: {site['org_name']}")
    console.print(f"  Type: {site['site_type'] or 'Not set'}")
    console.print(f"  Primary: {'Yes' if site['is_primary'] else 'No'}")
    console.print(f"  Timezone: {site['timezone']}")

    if site["city"]:
        address_parts = [
            site["address_line1"],
            site["city"],
            site["state"],
            site["postal_code"],
        ]
        address = ", ".join(filter(None, address_parts))
        console.print(f"  Address: {address}")

    console.print(f"\n  Zones: {zone_count}")
    console.print(f"  Networks: {network_count}")
    console.print(f"  Devices: {device_count}")


@app.command()
def create(
    name: str = typer.Argument(..., help="Site name"),
    org: str = typer.Option(..., "--org", "-o", help="Organization slug"),
    site_type: str = typer.Option(
        "residence", "--type", "-t", help="Type: residence, office, datacenter, warehouse, other"
    ),
    city: str = typer.Option(None, "--city", help="City"),
    timezone: str = typer.Option("America/Los_Angeles", "--timezone", help="Timezone"),
    primary: bool = typer.Option(False, "--primary", "-p", help="Set as primary site"),
):
    """Create a new site."""
    import re

    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")

    with get_connection() as conn:
        with conn.cursor() as cur:
            # Get organization ID
            cur.execute("SELECT id FROM organizations WHERE slug = %s", (org,))
            org_row = cur.fetchone()

            if not org_row:
                console.print(f"[red]Organization not found:[/red] {org}")
                raise typer.Exit(1)

            try:
                cur.execute(
                    """
                    INSERT INTO sites (
                        organization_id, name, slug, site_type, city, timezone, is_primary
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING id, slug
                """,
                    (org_row["id"], name, slug, site_type, city, timezone, primary),
                )
                result = cur.fetchone()
                conn.commit()

                console.print(f"[green][OK][/green] Created site: {result['slug']}")

            except Exception as e:
                conn.rollback()
                console.print(f"[red]Error:[/red] {e}")
                raise typer.Exit(1)


@app.command()
def delete(
    slug: str = typer.Argument(..., help="Site slug"),
    confirm: bool = typer.Option(False, "--yes", "-y", help="Skip confirmation"),
):
    """Delete a site and all its data."""
    if not confirm:
        confirm = typer.confirm(
            f"Delete site '{slug}' and all its data (zones, devices, networks)?"
        )
        if not confirm:
            raise typer.Abort()

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM sites WHERE slug = %s RETURNING id", (slug,))
            result = cur.fetchone()

            if not result:
                console.print(f"[red]Site not found:[/red] {slug}")
                raise typer.Exit(1)

            conn.commit()
            console.print(f"[green][OK][/green] Deleted site: {slug}")
