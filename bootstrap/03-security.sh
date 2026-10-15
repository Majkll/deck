#!/usr/bin/env bash
set -eu

MODE="${1:-bash}"
FLAVOR="${2:-sysadmin}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

POLICY_SOURCE="$ROOT_DIR/config/security-policy.toml"
POLICY_TARGET="/etc/pi-security/security-policy.toml"
CODE_TARGET="/opt/pi-security"
SERVICE_HOME="/var/lib/pi-safe-fetch"
UNIT_TARGET="/etc/systemd/system"

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

policy_has_domains() {
  local policy_file="$1"
  if ! run_as_root grep -Eq 'allowed_domains[[:space:]]*=[[:space:]]*\[[^]]+\]' "$policy_file"; then
    return 1
  fi

  run_as_root python3 - "$policy_file" <<'PY'
import re
import sys
import tomllib

with open(sys.argv[1], "rb") as handle:
    policy = tomllib.load(handle)
domains = policy.get("network", {}).get("allowed_domains")
if not isinstance(domains, list) or not domains:
    raise SystemExit(1)
if any(not isinstance(domain, str) or not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?", domain) or "." not in domain or ".." in domain for domain in domains):
    raise SystemExit(1)
PY
}

collect_domains() {
  local input raw domain domains_json confirmation

  while true; do
    printf '[stage:03-security] Enter exact HTTPS hostnames, comma-separated: ' >&2
    IFS= read -r input
    if [ -z "$input" ]; then
      echo "[stage:03-security] At least one hostname is required; the safe-fetch service will remain disabled." >&2
      continue
    fi

    domains_json=""
    IFS=',' read -ra raw_domains <<< "$input"
    for raw in "${raw_domains[@]}"; do
      domain="$(printf '%s' "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      if [[ ! "$domain" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] || [[ "$domain" != *.* ]] || [[ "$domain" == *..* ]]; then
        echo "[stage:03-security] Invalid hostname: $domain" >&2
        domains_json=""
        break
      fi
      if [ -n "$domains_json" ]; then
        domains_json+=", "
      fi
      domains_json+="\"${domain,,}\""
    done

    if [ -z "$domains_json" ]; then
      continue
    fi

    echo "[stage:03-security] Proposed allowed domains: [$domains_json]" >&2
    printf '[stage:03-security] Confirm this allowlist? [y/N] ' >&2
    read -r confirmation
    case "$confirmation" in
      y|Y|yes|YES)
        printf '%s\n' "$domains_json"
        return 0
        ;;
      *)
        echo "[stage:03-security] Allowlist rejected; please enter it again." >&2
        ;;
    esac
  done
}

install_policy() {
  local domains_json temporary_policy

  if [ -f "$POLICY_TARGET" ] && policy_has_domains "$POLICY_TARGET"; then
    echo "[stage:03-security] PASS: existing reviewed policy retained at $POLICY_TARGET"
    return 0
  fi

  domains_json="$(collect_domains)"
  temporary_policy="$(mktemp)"
  sed "s/^allowed_domains[[:space:]]*=.*/allowed_domains = [${domains_json}]/" "$POLICY_SOURCE" > "$temporary_policy"
  run_as_root install -o root -g root -m 600 "$temporary_policy" "$POLICY_TARGET"
  rm -f "$temporary_policy"
  echo "[stage:03-security] PASS: reviewed policy installed at $POLICY_TARGET"
}

install_runtime() {
  echo "[stage:03-security] Installing security runtime at $CODE_TARGET"
  run_as_root install -d -o root -g root -m 755 "$CODE_TARGET"
  run_as_root install -d -o root -g root -m 755 "$CODE_TARGET/Pi-Scripts"
  run_as_root cp -a "$ROOT_DIR/Pi-Scripts/." "$CODE_TARGET/Pi-Scripts/"
  run_as_root chown -R root:root "$CODE_TARGET"
  run_as_root find "$CODE_TARGET" -type d -exec chmod 755 {} +
  run_as_root find "$CODE_TARGET" -type f -exec chmod 644 {} +
  run_as_root install -d -o pi-safe-fetch -g pi-safe-fetch -m 700 "$SERVICE_HOME"
}

install_units() {
  if ! command -v systemctl >/dev/null 2>&1; then
    echo "[stage:03-security] FAIL: systemctl is required to install the safe-fetch units." >&2
    exit 1
  fi

  run_as_root install -o root -g root -m 644 "$ROOT_DIR/systemd/pi-safe-fetch@.service" "$UNIT_TARGET/pi-safe-fetch@.service"
  run_as_root install -o root -g root -m 644 "$ROOT_DIR/systemd/pi-safe-fetch.socket" "$UNIT_TARGET/pi-safe-fetch.socket"
  run_as_root systemctl daemon-reload
  echo "[stage:03-security] PASS: systemd units installed and daemon reloaded"
  echo "[stage:03-security] Socket activation is disabled by default. Review, then run: sudo systemctl enable --now pi-safe-fetch.socket"
}

main() {
  echo "[stage:03-security] mode=$MODE flavor=$FLAVOR"

  if [ ! -d "$ROOT_DIR/Pi-Scripts" ] || [ ! -f "$POLICY_SOURCE" ]; then
    echo "[stage:03-security] FAIL: required security source files are missing." >&2
    exit 1
  fi

  install_policy
  install_runtime
  install_units
  echo "[stage:03-security] Security runtime deployed; no service was enabled or started."
}

main "$@"
