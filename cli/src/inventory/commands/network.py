"""
Network management commands.
"""

import typer
from rich.console import Console
from rich.table import Table

from inventory.db.connection import get_connection

app = typer.Typer(help="Network management")
console = Console()


@app.command("list")
def list_networks(
    site: str = typer.Option(None, "--site", "-s", help="Filter by site slug"),
    network_type: str = typer.Option(None, "--type", "-t", help="Filter by network type"),
):
    """List networks."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            query = """
                SELECT
                    n.id, n.name, n.slug, n.network_type, n.cidr, n.ssid,
                    n.is_primary, n.is_active,
                    s.name as site_name, s.slug as site_slug,
                    (SELECT COUNT(*) FROM devices d WHERE d.network_id = n.id) as device_count
                FROM networks n
                JOIN sites s ON n.site_id = s.id
                WHERE n.is_active = TRUE
            """
            params = []

            if site:
                query += " AND s.slug = %s"
                params.append(site)

            if network_type:
                query += " AND n.network_type = %s"
                params.append(network_type)

            query += " ORDER BY s.name, n.name"

            cur.execute(query, params)
            rows = cur.fetchall()

    if not rows:
        console.print("[yellow]No networks found[/yellow]")
        return

    table = Table(title="Networks")
    table.add_column("Name", style="cyan")
    table.add_column("Type")
    table.add_column("CIDR/SSID")
    table.add_column("Site")
    table.add_column("Devices", justify="right")
    table.add_column("Primary")

    for row in rows:
        # Show CIDR for IP networks, SSID for WiFi
        identifier = row["cidr"] or row["ssid"] or "-"

        table.add_row(
            row["name"],
            row["network_type"],
            identifier,
            row["site_name"],
            str(row["device_count"]),
            "Yes" if row["is_primary"] else "",
        )

    console.print(table)


@app.command()
def show(slug: str = typer.Argument(..., help="Network slug")):
    """Show network details."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    n.*,
                    s.name as site_name,
                    d.name as controller_name
                FROM networks n
                JOIN sites s ON n.site_id = s.id
                LEFT JOIN devices d ON n.controller_device_id = d.id
                WHERE n.slug = %s
            """,
                (slug,),
            )
            network = cur.fetchone()

            if not network:
                console.print(f"[red]Network not found:[/red] {slug}")
                raise typer.Exit(1)

            # Get device count
            cur.execute(
                "SELECT COUNT(*) as count FROM devices WHERE network_id = %s",
                (network["id"],),
            )
            device_count = cur.fetchone()["count"]

            # Get IP allocation count
            cur.execute(
                "SELECT COUNT(*) as count FROM ip_allocations WHERE network_id = %s",
                (network["id"],),
            )
            ip_count = cur.fetchone()["count"]

    console.print(f"\n[bold]{network['name']}[/bold]")
    console.print(f"  Slug: {network['slug']}")
    console.print(f"  Type: {network['network_type']}")
    console.print(f"  Site: {network['site_name']}")
    console.print(f"  Primary: {'Yes' if network['is_primary'] else 'No'}")

    if network["cidr"]:
        console.print("\n[bold]IP Network[/bold]")
        console.print(f"  CIDR: {network['cidr']}")
        if network["gateway_ip"]:
            console.print(f"  Gateway: {network['gateway_ip']}")
        if network["vlan_id"]:
            console.print(f"  VLAN: {network['vlan_id']}")

    if network["ssid"]:
        console.print("\n[bold]WiFi[/bold]")
        console.print(f"  SSID: {network['ssid']}")
        if network["frequency"]:
            console.print(f"  Frequency: {network['frequency']}")
        if network["security_type"]:
            console.print(f"  Security: {network['security_type']}")

    if network["network_type"] in ["zwave", "zigbee"]:
        console.print("\n[bold]Mesh Network[/bold]")
        if network["controller_name"]:
            console.print(f"  Controller: {network['controller_name']}")
        if network["channel"]:
            console.print(f"  Channel: {network['channel']}")
        if network["pan_id"]:
            console.print(f"  PAN ID: {network['pan_id']}")

    console.print("\n[bold]Statistics[/bold]")
    console.print(f"  Devices: {device_count}")
    console.print(f"  IP Allocations: {ip_count}")


@app.command()
def types():
    """List network type options."""
    types = [
        ("ethernet", "Wired Ethernet network"),
        ("wifi", "Wireless WiFi network"),
        ("zwave", "Z-Wave mesh network"),
        ("zigbee", "Zigbee mesh network"),
        ("bluetooth", "Bluetooth network"),
        ("thread", "Thread mesh network"),
        ("matter", "Matter network"),
        ("other", "Other network type"),
    ]

    table = Table(title="Network Types")
    table.add_column("Type", style="cyan")
    table.add_column("Description")

    for t, desc in types:
        table.add_row(t, desc)

    console.print(table)


@app.command()
def ips(
    network: str = typer.Argument(..., help="Network slug"),
    available: bool = typer.Option(False, "--available", "-a", help="Show only available IPs"),
):
    """List IP allocations for a network."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            # Get network
            cur.execute("SELECT id, cidr FROM networks WHERE slug = %s", (network,))
            net = cur.fetchone()

            if not net:
                console.print(f"[red]Network not found:[/red] {network}")
                raise typer.Exit(1)

            if not net["cidr"]:
                console.print("[yellow]This network does not have IP addressing[/yellow]")
                return

            # Get allocations
            cur.execute(
                """
                SELECT
                    ip.ip_address, ip.allocation_type, ip.hostname,
                    ip.is_active, ip.last_seen,
                    d.name as device_name
                FROM ip_allocations ip
                LEFT JOIN devices d ON ip.device_id = d.id
                WHERE ip.network_id = %s
                ORDER BY ip.ip_address
            """,
                (net["id"],),
            )
            rows = cur.fetchall()

    if not rows:
        console.print("[yellow]No IP allocations found[/yellow]")
        return

    table = Table(title=f"IP Allocations - {network}")
    table.add_column("IP Address", style="cyan")
    table.add_column("Hostname")
    table.add_column("Device")
    table.add_column("Type")
    table.add_column("Active")

    for row in rows:
        table.add_row(
            str(row["ip_address"]),
            row["hostname"] or "-",
            row["device_name"] or "-",
            row["allocation_type"],
            "Yes" if row["is_active"] else "No",
        )

    console.print(table)


@app.command()
def create(
    name: str = typer.Argument(..., help="Network name"),
    network_type: str = typer.Option(
        ..., "--type", "-t", help="Type: ethernet, wifi, zwave, zigbee, bluetooth, etc."
    ),
    site: str = typer.Option(..., "--site", "-s", help="Site slug"),
    cidr: str = typer.Option(None, "--cidr", help="CIDR notation (e.g., 192.168.1.0/24)"),
    gateway: str = typer.Option(None, "--gateway", "-g", help="Gateway IP address"),
    vlan: int = typer.Option(None, "--vlan", help="VLAN ID"),
    ssid: str = typer.Option(None, "--ssid", help="WiFi SSID"),
    frequency: str = typer.Option(None, "--frequency", help="WiFi frequency: 2.4GHz, 5GHz"),
    security: str = typer.Option(None, "--security", help="Security type: WPA2, WPA3, WEP, Open"),
    channel: int = typer.Option(None, "--channel", help="Channel for mesh networks"),
    primary: bool = typer.Option(False, "--primary", "-p", help="Set as primary network"),
):
    """Create a new network."""
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

            try:
                cur.execute(
                    """
                    INSERT INTO networks (
                        site_id, name, slug, network_type,
                        cidr, gateway_ip, vlan_id,
                        ssid, frequency, security_type,
                        channel, is_primary
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id, slug
                """,
                    (
                        site_row["id"],
                        name,
                        slug,
                        network_type,
                        cidr,
                        gateway,
                        vlan,
                        ssid,
                        frequency,
                        security,
                        channel,
                        primary,
                    ),
                )
                result = cur.fetchone()
                conn.commit()

                console.print(f"[green][OK][/green] Created network: {result['slug']}")

            except Exception as e:
                conn.rollback()
                console.print(f"[red]Error:[/red] {e}")
                raise typer.Exit(1)


@app.command()
def delete(
    slug: str = typer.Argument(..., help="Network slug"),
    confirm: bool = typer.Option(False, "--yes", "-y", help="Skip confirmation"),
):
    """Delete a network."""
    if not confirm:
        confirm = typer.confirm(
            f"Delete network '{slug}'? Devices on this network will become unassigned."
        )
        if not confirm:
            raise typer.Abort()

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM networks WHERE slug = %s RETURNING id", (slug,))
            result = cur.fetchone()

            if not result:
                console.print(f"[red]Network not found:[/red] {slug}")
                raise typer.Exit(1)

            conn.commit()
            console.print(f"[green][OK][/green] Deleted network: {slug}")
