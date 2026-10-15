#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FLAVOR="${1:-sysadmin}"

case "$FLAVOR" in
  sysadmin)
    MANIFEST="${ROOT_DIR}/../flavors/sysadmin/manifest.yaml"
    ;;
  scientific)
    MANIFEST="${ROOT_DIR}/../flavors/scientific/manifest.yaml"
    ;;
  *)
    echo "Unsupported flavor: $FLAVOR" >&2
    exit 2
    ;;
 esac

echo "Flavor manifest: $MANIFEST"
if [ ! -f "$MANIFEST" ]; then
  echo "Missing flavor manifest: $MANIFEST" >&2
  exit 1
fi

echo "Flavor $FLAVOR is loaded and ready for bootstrap."
