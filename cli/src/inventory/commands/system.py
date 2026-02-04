"""
System-wide health check commands for ra-infrastructure.

This module provides comprehensive health checks for all infrastructure services
that ra-infrastructure is responsible for, including databases, Docker services,
Cloudflare tunnel endpoints, and the Selfwize dashboard.
"""

import subprocess
import time
from typing import List, Tuple
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import typer
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

from inventory.config import get_infra_config
from inventory.db.connection import get_connection

app = typer.Typer(help="System health checks and monitoring")
console = Console()


def _check_docker_daemon() -> Tuple[bool, str]:
    """Check if Docker daemon is responsive."""
    try:
        result = subprocess.run(
            ["docker", "info"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode == 0:
            return True, "daemon responsive"
        return False, "command failed"
    except subprocess.TimeoutExpired:
        return False, "daemon timeout"
    except FileNotFoundError:
        return False, "not installed"


def _check_container(container_name: str) -> Tuple[bool, str]:
    """Check if a Docker container is running."""
    try:
        result = subprocess.run(
            ["docker", "inspect", "--format", "{{.State.Status}}", container_name],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode == 0:
            status = result.stdout.strip()
            if status == "running":
                return True, "running"
            return False, status
        return False, "not found"
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False, "check failed"


def _check_postgres() -> Tuple[bool, str]:
    """Check PostgreSQL database connection."""
    try:
        start = time.time()
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()
        latency_ms = int((time.time() - start) * 1000)
        return True, f"connected ({latency_ms}ms)"
    except Exception as e:
        return False, f"connection failed: {str(e)[:50]}"


def _check_mysql() -> Tuple[bool, str]:
    """Check MySQL database connection."""
    infra = get_infra_config()
    try:
        result = subprocess.run(
            [
                "docker",
                "exec",
                infra.mysql_container,
                "mysqladmin",
                "ping",
                "-h",
                "localhost",
                "-u",
                infra.mysql_user,
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode == 0 and "alive" in result.stdout.lower():
            return True, "alive"
        return False, "not responding"
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False, "check failed"


def _check_http_endpoint(url: str, timeout: int = 10, allow_403: bool = False) -> Tuple[bool, str]:
    """Check if an HTTP/HTTPS endpoint is accessible."""
    try:
        req = Request(url, headers={'User-Agent': 'ra-infrastructure-healthcheck/1.0'})
        start = time.time()
        response = urlopen(req, timeout=timeout)
        latency_ms = int((time.time() - start) * 1000)
        status_code = response.getcode()

        if status_code in [200, 302]:
            return True, f"HTTP {status_code} ({latency_ms}ms)"
        return False, f"HTTP {status_code}"
    except HTTPError as e:
        # 403 is acceptable for authenticated endpoints
        if e.code == 403 and allow_403:
            return True, f"HTTP 403 (auth required)"
        return False, f"HTTP {e.code}"
    except URLError as e:
        return False, f"connection failed: {str(e.reason)[:30]}"
    except Exception as e:
        return False, f"error: {str(e)[:30]}"


def _check_cloudflared_service() -> Tuple[bool, str]:
    """Check if cloudflared Windows service is running."""
    try:
        result = subprocess.run(
            ["powershell", "-Command", "Get-Service", "cloudflared"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode == 0:
            output = result.stdout.lower()
            if "running" in output:
                return True, "service running"
            return False, "service stopped"
        return False, "service not found"
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False, "check failed"


def _check_selfwize_dashboard() -> Tuple[bool, str, List[str]]:
    """Check Selfwize dashboard and verify service cards are present.

    The dashboard is behind Cloudflare Access, so we:
    1. Check external reachability (dash.selfwize.com) - 302 to auth is OK
    2. Check local services.json (localhost:8088) for content verification

    Returns:
        Tuple of (is_healthy, status_message, list_of_detected_services)
    """
    import json

    # Expected services
    expected_services = [
        "Homeseer",
        "Blue Iris",
        "Asset Inventory",
        "Health Records",
        "Family Contacts",
        "Daily Events",
        "Database Admin",
        "Reverse Proxy",
        "Status Monitor",
    ]

    # Step 1: Check external reachability
    external_ok = False
    external_latency = 0
    try:
        req = Request(
            "https://dash.selfwize.com",
            headers={'User-Agent': 'ra-infrastructure-healthcheck/1.0'}
        )
        start = time.time()
        response = urlopen(req, timeout=15)
        external_latency = int((time.time() - start) * 1000)
        external_ok = response.getcode() in [200, 302]
    except HTTPError as e:
        # 302 redirect to Cloudflare Access is expected
        if e.code == 302:
            external_ok = True
    except Exception:
        external_ok = False

    # Step 2: Check local services.json for content verification
    dash_port = get_infra_config().dashboard_port
    detected = []
    try:
        req = Request(
            f"http://localhost:{dash_port}/services.json",
            headers={'User-Agent': 'ra-infrastructure-healthcheck/1.0'}
        )
        response = urlopen(req, timeout=5)
        body = response.read().decode('utf-8', errors='ignore')

        try:
            data = json.loads(body)
            for group in data.get("groups", []):
                for service in group.get("services", []):
                    name = service.get("name", "")
                    if name in expected_services:
                        detected.append(name)
        except json.JSONDecodeError:
            detected = [svc for svc in expected_services if svc in body]
    except Exception:
        pass  # Local check failed, will report based on external only

    # Build result
    if external_ok and len(detected) >= 7:
        return True, f"reachable, {len(detected)}/9 services ({external_latency}ms)", detected
    elif external_ok and len(detected) > 0:
        return True, f"reachable, {len(detected)}/9 services ({external_latency}ms)", detected
    elif external_ok:
        return True, f"reachable ({external_latency}ms), local check failed", detected
    else:
        return False, "external endpoint unreachable", detected


@app.command()
def selfcheck(
    verbose: bool = typer.Option(False, "--verbose", "-v", help="Show detailed output"),
):
    """Run comprehensive health check of all infrastructure services.

    This command checks:
    - Docker daemon and containers
    - PostgreSQL and MySQL databases
    - Cloudflare tunnel service
    - All external endpoints (*.selfwize.com)
    - Selfwize dashboard and service availability

    Exit code 0 if all critical services are healthy, 1 otherwise.
    """
    console.print(Panel.fit(
        "[bold]ra-infrastructure Self-Check[/bold]\n"
        "Verifying all infrastructure services...",
        border_style="cyan"
    ))
    console.print()

    # Track overall health
    all_healthy = True
    critical_failure = False

    # =========================================================================
    # DOCKER INFRASTRUCTURE
    # =========================================================================
    console.print("[bold cyan]Docker Infrastructure[/bold cyan]")

    checks = []

    # Docker daemon
    healthy, msg = _check_docker_daemon()
    checks.append(("Docker Daemon", healthy, msg, True))  # Critical
    all_healthy = all_healthy and healthy
    if not healthy:
        critical_failure = True

    # Docker containers
    infra = get_infra_config()
    containers = [
        (infra.postgres_container, "PostgreSQL", True),
        (infra.mysql_container, "MySQL", True),
        (infra.pgadmin_container, "pgAdmin", False),
        (infra.traefik_container, "Traefik", False),
        (infra.gatus_container, "Gatus", False),
        (infra.dashboard_container, "Dashboard", False),
        (infra.snipeit_container, "Snipe-IT", False),
        (infra.fasten_container, "Fasten Health", False),
        (infra.eventlog_container, "Event Log", False),
        (infra.eventlog_db_container, "Event Log DB", False),
    ]

    for container_name, display_name, is_critical in containers:
        healthy, msg = _check_container(container_name)
        checks.append((display_name, healthy, msg, is_critical))
        all_healthy = all_healthy and healthy
        if not healthy and is_critical:
            critical_failure = True

    _print_checks_table(checks)
    console.print()

    # =========================================================================
    # DATABASE SERVICES
    # =========================================================================
    console.print("[bold cyan]Database Services[/bold cyan]")

    checks = []

    # PostgreSQL
    healthy, msg = _check_postgres()
    checks.append(("PostgreSQL (inventory)", healthy, msg, True))
    all_healthy = all_healthy and healthy
    if not healthy:
        critical_failure = True

    # MySQL
    healthy, msg = _check_mysql()
    checks.append(("MySQL (homeautomation)", healthy, msg, True))
    all_healthy = all_healthy and healthy
    if not healthy:
        critical_failure = True

    _print_checks_table(checks)
    console.print()

    # =========================================================================
    # CLOUDFLARE TUNNEL
    # =========================================================================
    console.print("[bold cyan]Cloudflare Tunnel[/bold cyan]")

    checks = []

    # Cloudflared service
    healthy, msg = _check_cloudflared_service()
    checks.append(("cloudflared service", healthy, msg, True))
    all_healthy = all_healthy and healthy
    if not healthy:
        critical_failure = True

    _print_checks_table(checks)
    console.print()

    # =========================================================================
    # EXTERNAL ENDPOINTS
    # =========================================================================
    console.print("[bold cyan]External Endpoints (*.selfwize.com)[/bold cyan]")

    checks = []

    endpoints = [
        ("https://status.selfwize.com", "Status Monitor", False, False),
        ("https://stuff.selfwize.com", "Asset Inventory", False, True),
        ("https://wellness.selfwize.com", "Health Records", False, True),
        ("https://home.selfwize.com", "Homeseer", False, True),
        ("https://cameras.selfwize.com", "Blue Iris", False, True),
        ("https://family.selfwize.com", "Family Contacts", False, True),
        ("https://events.selfwize.com", "Daily Events", False, True),
    ]

    for url, display_name, is_critical, allow_403 in endpoints:
        healthy, msg = _check_http_endpoint(url, allow_403=allow_403)
        checks.append((display_name, healthy, msg, is_critical))
        all_healthy = all_healthy and healthy
        if not healthy and is_critical:
            critical_failure = True

    _print_checks_table(checks)
    console.print()

    # =========================================================================
    # SELFWIZE DASHBOARD
    # =========================================================================
    console.print("[bold cyan]Selfwize Dashboard[/bold cyan]")

    healthy, msg, detected = _check_selfwize_dashboard()
    checks = [("dash.selfwize.com", healthy, msg, False)]
    all_healthy = all_healthy and healthy

    _print_checks_table(checks)

    if verbose and detected:
        console.print(f"\n[dim]Detected services: {', '.join(detected)}[/dim]")

    console.print()

    # =========================================================================
    # SUMMARY
    # =========================================================================
    if critical_failure:
        console.print(Panel.fit(
            "[bold red]CRITICAL FAILURE[/bold red]\n"
            "One or more critical services are unavailable!\n"
            "Check the output above for details.",
            border_style="red"
        ))
        raise typer.Exit(1)
    elif not all_healthy:
        console.print(Panel.fit(
            "[bold yellow]DEGRADED[/bold yellow]\n"
            "Some non-critical services are unavailable.\n"
            "Infrastructure is operational but check warnings above.",
            border_style="yellow"
        ))
        raise typer.Exit(0)
    else:
        console.print(Panel.fit(
            "[bold green]ALL SYSTEMS OPERATIONAL[/bold green]\n"
            "All infrastructure services are healthy.",
            border_style="green"
        ))
        raise typer.Exit(0)


def _print_checks_table(checks: List[Tuple[str, bool, str, bool]]):
    """Print a table of health checks.

    Args:
        checks: List of tuples (name, is_healthy, message, is_critical)
    """
    table = Table(show_header=False, box=None, padding=(0, 2))
    table.add_column("Service", style="cyan")
    table.add_column("Status", justify="left")
    table.add_column("Details", style="dim")

    for name, healthy, msg, is_critical in checks:
        if healthy:
            status = "[green]OK[/green]"
        else:
            if is_critical:
                status = "[bold red]CRITICAL[/bold red]"
            else:
                status = "[yellow]WARN[/yellow]"

        # Add critical indicator to name
        display_name = f"{name} [bold red]*[/bold red]" if is_critical and not healthy else name

        table.add_row(display_name, status, msg)

    console.print(table)


@app.command()
def check_endpoint(
    url: str = typer.Argument(..., help="URL to check"),
    timeout: int = typer.Option(10, "--timeout", "-t", help="Timeout in seconds"),
    allow_403: bool = typer.Option(False, "--allow-403", help="Treat 403 as success"),
):
    """Check a specific HTTP/HTTPS endpoint.

    Useful for testing individual services or debugging connectivity issues.
    """
    console.print(f"[bold]Checking:[/bold] {url}")
    console.print()

    healthy, msg = _check_http_endpoint(url, timeout=timeout, allow_403=allow_403)

    if healthy:
        console.print(f"[green]OK[/green] - {msg}")
        raise typer.Exit(0)
    else:
        console.print(f"[red]FAILED[/red] - {msg}")
        raise typer.Exit(1)
