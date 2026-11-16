# Azure DevSecOps Enterprise — SecureOps Platform

An evolving portfolio project for a secure, automated Azure delivery platform. The intended end-to-end design uses FastAPI, Azure DevOps, Terraform, Docker, Azure Container Registry (ACR), Azure Kubernetes Service (AKS), Helm, and security and monitoring tools.

> **Project status:** Development is in progress. The current implementation is the initial FastAPI application scaffold only. CI/CD, security scanning, containerization, Terraform, Kubernetes, Helm, monitoring, and Azure deployment have not yet been implemented. No Azure resources have been created.

## Implemented so far

### SecureOps API

The initial FastAPI application provides:

- `GET /` — welcome response and application name.
- `GET /health` — basic liveness response.
- `GET /api/v1/info` — application name, version, and configured environment.
- `GET /api/v1/status` — application running status; logs when requested.
- Settings loaded from environment variables, with optional `.env` support.
- Configurable application name, environment, and log level.
- FastAPI interactive documentation at `/docs` and OpenAPI schema at `/openapi.json`.

The current app version is `0.1.0`. This is a starting point, not a claim that the service is production-ready or completely secure.

### Current repository files

```text
.
├── app/
│   ├── __init__.py
│   ├── config.py
│   └── main.py
├── .gitignore
├── README.md
└── requirements.txt
```

`.gitignore` excludes local `.env` files (except a future `.env.example`), virtual environments, Python bytecode/cache, pytest cache, and coverage output. Do not put credentials in source control.

## Run locally

Requirements: Python 3.12 or a compatible Python version and an internet connection to install the declared packages. Docker, Terraform, Azure CLI, and Kubernetes are not needed for this current app-only step.

From the repository root in PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --reload
```

Open `http://127.0.0.1:8000/docs` to view and exercise the API. The root, health, info, and status routes are available at `/`, `/health`, `/api/v1/info`, and `/api/v1/status`.

Optional settings use the `SECUREOPS_` prefix. For example, in the current PowerShell session:

```powershell
$env:SECUREOPS_ENVIRONMENT = "development"
$env:SECUREOPS_LOG_LEVEL = "INFO"
python -m uvicorn app.main:app --reload
```

Supported settings are `SECUREOPS_APP_NAME`, `SECUREOPS_ENVIRONMENT`, and `SECUREOPS_LOG_LEVEL`. Environment variables take precedence over values in an optional `.env` file.

## Dependencies

Runtime dependencies are declared in [`requirements.txt`](requirements.txt):

- FastAPI for the API framework.
- Pydantic Settings for environment-based configuration.
- Uvicorn for the ASGI development server.

Dependency installation and live HTTP endpoint checks have not yet been confirmed in this environment; the first installation attempt timed out while downloading packages. Python source compilation and editor diagnostics passed for the initial scaffold.

## Planned platform architecture

The target workflow is:

```text
Developer
  -> GitHub
  -> Azure DevOps pipeline
  -> quality checks and automated tests
  -> dependency, source, infrastructure, and image security scans
  -> Docker image and ACR
  -> AKS deployment with Helm
  -> monitoring and alerts
```

Terraform, Key Vault integration, workload identity federation, Kubernetes resources, Helm, Trivy/Bandit/pip-audit scanning, and observability are planned work; they are not present in the repository yet. Azure provisioning is intentionally deferred until the final deployment phase and requires explicit cost review and approval.

## Progress checklist

- [x] Phase 1 — initial FastAPI application scaffold and dependency declarations.
- [ ] Phase 1 — application tests, validation, and remaining application setup.
- [ ] Phase 2 — application quality checks, automated tests, and GitHub workflow.
- [ ] Phase 3 — Dockerfile and container configuration.
- [ ] Phase 4 — Terraform modules and non-provisioning validation.
- [ ] Phase 5 — Azure DevOps pipeline.
- [ ] Phase 6 — security scanning and remediation.
- [ ] Phase 7 — Kubernetes manifests and Helm chart.
- [ ] Phase 8 — monitoring and observability configuration.
- [ ] Phase 9 — complete documentation and final verification.
- [ ] Phase 10 — Azure deployment, only after cost disclosure and approval.

This checklist records project progress; checked items do not imply that later phases or cloud deployment have been completed.
