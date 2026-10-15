#!/usr/bin/env bash
set -eu

MODE="${1:-bash}"
FLAVOR="${2:-sysadmin}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APPROVED=false
DRY_RUN=false

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --approve)
      APPROVED=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [ "${PI_HARNESS_PRODUCTION_APPROVED:-}" = "1" ] || [ "${PI_HARNESS_PRODUCTION_APPROVED:-}" = "true" ]; then
  APPROVED=true
fi

check_policy() {
  local policy_file="/etc/pi-security/security-policy.toml"

  if [ ! -f "$policy_file" ]; then
    policy_file="$ROOT_DIR/config/security-policy.toml"
  fi

  if [ ! -f "$policy_file" ]; then
    echo "[stage:08-production-gate] FAIL: security policy is missing at $policy_file" >&2
    return 1
  fi

  if ! run_as_root grep -Eq 'allowed_domains[[:space:]]*=[[:space:]]*\[[^]]+\]' "$policy_file"; then
    echo "[stage:08-production-gate] FAIL: allowed_domains is still empty; complete the interactive policy setup before enabling the service." >&2
    return 1
  fi

  echo "[stage:08-production-gate] PASS: reviewed policy detected at $policy_file"
}

check_docs() {
  local service_policy="$ROOT_DIR/docs/service-account-policy.md"
  if [ ! -f "$service_policy" ]; then
    echo "[stage:08-production-gate] FAIL: service account guidance is missing at $service_policy" >&2
    return 1
  fi

  echo "[stage:08-production-gate] PASS: service account guidance present"
}

if [ "$DRY_RUN" = true ]; then
  echo "[stage:08-production-gate] DRY_RUN: production gate would require operator approval before live installation."
  echo "[stage:08-production-gate] mode=$MODE flavor=$FLAVOR"
  exit 0
fi

if [ "$APPROVED" != true ]; then
  echo "[stage:08-production-gate] Production gate: explicit operator approval is required before live target deployment." >&2
  echo "[stage:08-production-gate] Review the following before continuing:" >&2
  echo "  - config/security-policy.toml (non-empty allowlist; ensure only reviewed domains are included)" >&2
  echo "  - docs/service-account-policy.md (least-privilege service account pattern)" >&2
  echo "  - target environment and backup recovery plan" >&2
  echo "[stage:08-production-gate] Re-run with --approve or set PI_HARNESS_PRODUCTION_APPROVED=1 to continue." >&2
  exit 1
fi

check_policy
check_docs

echo "[stage:08-production-gate] Production gate passed for mode=$MODE flavor=$FLAVOR"
