"""
Device management commands.
"""

from typing import Optional

import typer
from rich.console import Console
from rich.table import Table

from inventory.db.connection import get_connection

app = typer.Typer(help="Device management")
console = Console()


@app.command("list")
def list_devices(
    site: str = typer.Option(None, "--site", "-s", help="Filter by site slug"),
    zone: str = typer.Option(None, "--zone", "-z", help="Filter by zone slug"),
    category: str = typer.Option(None, "--category", "-c", help="Filter by category slug"),
    status: str = typer.Option(None, "--status", help="Filter by status"),
    limit: int = typer.Option(50, "--limit", "-l", help="Maximum number of results"),
):
    """List devices."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            query = """
                SELECT
                    d.id, d.name, d.slug, d.device_type, d.status,
                    d.manufacturer, d.model, d.ip_address,
                    s.name as site_name, s.slug as site_slug,
                    z.name as zone_name,
                    c.name as category_name
                FROM devices d
                JOIN sites s ON d.site_id = s.id
                LEFT JOIN zones z ON d.zone_id = z.id
                LEFT JOIN device_categories c ON d.category_id = c.id
                WHERE d.is_active = TRUE
            """
            params = []

            if site:
                query += " AND s.slug = %s"
                params.append(site)

            if zone:
                query += " AND z.slug = %s"
                params.append(zone)

            if category:
                query += " AND c.slug = %s"
                params.append(category)

            if status:
                query += " AND d.status = %s"
                params.append(status)

            query += " ORDER BY d.name LIMIT %s"
            params.append(limit)

            cur.execute(query, params)
            rows = cur.fetchall()

    if not rows:
        console.print("[yellow]No devices found[/yellow]")
        return

    table = Table(title=f"Devices ({len(rows)} shown)")
    table.add_column("Name", style="cyan")
    table.add_column("Type")
    table.add_column("Zone")
    table.add_column("Status")
    table.add_column("IP")
    table.add_column("Manufacturer")

    for row in rows:
        status_color = {
            "online": "green",
            "offline": "red",
            "unknown": "yellow",
            "maintenance": "blue",
        }.get(row["status"], "white")

        table.add_row(
            row["name"],
            row["device_type"],
            row["zone_name"] or "-",
            f"[{status_color}]{row['status']}[/{status_color}]",
            str(row["ip_address"]) if row["ip_address"] else "-",
            row["manufacturer"] or "-",
        )

    console.print(table)


@app.command()
def show(slug: str = typer.Argument(..., help="Device slug")):
    """Show device details."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    d.*,
                    s.name as site_name,
                    z.name as zone_name,
                    n.name as network_name,
                    c.name as category_name
                FROM devices d
                JOIN sites s ON d.site_id = s.id
                LEFT JOIN zones z ON d.zone_id = z.id
                LEFT JOIN networks n ON d.network_id = n.id
                LEFT JOIN device_categories c ON d.category_id = c.id
                WHERE d.slug = %s
            """,
                (slug,),
            )
            device = cur.fetchone()

            if not device:
                console.print(f"[red]Device not found:[/red] {slug}")
                raise typer.Exit(1)

    console.print(f"\n[bold]{device['name']}[/bold]")
    console.print(f"  Slug: {device['slug']}")
    console.print(f"  Type: {device['device_type']}")
    console.print(f"  Category: {device['category_name'] or 'Not set'}")
    console.print(f"  Status: {device['status']}")

    console.print("\n[bold]Location[/bold]")
    console.print(f"  Site: {device['site_name']}")
    console.print(f"  Zone: {device['zone_name'] or 'Not assigned'}")
    console.print(f"  Network: {device['network_name'] or 'Not assigned'}")

    if device["manufacturer"] or device["model"]:
        console.print("\n[bold]Hardware[/bold]")
        if device["manufacturer"]:
            console.print(f"  Manufacturer: {device['manufacturer']}")
        if device["model"]:
            console.print(f"  Model: {device['model']}")
        if device["serial_number"]:
            console.print(f"  Serial: {device['serial_number']}")
        if device["firmware_version"]:
            console.print(f"  Firmware: {device['firmware_version']}")

    if device["mac_address"] or device["ip_address"]:
        console.print("\n[bold]Network[/bold]")
        if device["mac_address"]:
            console.print(f"  MAC: {device['mac_address']}")
        if device["ip_address"]:
            console.print(f"  IP: {device['ip_address']}")
        if device["hostname"]:
            console.print(f"  Hostname: {device['hostname']}")

    if device["zwave_node_id"] or device["zigbee_ieee_address"]:
        console.print("\n[bold]Protocol IDs[/bold]")
        if device["zwave_node_id"]:
            console.print(f"  Z-Wave Node: {device['zwave_node_id']}")
        if device["zigbee_ieee_address"]:
            console.print(f"  Zigbee IEEE: {device['zigbee_ieee_address']}")

    if device["homeseer_ref"]:
        console.print("\n[bold]Integrations[/bold]")
        console.print(f"  HomeSeer: {device['homeseer_ref']}")


@app.command()
def create(
    name: str = typer.Argument(..., help="Device name"),
    device_type: str = typer.Option(..., "--type", "-t", help="Device type"),
    site: str = typer.Option(..., "--site", "-s", help="Site slug"),
    zone: Optional[str] = typer.Option(None, "--zone", "-z", help="Zone slug"),
    category: Optional[str] = typer.Option(None, "--category", "-c", help="Category slug"),
    manufacturer: Optional[str] = typer.Option(None, "--manufacturer", "-m", help="Manufacturer"),
    model: Optional[str] = typer.Option(None, "--model", help="Model"),
    ip: Optional[str] = typer.Option(None, "--ip", help="IP address"),
    mac: Optional[str] = typer.Option(None, "--mac", help="MAC address"),
):
    """Create a new device."""
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

            # Get zone ID if provided
            zone_id = None
            if zone:
                cur.execute(
                    "SELECT id FROM zones WHERE slug = %s AND site_id = %s",
                    (zone, site_row["id"]),
                )
                zone_row = cur.fetchone()
                if zone_row:
                    zone_id = zone_row["id"]

            # Get category ID if provided
            category_id = None
            if category:
                cur.execute("SELECT id FROM device_categories WHERE slug = %s", (category,))
                cat_row = cur.fetchone()
                if cat_row:
                    category_id = cat_row["id"]

            try:
                cur.execute(
                    """
                    INSERT INTO devices (
                        site_id, zone_id, category_id, name, slug, device_type,
                        manufacturer, model, ip_address, mac_address
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id, slug
                """,
                    (
                        site_row["id"],
                        zone_id,
                        category_id,
                        name,
                        slug,
                        device_type,
                        manufacturer,
                        model,
                        ip,
                        mac,
                    ),
                )
                result = cur.fetchone()
                conn.commit()

                console.print(f"[green][OK][/green] Created device: {result['slug']}")

            except Exception as e:
                conn.rollback()
                console.print(f"[red]Error:[/red] {e}")
                raise typer.Exit(1)


@app.command()
def count(
    site: str = typer.Option(None, "--site", "-s", help="Filter by site slug"),
    by: str = typer.Option(
        "category", "--by", "-b", help="Group by: category, type, zone, status"
    ),
):
    """Count devices by category, type, zone, or status."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            group_column = {
                "category": "c.name",
                "type": "d.device_type",
                "zone": "z.name",
                "status": "d.status",
            }.get(by, "c.name")

            query = f"""
                SELECT
                    COALESCE({group_column}, 'Unassigned') as group_name,
                    COUNT(*) as count
                FROM devices d
                JOIN sites s ON d.site_id = s.id
                LEFT JOIN zones z ON d.zone_id = z.id
                LEFT JOIN device_categories c ON d.category_id = c.id
                WHERE d.is_active = TRUE
            """

            params = []
            if site:
                query += " AND s.slug = %s"
                params.append(site)

            query += f" GROUP BY {group_column} ORDER BY count DESC"

            cur.execute(query, params)
            rows = cur.fetchall()

    if not rows:
        console.print("[yellow]No devices found[/yellow]")
        return

    table = Table(title=f"Devices by {by.title()}")
    table.add_column(by.title(), style="cyan")
    table.add_column("Count", justify="right")

    total = 0
    for row in rows:
        table.add_row(row["group_name"], str(row["count"]))
        total += row["count"]

    table.add_row("[bold]Total[/bold]", f"[bold]{total}[/bold]")

    console.print(table)


@app.command()
def update(
    slug: str = typer.Argument(..., help="Device slug"),
    name: Optional[str] = typer.Option(None, "--name", "-n", help="New name"),
    zone: Optional[str] = typer.Option(None, "--zone", "-z", help="New zone slug"),
    status: Optional[str] = typer.Option(
        None, "--status", help="Status: online, offline, unknown, maintenance"
    ),
    ip: Optional[str] = typer.Option(None, "--ip", help="IP address"),
    mac: Optional[str] = typer.Option(None, "--mac", help="MAC address"),
    manufacturer: Optional[str] = typer.Option(None, "--manufacturer", "-m", help="Manufacturer"),
    model: Optional[str] = typer.Option(None, "--model", help="Model"),
    serial: Optional[str] = typer.Option(None, "--serial", help="Serial number"),
    firmware: Optional[str] = typer.Option(None, "--firmware", help="Firmware version"),
):
    """Update a device."""
    # Build update fields
    updates = {}
    if name is not None:
        updates["name"] = name
    if status is not None:
        updates["status"] = status
    if ip is not None:
        updates["ip_address"] = ip if ip else None
    if mac is not None:
        updates["mac_address"] = mac if mac else None
    if manufacturer is not None:
        updates["manufacturer"] = manufacturer if manufacturer else None
    if model is not None:
        updates["model"] = model if model else None
    if serial is not None:
        updates["serial_number"] = serial if serial else None
    if firmware is not None:
        updates["firmware_version"] = firmware if firmware else None

    if not updates and zone is None:
        console.print("[yellow]No updates specified[/yellow]")
        raise typer.Exit(1)

    with get_connection() as conn:
        with conn.cursor() as cur:
            # Get device
            cur.execute("SELECT id, site_id FROM devices WHERE slug = %s", (slug,))
            device = cur.fetchone()

            if not device:
                console.print(f"[red]Device not found:[/red] {slug}")
                raise typer.Exit(1)

            # Handle zone update
            if zone is not None:
                if zone:
                    cur.execute(
                        "SELECT id FROM zones WHERE slug = %s AND site_id = %s",
                        (zone, device["site_id"]),
                    )
                    zone_row = cur.fetchone()
                    if zone_row:
                        updates["zone_id"] = zone_row["id"]
                    else:
                        console.print(
                            "[yellow]Warning: Zone not found, skipping zone update[/yellow]"
                        )
                else:
                    updates["zone_id"] = None

            if not updates:
                console.print("[yellow]No valid updates to apply[/yellow]")
                raise typer.Exit(1)

            # Build SQL
            set_clause = ", ".join(f"{k} = %s" for k in updates.keys())
            values = list(updates.values()) + [slug]

            try:
                cur.execute(
                    f"UPDATE devices SET {set_clause} WHERE slug = %s RETURNING slug",
                    values,
                )
                conn.commit()
                console.print(f"[green][OK][/green] Updated device: {slug}")

            except Exception as e:
                conn.rollback()
                console.print(f"[red]Error:[/red] {e}")
                raise typer.Exit(1)


@app.command()
def delete(
    slug: str = typer.Argument(..., help="Device slug"),
    confirm: bool = typer.Option(False, "--yes", "-y", help="Skip confirmation"),
):
    """Delete a device."""
    if not confirm:
        confirm = typer.confirm(f"Delete device '{slug}'?")
        if not confirm:
            raise typer.Abort()

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM devices WHERE slug = %s RETURNING id", (slug,))
            result = cur.fetchone()

            if not result:
                console.print(f"[red]Device not found:[/red] {slug}")
                raise typer.Exit(1)

            conn.commit()
            console.print(f"[green][OK][/green] Deleted device: {slug}")
