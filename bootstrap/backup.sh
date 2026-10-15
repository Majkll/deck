#!/usr/bin/env bash
set -eu

ACTION="${1:-help}"
TARGET_DIR="${2:-${HOME}/.local/share/pi-harness-backup}"
STAMP="$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<'EOF'
Usage:
  backup.sh snapshot [target-dir]
  backup.sh restore <snapshot-file>

This script creates a simple, reviewable backup bundle for the Pi harness state.
It is intentionally small and safe: no secrets are written to the repo, and the
archive is meant to be operator-managed.
EOF
}

snapshot() {
  local output_dir="${1:-$TARGET_DIR}"
  mkdir -p "$output_dir"
  local archive_path="$output_dir/pi-harness-state-${STAMP}.tar.gz"
  tar -czf "$archive_path" \
    --exclude='.git' \
    --exclude='node_modules' \
    "${HOME}/.config/pi-harness" \
    "${HOME}/.local/share/pi-memory" \
    "${HOME}/.local/share/pi-wiki" \
    "${HOME}/.local/share/pi-harness" 2>/dev/null || true

  echo "Snapshot created at: $archive_path"
}

restore() {
  local archive_path="$1"
  if [ ! -f "$archive_path" ]; then
    echo "Restore target not found: $archive_path" >&2
    exit 1
  fi

  tar -xzf "$archive_path" -C "$HOME"
  echo "Restore complete from: $archive_path"
}

case "$ACTION" in
  snapshot)
    snapshot "$TARGET_DIR"
    ;;
  restore)
    if [ $# -lt 2 ]; then
      echo "A snapshot archive path is required for restore." >&2
      usage >&2
      exit 1
    fi
    restore "$2"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    usage >&2
    exit 2
    ;;
 esac
