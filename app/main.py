import logging

from fastapi import FastAPI

from app.config import get_settings

settings = get_settings()

logging.basicConfig(
    level=settings.log_level.upper(),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(title=settings.app_name, version="0.1.0")


@app.get("/")
def root() -> dict[str, str]:
    return {
        "name": settings.app_name,
        "message": "Welcome to SecureOps API",
    }


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "healthy"}


@app.get("/api/v1/info")
def info() -> dict[str, str]:
    return {
        "name": settings.app_name,
        "version": app.version,
        "environment": settings.environment,
    }


@app.get("/api/v1/status")
def status() -> dict[str, str]:
    logger.info("Status endpoint requested")
    return {"status": "running"}
