"""
Organization management commands.
"""

import typer
from rich.console import Console
from rich.table import Table

from inventory.db.connection import get_connection

app = typer.Typer(help="Organization management")
console = Console()


@app.command("list")
def list_orgs():
    """List all organizations."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, name, slug, type, is_active, created_at
                FROM organizations
                ORDER BY name
            """)
            rows = cur.fetchall()

    if not rows:
        console.print("[yellow]No organizations found[/yellow]")
        return

    table = Table(title="Organizations")
    table.add_column("Name", style="cyan")
    table.add_column("Slug")
    table.add_column("Type")
    table.add_column("Active")
    table.add_column("Created")

    for row in rows:
        table.add_row(
            row["name"],
            row["slug"],
            row["type"],
            "Yes" if row["is_active"] else "No",
            row["created_at"].strftime("%Y-%m-%d"),
        )

    console.print(table)


@app.command()
def show(slug: str = typer.Argument(..., help="Organization slug")):
    """Show organization details."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT * FROM organizations WHERE slug = %s
            """,
                (slug,),
            )
            org = cur.fetchone()

            if not org:
                console.print(f"[red]Organization not found:[/red] {slug}")
                raise typer.Exit(1)

            # Get site count
            cur.execute(
                """
                SELECT COUNT(*) as count FROM sites WHERE organization_id = %s
            """,
                (org["id"],),
            )
            site_count = cur.fetchone()["count"]

    console.print(f"\n[bold]{org['name']}[/bold]")
    console.print(f"  Slug: {org['slug']}")
    console.print(f"  Type: {org['type']}")
    console.print(f"  Active: {'Yes' if org['is_active'] else 'No'}")
    console.print(f"  Sites: {site_count}")
    console.print(f"  Created: {org['created_at'].strftime('%Y-%m-%d %H:%M:%S')}")

    if org["description"]:
        console.print(f"  Description: {org['description']}")


@app.command()
def create(
    name: str = typer.Argument(..., help="Organization name"),
    org_type: str = typer.Option("home", "--type", "-t", help="Type: home, business, lab, other"),
    description: str = typer.Option(None, "--description", "-d", help="Description"),
):
    """Create a new organization."""
    import re

    # Generate slug from name
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")

    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                cur.execute(
                    """
                    INSERT INTO organizations (name, slug, type, description)
                    VALUES (%s, %s, %s, %s)
                    RETURNING id, slug
                """,
                    (name, slug, org_type, description),
                )
                result = cur.fetchone()
                conn.commit()

                console.print(f"[green][OK][/green] Created organization: {result['slug']}")

            except Exception as e:
                conn.rollback()
                console.print(f"[red]Error:[/red] {e}")
                raise typer.Exit(1)


@app.command()
def delete(
    slug: str = typer.Argument(..., help="Organization slug"),
    confirm: bool = typer.Option(False, "--yes", "-y", help="Skip confirmation"),
):
    """Delete an organization."""
    if not confirm:
        confirm = typer.confirm(f"Delete organization '{slug}' and all its data?")
        if not confirm:
            raise typer.Abort()

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM organizations WHERE slug = %s RETURNING id", (slug,))
            result = cur.fetchone()

            if not result:
                console.print(f"[red]Organization not found:[/red] {slug}")
                raise typer.Exit(1)

            conn.commit()
            console.print(f"[green][OK][/green] Deleted organization: {slug}")
