from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.main import app, settings


@pytest.fixture
def client() -> Iterator[TestClient]:
    with TestClient(app) as test_client:
        yield test_client


def test_root_returns_welcome_payload(client: TestClient) -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert response.json() == {
        "name": settings.app_name,
        "message": "Welcome to SecureOps API",
    }


def test_health_returns_healthy_status(client: TestClient) -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}


def test_info_returns_application_metadata(client: TestClient) -> None:
    response = client.get("/api/v1/info")

    assert response.status_code == 200
    assert response.json() == {
        "name": settings.app_name,
        "version": app.version,
        "environment": settings.environment,
    }


def test_status_returns_running_status(client: TestClient) -> None:
    response = client.get("/api/v1/status")

    assert response.status_code == 200
    assert response.json() == {"status": "running"}


def test_unknown_route_returns_not_found(client: TestClient) -> None:
    response = client.get("/api/v1/does-not-exist")

    assert response.status_code == 404
    assert response.json() == {"detail": "Not Found"}
