#!/usr/bin/env bash
set -eu

MODE="${1:-bash}"
FLAVOR="${2:-sysadmin}"

STATE_DIR="${HOME}/.local/share/pi-harness"
LOG_FILE="$STATE_DIR/bootstrap-verify.log"

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

mkdir -p "$STATE_DIR"

echo "[stage:07-verify] mode=$MODE flavor=$FLAVOR"
checks=0
failures=0

check() {
  local label="$1"
  local condition="$2"
  checks=$((checks + 1))
  if eval "$condition"; then
    echo "[stage:07-verify] PASS: $label" | tee -a "$LOG_FILE"
  else
    echo "[stage:07-verify] FAIL: $label" | tee -a "$LOG_FILE" >&2
    echo "[stage:07-verify] Remediation: review the requirement and re-run this stage after fixing the underlying issue." | tee -a "$LOG_FILE" >&2
    failures=$((failures + 1))
  fi
}

check 'debian os-release' '[ -f /etc/os-release ] && grep -qi debian /etc/os-release'
check 'python3 available' 'command -v python3 >/dev/null 2>&1'
check 'curl available' 'command -v curl >/dev/null 2>&1'
check 'wget available' 'command -v wget >/dev/null 2>&1'
check 'fail2ban available' 'command -v fail2ban-client >/dev/null 2>&1 || command -v fail2ban-server >/dev/null 2>&1'
check 'NymVPN daemon package installed' 'dpkg-query -W -f='\''${Status}'\'' nym-vpnd 2>/dev/null | grep -q "install ok installed"'
check 'NymVPN CLI package and command available' 'dpkg-query -W -f='\''${Status}'\'' nym-vpnc 2>/dev/null | grep -q "install ok installed" && command -v nym-vpnc >/dev/null 2>&1'
check 'memory directories exist' '[ -d "${HOME}/.local/share/pi-memory" ] && [ -d "${HOME}/.local/share/pi-wiki" ]'
check 'user plan exists' '[ -f "${HOME}/.local/share/pi-harness/user-plan.json" ]'
check 'persona config exists' '[ -f "${HOME}/.local/share/pi-harness/persona.json" ]'
check 'pi-safe-fetch account is hardened' 'getent passwd pi-safe-fetch | awk -F: '\''$6 == "/var/lib/pi-safe-fetch" && $7 == "/usr/sbin/nologin"'\'' >/dev/null'
check 'pi-safe-fetch primary group is dedicated' '[ "$(id -gn pi-safe-fetch)" = "pi-safe-fetch" ]'
check 'pi-safe-fetch has no supplementary groups' '[ "$(id -G pi-safe-fetch | wc -w)" -eq 1 ]'
check 'pi-safe-fetch password is locked' 'passwd -S pi-safe-fetch 2>/dev/null | awk '\''$2 == "L"'\'' >/dev/null'
check 'service directory is private' '[ -d /var/lib/pi-safe-fetch ] && [ "$(stat -c %a /var/lib/pi-safe-fetch)" = 700 ]'
check 'security policy is installed and restricted' '[ -f /etc/pi-security/security-policy.toml ] && [ "$(stat -c %a /etc/pi-security/security-policy.toml)" = 600 ] && [ "$(stat -c %U:%G /etc/pi-security/security-policy.toml)" = root:root ]'
check 'security policy has an allowlist' 'run_as_root grep -Eq '\''allowed_domains[[:space:]]*=[[:space:]]*\[[^]]+\]'\'' /etc/pi-security/security-policy.toml'
check 'security runtime is deployed' '[ -f /opt/pi-security/Pi-Scripts/safe_fetch_service.py ] && [ -f /opt/pi-security/Pi-Scripts/safe_fetch.py ] && [ "$(stat -c %U:%G /opt/pi-security/Pi-Scripts/safe_fetch_service.py)" = root:root ]'
check 'systemd units are installed' '[ -f /etc/systemd/system/pi-safe-fetch.socket ] && [ -f /etc/systemd/system/pi-safe-fetch@.service ] && [ "$(stat -c %U:%G /etc/systemd/system/pi-safe-fetch.socket)" = root:root ]'

if [ "$failures" -gt 0 ]; then
  echo "[stage:07-verify] $failures failed checks out of $checks." | tee -a "$LOG_FILE" >&2
  exit 1
fi

echo "[stage:07-verify] All verification checks passed." | tee -a "$LOG_FILE"
