"""
Database management commands.
"""


import typer
from rich.console import Console
from rich.table import Table

from inventory.config import get_settings
from inventory.db.connection import get_connection

app = typer.Typer(help="Database operations")
console = Console()


@app.command()
def migrate(
    dry_run: bool = typer.Option(False, "--dry-run", help="Show migrations without executing"),
):
    """Run database migrations."""
    settings = get_settings()
    migrations_path = settings.migrations_path

    if not migrations_path.exists():
        console.print(f"[red]Migrations path not found:[/red] {migrations_path}")
        raise typer.Exit(1)

    # Get migration files
    migration_files = sorted(migrations_path.glob("*.sql"))

    if not migration_files:
        console.print("[yellow]No migration files found[/yellow]")
        return

    console.print(f"[bold]Found {len(migration_files)} migration(s)[/bold]")

    if dry_run:
        for f in migration_files:
            console.print(f"  • {f.name}")
        return

    # Run migrations
    with get_connection() as conn:
        for migration_file in migration_files:
            console.print(f"Running: {migration_file.name}...", end=" ")
            try:
                sql = migration_file.read_text()
                with conn.cursor() as cur:
                    cur.execute(sql)
                conn.commit()
                console.print("[green][OK][/green]")
            except Exception as e:
                conn.rollback()
                console.print(f"[red][FAIL][/red] {e}")
                raise typer.Exit(1)

    console.print("[green]All migrations completed successfully[/green]")


@app.command()
def seed(
    file: str = typer.Option(None, "--file", "-f", help="Specific seed file to run"),
):
    """Seed database with initial data."""
    settings = get_settings()
    seeds_path = settings.seeds_path

    if not seeds_path.exists():
        console.print(f"[red]Seeds path not found:[/red] {seeds_path}")
        raise typer.Exit(1)

    # Get seed files
    if file:
        seed_files = [seeds_path / file]
        if not seed_files[0].exists():
            console.print(f"[red]Seed file not found:[/red] {file}")
            raise typer.Exit(1)
    else:
        seed_files = sorted(seeds_path.glob("*.sql"))

    if not seed_files:
        console.print("[yellow]No seed files found[/yellow]")
        return

    console.print(f"[bold]Running {len(seed_files)} seed file(s)[/bold]")

    with get_connection() as conn:
        for seed_file in seed_files:
            console.print(f"Seeding: {seed_file.name}...", end=" ")
            try:
                sql = seed_file.read_text()
                with conn.cursor() as cur:
                    cur.execute(sql)
                conn.commit()
                console.print("[green][OK][/green]")
            except Exception as e:
                conn.rollback()
                console.print(f"[red][FAIL][/red] {e}")
                raise typer.Exit(1)

    console.print("[green]Seeding completed successfully[/green]")


@app.command()
def reset(
    confirm: bool = typer.Option(False, "--yes", "-y", help="Skip confirmation"),
):
    """Reset database (drop all tables and re-run migrations)."""
    if not confirm:
        confirm = typer.confirm("This will delete ALL data. Are you sure?")
        if not confirm:
            raise typer.Abort()

    console.print("[yellow]Dropping all tables...[/yellow]")

    with get_connection() as conn:
        with conn.cursor() as cur:
            # Get all tables
            cur.execute("""
                SELECT tablename FROM pg_tables
                WHERE schemaname = 'public'
            """)
            tables = [row["tablename"] for row in cur.fetchall()]

            if tables:
                # Drop all tables
                cur.execute(f"DROP TABLE IF EXISTS {', '.join(tables)} CASCADE")
                conn.commit()
                console.print(f"Dropped {len(tables)} table(s)")
            else:
                console.print("No tables to drop")

    # Re-run migrations
    console.print("\n[bold]Re-running migrations...[/bold]")
    migrate(dry_run=False)


@app.command()
def tables():
    """List all database tables."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    tablename,
                    pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) as size
                FROM pg_tables
                WHERE schemaname = 'public'
                ORDER BY tablename
            """)
            rows = cur.fetchall()

    if not rows:
        console.print("[yellow]No tables found[/yellow]")
        return

    table = Table(title="Database Tables")
    table.add_column("Table", style="cyan")
    table.add_column("Size", justify="right")

    for row in rows:
        table.add_row(row["tablename"], row["size"])

    console.print(table)


@app.command()
def stats():
    """Show database statistics."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            # Count records in main tables
            stats = {}
            tables_to_count = [
                "organizations",
                "sites",
                "zones",
                "networks",
                "devices",
                "ip_allocations",
                "audit_log",
            ]

            for table in tables_to_count:
                try:
                    cur.execute(f"SELECT COUNT(*) as count FROM {table}")
                    result = cur.fetchone()
                    stats[table] = result["count"] if result else 0
                except Exception:
                    stats[table] = "N/A"

    table = Table(title="Database Statistics")
    table.add_column("Entity", style="cyan")
    table.add_column("Count", justify="right")

    for entity, count in stats.items():
        table.add_row(entity, str(count))

    console.print(table)
