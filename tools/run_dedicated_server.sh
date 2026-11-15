#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
PORT="${BLOXTACOS_PORT:-24680}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [[ ! -x "$GODOT_BIN" ]]; then
  echo "Godot não encontrado. Defina GODOT_BIN=/caminho/para/godot." >&2
  exit 127
fi
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "BLOXTACOS_PORT precisa ser uma porta UDP entre 1 e 65535." >&2
  exit 2
fi

exec "$GODOT_BIN" --headless --path "$PROJECT_DIR" -- --server "--port=${PORT}"
