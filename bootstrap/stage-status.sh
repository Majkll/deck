#!/usr/bin/env bash
set -eu

LOG_FILE="${PI_HARNESS_LOG:-${HOME}/.local/share/pi-harness/stage-status.log}"
mkdir -p "$(dirname -- "$LOG_FILE")"

log() {
  local stage="$1"
  local status="$2"
  local message="$3"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $stage | $status | $message" >> "$LOG_FILE"
  echo "$stage: $status - $message"
}

if [ "$#" -lt 2 ]; then
  echo "Usage: stage-status.sh <stage-name> <status> [message]" >&2
  exit 2
fi

STAGE="$1"
STATUS="$2"
MESSAGE="${3:-no message}"
log "$STAGE" "$STATUS" "$MESSAGE"

if [ -n "${PI_HARNESS_LOG_SUMMARY:-}" ]; then
  printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $STAGE | $STATUS | $MESSAGE" >> "$PI_HARNESS_LOG_SUMMARY"
fi
