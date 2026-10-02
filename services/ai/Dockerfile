FROM python:3.12-slim
WORKDIR /app
COPY --from=ghcr.io/astral-sh/uv:0.11.19 /uv /bin/uv
COPY pyproject.toml uv.lock ./
COPY cwai ./cwai
RUN uv sync --frozen --no-dev && useradd --uid 10001 --create-home cwai && mkdir -p /data/originals && chown cwai /data/originals
COPY alembic.ini ./
COPY alembic ./alembic
USER cwai
ENV PATH="/app/.venv/bin:$PATH"
CMD ["uvicorn", "cwai.api:app", "--host", "0.0.0.0", "--port", "8000"]
