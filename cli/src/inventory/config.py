"""
Configuration management using pydantic-settings.
"""

from functools import lru_cache
from pathlib import Path
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        env_prefix="INV_",
        case_sensitive=False,
        extra="ignore",  # Ignore extra env vars like POSTGRES_DB, PGADMIN_EMAIL, etc.
    )

    # Database
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "inventory"
    db_user: str = "inventory"
    db_password: str = "inventory_dev_password"

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
