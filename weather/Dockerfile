FROM python:3.14-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
WORKDIR /app
COPY pyproject.toml uv.lock ./
ENV UV_PROJECT_ENVIRONMENT=/app/.venv
RUN uv sync --frozen --no-dev

FROM python:3.14-slim AS runtime
WORKDIR /app
RUN groupadd -r etl && useradd -r -g etl etl
COPY --from=builder /app/.venv /app/.venv
COPY --chown=etl:etl src/ .
USER etl

ENV PATH=/app/.venv/bin:$PATH
ENTRYPOINT ["python", "main.py"]
