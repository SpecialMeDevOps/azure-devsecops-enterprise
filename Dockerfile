# syntax=docker/dockerfile:1.7

FROM python:3.12-slim-bookworm AS builder

WORKDIR /build

RUN apt-get update \
    && apt-get install --no-install-recommends -y build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN python -m pip wheel \
    --no-cache-dir \
    --wheel-dir=/wheelhouse \
    -r requirements.txt

FROM python:3.12-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    SECUREOPS_ENVIRONMENT=production \
    SECUREOPS_LOG_LEVEL=INFO

RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN groupadd --system --gid 10001 secureops \
    && useradd --system --uid 10001 --gid secureops \
        --no-create-home --home-dir /nonexistent \
        --shell /usr/sbin/nologin secureops

COPY requirements.txt /tmp/requirements.txt

RUN --mount=type=bind,from=builder,source=/wheelhouse,target=/wheelhouse,ro \
    python -m pip install \
        --no-cache-dir \
        --no-index \
        --find-links=/wheelhouse \
        -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

COPY --chown=10001:10001 app/ ./app/

USER 10001:10001

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["python", "-c", "from urllib.request import urlopen; response = urlopen('http://127.0.0.1:8000/health', timeout=2); raise SystemExit(0 if response.status == 200 else 1)"]

CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--timeout-graceful-shutdown", "30"]
