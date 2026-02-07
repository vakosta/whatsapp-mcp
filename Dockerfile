# Stage 1: Build Go binary
FROM golang:1.24-bookworm AS go-builder

WORKDIR /build
COPY whatsapp-bridge/ ./whatsapp-bridge/
WORKDIR /build/whatsapp-bridge
RUN CGO_ENABLED=1 GOOS=linux go build -o /build/whatsapp-bridge-bin .

# Stage 2: Install Python dependencies
FROM python:3.11-slim-bookworm AS py-builder

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /build/whatsapp-mcp-server
COPY whatsapp-mcp-server/pyproject.toml whatsapp-mcp-server/uv.lock ./
RUN uv sync --frozen --no-dev

# Stage 3: Runtime
FROM python:3.11-slim-bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libsqlite3-0 \
        ffmpeg \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy Go binary
COPY --from=go-builder /build/whatsapp-bridge-bin /app/whatsapp-bridge-bin

# Copy Python venv and source
COPY --from=py-builder /build/whatsapp-mcp-server/.venv /app/whatsapp-mcp-server/.venv
COPY whatsapp-mcp-server/ /app/whatsapp-mcp-server/

# Copy startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

WORKDIR /app

# Default persistent data directory (mount a Railway volume here)
RUN mkdir -p /data

ENV PATH="/app/whatsapp-mcp-server/.venv/bin:$PATH"

EXPOSE 8000

CMD ["/app/start.sh"]
