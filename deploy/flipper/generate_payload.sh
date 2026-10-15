#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/../.. && pwd)"
FLAVOR="sysadmin"
OUTPUT="${ROOT_DIR}/deploy/flipper/payload.txt"

usage() {
  cat <<'EOF'
Usage: generate_payload.sh --flavor <sysadmin|scientific> [--output file]

This generates a payload-friendly adapter that executes the same shared bootstrap stages.
The payload is intentionally a dry-run wrapper for review and is not meant to be executed here.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --flavor)
      FLAVOR="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
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

case "$FLAVOR" in
  sysadmin|scientific)
    ;;
  *)
    echo "Unsupported flavor: $FLAVOR" >&2
    exit 2
    ;;
 esac

mkdir -p "$(dirname -- "$OUTPUT")"
cat > "$OUTPUT" <<EOF
REM Pi harness bootstrap payload
REM Mode: flipper
REM Flavor: ${FLAVOR}
REM Shared stage logic is defined in bootstrap/bootstrap.sh.
REM Review before transmitting to target hardware.
GUI r
STRING bash -lc 'bash ${ROOT_DIR}/bootstrap/bootstrap.sh --mode flipper --flavor ${FLAVOR}'
ENTER
EOF

echo "Generated Flipper payload at $OUTPUT"
