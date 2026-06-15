#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd "$SCRIPT_DIR/.." && pwd)
cd "$PROJECT_ROOT"

if [ -x "tools/python/bin/python" ]; then
  PY="tools/python/bin/python"
elif [ -x "tools/python/python" ]; then
  PY="tools/python/python"
elif command -v python3 >/dev/null 2>&1; then
  PY="python3"
elif command -v python >/dev/null 2>&1; then
  PY="python"
else
  echo "GodotMCP startup failed: Python was not found." >&2
  exit 1
fi

exec "$PY" "scripts/godot_mcp_stdio.py" "$@"
