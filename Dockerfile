FROM python:3.14.4-trixie AS build

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

COPY --from=ghcr.io/astral-sh/uv:0.5.4 /uv /uvx /usr/local/bin/

WORKDIR /app

COPY pyproject.toml uv.lock* ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project || uv sync --no-dev --no-install-project

COPY src ./src


FROM python:3.14.4-trixie AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH"

RUN groupadd --system --gid 1001 webhook \
    && useradd --system --uid 1001 --gid webhook --home-dir /app --shell /usr/sbin/nologin webhook

WORKDIR /app

COPY --from=build --chown=webhook:webhook /app/.venv /app/.venv
COPY --from=build --chown=webhook:webhook /app/src /app/src

USER webhook

EXPOSE 8443 9090

CMD ["uvicorn", "--app-dir", "src", "main:app", "--host", "0.0.0.0", "--port", "8443", \
     "--ssl-certfile", "/tls/tls.crt", "--ssl-keyfile", "/tls/tls.key"]
