FROM python:3.12-slim
WORKDIR /app
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir "pip @ https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl#sha256=fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70"

COPY --from=ghcr.io/astral-sh/uv:0.13.4@sha256:9f130421e930bfbdc563c00740466603f8723158e90297d07957c2294640262b /uv /uvx /usr/local/bin/
COPY pyproject.toml uv.lock ./
COPY cwai ./cwai
RUN uv sync --frozen --no-dev && useradd --uid 10001 --create-home cwai && mkdir -p /data/originals && chown cwai /data/originals
COPY alembic.ini ./
COPY alembic ./alembic
USER cwai
ENV PATH="/app/.venv/bin:$PATH"
CMD ["uvicorn", "cwai.api:app", "--host", "0.0.0.0", "--port", "8000"]
