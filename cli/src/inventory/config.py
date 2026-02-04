"""
Configuration management using pydantic-settings.
"""

from functools import lru_cache
from pathlib import Path
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class InfraConfig(BaseSettings):
    """Infrastructure topology loaded from config/infrastructure.env.

    This is the single source of truth for container names, ports,
    database names, and paths. No secrets here.
    """

    model_config = SettingsConfigDict(
        env_file=Path(__file__).parent.parent.parent.parent / "config" / "infrastructure.env",
        env_file_encoding="utf-8",
        env_prefix="RA_",
        case_sensitive=False,
        extra="ignore",
    )

    # Container names
    postgres_container: str = "ra_postgres"
    mysql_container: str = "ra_mysql"
    pgadmin_container: str = "ra_pgadmin"
    traefik_container: str = "ra_traefik"
    gatus_container: str = "ra_gatus"
    dashboard_container: str = "ra_dashboard"
    snipeit_container: str = "ra_snipeit"
    fasten_container: str = "ra_fasten"
    eventlog_container: str = "ra_eventlog"
    eventlog_db_container: str = "ra_eventlog_db"

    # Host ports
    postgres_port: int = 5433
    mysql_port: int = 3307
    pgadmin_port: int = 8084
    traefik_port: int = 8070
    gatus_port: int = 8085
    dashboard_port: int = 8088
    snipeit_port: int = 8083
    fasten_port: int = 9091
    eventlog_port: int = 8089
    eventlog_db_port: int = 5434

    # Database settings (non-secret)
    postgres_db: str = "inventory"
    postgres_user: str = "postgres"
    mysql_db: str = "snipeit"
    mysql_user: str = "snipeit"
    eventlog_db: str = "event_log"
    eventlog_user: str = "eventlog"

    # Docker network
    docker_network: str = "ra_network"

    # Compose file (relative to repo root)
    compose_file: str = "docker-compose.yml"

    # Backup paths
    backup_dir: str = r"C:\ra-infrastructure-local-backup\inventory"
    mysql_backup_dir: str = r"C:\ra-infrastructure-local-backup\mysql"
    fasten_backup_dir: str = r"C:\ra-infrastructure-local-backup\fasten"

    # Domain
    domain: str = "selfwize.com"

    # Windows user
    windows_user: str = "Rohit"


@lru_cache
def get_infra_config() -> InfraConfig:
    """Get cached infrastructure config instance."""
    return InfraConfig()


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        env_prefix="INV_",
        case_sensitive=False,
        extra="ignore",
    )

    # Database
    db_host: str = "localhost"
    db_port: int = 5433
    db_name: str = "inventory"
    db_user: str = "postgres"
    db_password: str = ""

    # Application
    debug: bool = False
    log_level: str = "INFO"

    # SMTP settings for monitoring alerts
    smtp_host: str = "localhost"
    smtp_port: int = 25
    smtp_user: Optional[str] = None
    smtp_password: Optional[str] = None
    smtp_tls: bool = False
    alert_email: Optional[str] = None
    alert_webhook: Optional[str] = None

    # Paths
    project_root: Path = Path(__file__).parent.parent.parent.parent
    migrations_path: Path = Path(__file__).parent.parent.parent.parent / "database" / "migrations"
    seeds_path: Path = Path(__file__).parent.parent.parent.parent / "database" / "seeds"

    @property
    def database_url(self) -> str:
        """Construct PostgreSQL connection URL."""
        return f"postgresql://{self.db_user}:{self.db_password}@{self.db_host}:{self.db_port}/{self.db_name}"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
