#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MODE="bash"
FLAVOR="sysadmin"
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: install-target.sh --mode <bash|flipper|docker> --flavor <sysadmin|scientific> [--dry-run] [--approve]

This entrypoint delegates to the new multi-stage bootstrap pipeline.
It is kept for compatibility and reuses the same deterministic stage definitions.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --flavor)
      FLAVOR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --approve)
      APPROVE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

BOOTSTRAP_ARGS=(--mode "$MODE" --flavor "$FLAVOR")
if [ "$DRY_RUN" = true ]; then
  BOOTSTRAP_ARGS+=(--dry-run)
fi
if [ "${APPROVE:-false}" = true ]; then
  BOOTSTRAP_ARGS+=(--approve)
fi

exec bash "$ROOT_DIR/bootstrap/bootstrap.sh" "${BOOTSTRAP_ARGS[@]}"
