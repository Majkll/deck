#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/../.. && pwd)"
MODE="bash"
FLAVOR="sysadmin"

usage() {
  cat <<'EOF'
Usage: install.sh --mode <bash|flipper|docker> --flavor <sysadmin|scientific> [--approve]

This adapter calls the shared deterministic bootstrap stages for a native Pi install.
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
if [ "${APPROVE:-false}" = true ]; then
  BOOTSTRAP_ARGS+=(--approve)
fi

bash "$ROOT_DIR/bootstrap/bootstrap.sh" "${BOOTSTRAP_ARGS[@]}"
