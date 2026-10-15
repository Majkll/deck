#!/usr/bin/env bash
set -eu

MODE="${1:-bash}"
FLAVOR="${2:-sysadmin}"

echo "[stage:00-base] mode=$MODE flavor=$FLAVOR"
if [ ! -f /etc/os-release ]; then
  echo "[stage:00-base] /etc/os-release is missing; this bootstrap expects Debian Trixie." >&2
  exit 1
fi
if ! grep -qi 'debian' /etc/os-release; then
  echo "[stage:00-base] Detected OS is not Debian; this repo targets Debian Trixie." >&2
  exit 1
fi

echo "[stage:00-base] Base system check passed."
