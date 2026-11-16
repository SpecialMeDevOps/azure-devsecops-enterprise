from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "SecureOps API"
    environment: str = "development"
    log_level: str = "INFO"

    model_config = SettingsConfigDict(
        env_prefix="SECUREOPS_",
        env_file=".env",
        extra="ignore",
        case_sensitive=False,
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
