#!/bin/bash
set -e

# Map Railway's PORT to MCP SSE port (Railway injects $PORT)
# Move the Go bridge to an internal port so it doesn't collide
if [ -n "$PORT" ]; then
  export MCP_PORT="$PORT"
  export BRIDGE_PORT="${BRIDGE_PORT:-8081}"
fi

# Default MCP transport to SSE when running in container (can be overridden)
export MCP_TRANSPORT="${MCP_TRANSPORT:-stdio}"

# Persistent data directory — attach a Railway volume at /data to survive restarts
export DATA_DIR="${DATA_DIR:-/data}"

# Ensure Python MCP server reads the same DB the Go bridge writes to
export MESSAGES_DB_PATH="${MESSAGES_DB_PATH:-$DATA_DIR/messages.db}"

# Point Python MCP server at the Go bridge's internal port
export WHATSAPP_API_BASE_URL="${WHATSAPP_API_BASE_URL:-http://localhost:${BRIDGE_PORT:-8080}/api}"

# Trap signals for clean shutdown
cleanup() {
  echo "Shutting down..."
  if [ -n "$BRIDGE_PID" ]; then
    kill "$BRIDGE_PID" 2>/dev/null || true
  fi
  if [ -n "$MCP_PID" ]; then
    kill "$MCP_PID" 2>/dev/null || true
  fi
  wait
  exit 0
}
trap cleanup SIGTERM SIGINT

# Start Go WhatsApp bridge in background
echo "Starting WhatsApp bridge..."
/app/whatsapp-bridge-bin &
BRIDGE_PID=$!

# Wait for bridge to initialize
sleep 3

# Start Python MCP server
echo "Starting MCP server (transport=$MCP_TRANSPORT)..."
cd /app/whatsapp-mcp-server
python main.py &
MCP_PID=$!

# Wait for either process to exit
wait -n "$BRIDGE_PID" "$MCP_PID"

# If one exits, shut down the other
echo "A process exited, shutting down..."
cleanup
