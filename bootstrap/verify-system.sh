#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-bash}"
FLAVOR="${2:-sysadmin}"

check_bin() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    echo "PASS: $name"
    return 0
  fi
  echo "FAIL: $name" >&2
  echo "Remediation: install $name or fix PATH before continuing." >&2
  return 1
}

main() {
  echo "== System validation =="
  echo "mode=$MODE flavor=$FLAVOR"

  local failed=0
  for bin in pi fail2ban-client curl wget python3 uv nym-vpnc; do
    if ! check_bin "$bin"; then
      failed=1
    fi
  done

  if [ ! -d "$ROOT_DIR/../Pi-Scripts" ]; then
    echo "FAIL: Pi-Scripts directory missing" >&2
    failed=1
  else
    echo "PASS: Pi-Scripts directory present"
  fi

  if [ "$failed" -ne 0 ]; then
    echo "Validation failed. Fix the missing requirements, then rerun this script." >&2
    exit 1
  fi

  echo "Validation complete: system is ready for bootstrap execution."
}

main "$@"
