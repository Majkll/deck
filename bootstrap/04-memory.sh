#!/usr/bin/env bash
set -eu

MODE="${1:-bash}"
FLAVOR="${2:-sysadmin}"

HOME_ROOT="${HOME:-/home/pi}"
MEMORY_DIR="$HOME_ROOT/.local/share/pi-memory"
WIKI_DIR="$HOME_ROOT/.local/share/pi-wiki"

main() {
  echo "[stage:04-memory] mode=$MODE flavor=$FLAVOR"
  mkdir -p "$MEMORY_DIR" "$WIKI_DIR"
  chmod 700 "$MEMORY_DIR" "$WIKI_DIR"

  echo "[stage:04-memory] PASS: memory directories created"
  echo "[stage:04-memory] Memory root: $MEMORY_DIR"
  echo "[stage:04-memory] Wiki root: $WIKI_DIR"
}

main "$@"
