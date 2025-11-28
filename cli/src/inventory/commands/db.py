"""
Database management commands.
"""

import subprocess
import sys
from pathlib import Path

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


@app.command()
def schema(
    output: str = typer.Option(
        "docs/schema", "--output", "-o", help="Output path (without extension)"
    ),
    format: str = typer.Option(
        "png", "--format", "-f", help="Output format: png, svg, pdf, or html"
    ),
):
    """Generate schema diagram from live database using SchemaSpy.

    Requires Docker to be running. Generates an ER diagram directly from
    the database, ensuring the diagram always matches the actual schema.

    Examples:
        inv db schema                      # Generate PNG to docs/schema.png
        inv db schema -f svg               # Generate SVG
        inv db schema -o my-schema -f pdf  # Generate PDF to my-schema.pdf
        inv db schema -f html              # Generate full HTML documentation
    """
    settings = get_settings()

    # Determine output path
    output_path = Path(output)
    if not output_path.is_absolute():
        # Relative to project root
        output_path = settings.project_root / output

    # For HTML, output is a directory; for others, it's a file
    if format == "html":
        output_dir = output_path
        output_file = output_dir / "index.html"
    else:
        output_dir = output_path.parent
        output_file = output_path.with_suffix(f".{format}")

    # Ensure output directory exists
    output_dir.mkdir(parents=True, exist_ok=True)

    console.print(f"[bold]Generating schema diagram...[/bold]")
    console.print(f"  Output: {output_file}")
    console.print(f"  Format: {format}")

    # Check if Docker is available
    try:
        subprocess.run(
            ["docker", "info"],
            capture_output=True,
            check=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        console.print("[red]Error: Docker is not running or not installed[/red]")
        console.print("Please start Docker and try again.")
        raise typer.Exit(1)

    # Use SchemaSpy Docker image to generate diagram
    # SchemaSpy generates HTML documentation with ER diagrams
    # Use Docker network to connect to inventory-db container (works on Windows/Mac/Linux)
    # Note: SchemaSpy image has default -o /output, so we just mount our dir there
    docker_cmd = [
        "docker",
        "run",
        "--rm",
        "--network=inventory_network",  # Connect to same network as database
        "-v",
        f"{output_dir}:/output",
        "schemaspy/schemaspy:latest",
        "-t",
        "pgsql",
        "-host",
        "inventory-db",  # Container name on the Docker network
        "-port",
        "5432",
        "-db",
        settings.db_name,
        "-u",
        settings.db_user,
        "-p",
        settings.db_password,
        "-s",
        "public",
    ]

    # For non-HTML formats, we generate HTML then extract the diagram
    console.print("[dim]Running SchemaSpy via Docker...[/dim]")

    try:
        result = subprocess.run(
            docker_cmd,
            capture_output=True,
            text=True,
            timeout=120,  # 2 minute timeout
        )

        if result.returncode != 0:
            console.print(f"[red]SchemaSpy failed:[/red]")
            console.print(result.stderr)
            raise typer.Exit(1)

        # SchemaSpy generates diagrams in diagrams/ subdirectory
        diagrams_dir = output_dir / "diagrams"
        summary_diagram = diagrams_dir / "summary" / "relationships.real.large.png"

        if format == "html":
            console.print(f"[green]HTML documentation generated at:[/green] {output_dir}")
            console.print(f"  Open {output_dir}/index.html in a browser")
        elif format == "png":
            # Copy the main diagram to the requested output location
            if summary_diagram.exists():
                import shutil

                shutil.copy(summary_diagram, output_file)
                console.print(f"[green]Schema diagram saved to:[/green] {output_file}")
            else:
                # Fallback to the compact diagram
                compact_diagram = diagrams_dir / "summary" / "relationships.real.compact.png"
                if compact_diagram.exists():
                    import shutil

                    shutil.copy(compact_diagram, output_file)
                    console.print(f"[green]Schema diagram saved to:[/green] {output_file}")
                else:
                    console.print("[yellow]Diagram generated but not found at expected path[/yellow]")
                    console.print(f"Check {diagrams_dir} for available diagrams")
        elif format in ("svg", "pdf"):
            console.print(f"[yellow]SchemaSpy generates PNG by default.[/yellow]")
            console.print(f"HTML output includes SVG diagrams at: {diagrams_dir}")
            # Still save the PNG
            if summary_diagram.exists():
                import shutil

                png_output = output_path.with_suffix(".png")
                shutil.copy(summary_diagram, png_output)
                console.print(f"[green]PNG diagram saved to:[/green] {png_output}")

    except subprocess.TimeoutExpired:
        console.print("[red]SchemaSpy timed out after 2 minutes[/red]")
        raise typer.Exit(1)
    except Exception as e:
        console.print(f"[red]Error running SchemaSpy:[/red] {e}")
        raise typer.Exit(1)
