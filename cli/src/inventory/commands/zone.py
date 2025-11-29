"""
Zone management commands.
"""

import typer
from rich.console import Console
from rich.table import Table

from inventory.db.connection import get_connection

app = typer.Typer(help="Zone management")
console = Console()


@app.command("list")
def list_zones(
    site: str = typer.Option(None, "--site", "-s", help="Filter by site slug"),
    zone_type: str = typer.Option(None, "--type", "-t", help="Filter by zone type"),
):
    """List zones."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            query = """
                SELECT
                    z.id, z.name, z.slug, z.zone_type, z.floor_number,
                    z.parent_zone_id, z.is_active,
                    s.name as site_name, s.slug as site_slug,
                    p.name as parent_name,
                    (SELECT COUNT(*) FROM devices d WHERE d.zone_id = z.id) as device_count
                FROM zones z
                JOIN sites s ON z.site_id = s.id
                LEFT JOIN zones p ON z.parent_zone_id = p.id
                WHERE z.is_active = TRUE
            """
            params = []

            if site:
                query += " AND s.slug = %s"
                params.append(site)

            if zone_type:
                query += " AND z.zone_type = %s"
                params.append(zone_type)

            query += " ORDER BY s.name, z.sort_order, z.name"

            cur.execute(query, params)
            rows = cur.fetchall()

    if not rows:
        console.print("[yellow]No zones found[/yellow]")
        return

    table = Table(title="Zones")
    table.add_column("Name", style="cyan")
    table.add_column("Slug")
    table.add_column("Type")
    table.add_column("Site")
    table.add_column("Parent")
    table.add_column("Floor")
    table.add_column("Devices", justify="right")

    for row in rows:
        table.add_row(
            row["name"],
            row["slug"],
            row["zone_type"] or "-",
            row["site_name"],
            row["parent_name"] or "-",
            str(row["floor_number"]) if row["floor_number"] is not None else "-",
            str(row["device_count"]),
        )

    console.print(table)


@app.command()
def show(slug: str = typer.Argument(..., help="Zone slug")):
    """Show zone details."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    z.*,
                    s.name as site_name,
                    p.name as parent_name
                FROM zones z
                JOIN sites s ON z.site_id = s.id
                LEFT JOIN zones p ON z.parent_zone_id = p.id
                WHERE z.slug = %s
            """,
                (slug,),
            )
            zone = cur.fetchone()

            if not zone:
                console.print(f"[red]Zone not found:[/red] {slug}")
                raise typer.Exit(1)

            # Get device count
            cur.execute(
                "SELECT COUNT(*) as count FROM devices WHERE zone_id = %s",
                (zone["id"],),
            )
            device_count = cur.fetchone()["count"]

            # Get child zones
            cur.execute(
                "SELECT name, slug FROM zones WHERE parent_zone_id = %s ORDER BY sort_order, name",
                (zone["id"],),
            )
            child_zones = cur.fetchall()

    console.print(f"\n[bold]{zone['name']}[/bold]")
    console.print(f"  Slug: {zone['slug']}")
    console.print(f"  Type: {zone['zone_type'] or 'Not set'}")
    console.print(f"  Site: {zone['site_name']}")
    console.print(f"  Parent: {zone['parent_name'] or 'None'}")

    if zone["floor_number"] is not None:
        console.print(f"  Floor: {zone['floor_number']}")

    if zone["area_sqft"]:
        console.print(f"  Area: {zone['area_sqft']} sq ft")

    console.print(f"\n  Devices: {device_count}")

    if child_zones:
        console.print(f"\n[bold]Child Zones ({len(child_zones)})[/bold]")
        for child in child_zones:
            console.print(f"  - {child['name']} ({child['slug']})")


@app.command()
def create(
    name: str = typer.Argument(..., help="Zone name"),
    site: str = typer.Option(..., "--site", "-s", help="Site slug"),
    zone_type: str = typer.Option(
        "room", "--type", "-t", help="Type: building, floor, room, closet, outdoor, garage, other"
    ),
    parent: str = typer.Option(None, "--parent", "-p", help="Parent zone slug"),
    floor: int = typer.Option(None, "--floor", "-f", help="Floor number"),
):
    """Create a new zone."""
    import re

    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")

    with get_connection() as conn:
        with conn.cursor() as cur:
            # Get site ID
            cur.execute("SELECT id FROM sites WHERE slug = %s", (site,))
            site_row = cur.fetchone()

            if not site_row:
                console.print(f"[red]Site not found:[/red] {site}")
                raise typer.Exit(1)

            # Get parent zone ID if provided
            parent_id = None
            if parent:
                cur.execute(
                    "SELECT id FROM zones WHERE slug = %s AND site_id = %s",
                    (parent, site_row["id"]),
                )
                parent_row = cur.fetchone()
                if parent_row:
                    parent_id = parent_row["id"]
                else:
                    console.print(
                        "[yellow]Warning: Parent zone not found, creating without parent[/yellow]"
                    )

            try:
                cur.execute(
                    """
                    INSERT INTO zones (site_id, parent_zone_id, name, slug, zone_type, floor_number)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id, slug
                """,
                    (site_row["id"], parent_id, name, slug, zone_type, floor),
                )
                result = cur.fetchone()
                conn.commit()

                console.print(f"[green][OK][/green] Created zone: {result['slug']}")

            except Exception as e:
                conn.rollback()
                console.print(f"[red]Error:[/red] {e}")
                raise typer.Exit(1)


@app.command()
def delete(
    slug: str = typer.Argument(..., help="Zone slug"),
    confirm: bool = typer.Option(False, "--yes", "-y", help="Skip confirmation"),
):
    """Delete a zone."""
    if not confirm:
        confirm = typer.confirm(
            f"Delete zone '{slug}'? Devices in this zone will become unassigned."
        )
        if not confirm:
            raise typer.Abort()

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM zones WHERE slug = %s RETURNING id", (slug,))
            result = cur.fetchone()

            if not result:
                console.print(f"[red]Zone not found:[/red] {slug}")
                raise typer.Exit(1)

            conn.commit()
            console.print(f"[green][OK][/green] Deleted zone: {slug}")


@app.command()
def types():
    """List zone type options."""
    types = [
        ("building", "Separate building on property"),
        ("floor", "Floor level within a building"),
        ("room", "Individual room"),
        ("closet", "Utility closet (server, storage)"),
        ("outdoor", "Outdoor area (yard, patio)"),
        ("garage", "Garage or workshop"),
        ("other", "Other zone type"),
    ]

    table = Table(title="Zone Types")
    table.add_column("Type", style="cyan")
    table.add_column("Description")

    for t, desc in types:
        table.add_row(t, desc)

    console.print(table)
