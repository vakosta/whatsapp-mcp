#!/bin/bash
set -e

# Map Railway's PORT to MCP SSE port (Railway injects $PORT)
if [ -n "$PORT" ]; then
  export MCP_PORT="$PORT"
fi

# Default MCP transport to SSE when running in container (can be overridden)
export MCP_TRANSPORT="${MCP_TRANSPORT:-stdio}"

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
