#!/usr/bin/env bash
set -eu

MODE="${1:-bash}"
FLAVOR="${2:-sysadmin}"

STATE_DIR="${HOME}/.local/share/pi-harness"
PLAN_FILE="$STATE_DIR/user-plan.json"
SERVICE_ACCOUNT="pi-safe-fetch"
SERVICE_GROUP="pi-safe-fetch"
SERVICE_HOME="/var/lib/pi-safe-fetch"
SERVICE_SHELL="/usr/sbin/nologin"

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

provision_service_account() {
  local passwd_entry group_entry account_gid account_home account_shell account_groups service_gid

  if ! getent group "$SERVICE_GROUP" >/dev/null 2>&1; then
    echo "[stage:02-users] Creating system group: $SERVICE_GROUP"
    run_as_root groupadd --system "$SERVICE_GROUP"
  fi

  group_entry="$(getent group "$SERVICE_GROUP" || true)"
  IFS=: read -r _ _ service_gid _ <<< "$group_entry"

  passwd_entry="$(getent passwd "$SERVICE_ACCOUNT" || true)"
  if [ -z "$passwd_entry" ]; then
    echo "[stage:02-users] Creating service account: $SERVICE_ACCOUNT"
    run_as_root useradd --system --gid "$SERVICE_GROUP" --home-dir "$SERVICE_HOME" --shell "$SERVICE_SHELL" --no-create-home "$SERVICE_ACCOUNT"
  fi

  passwd_entry="$(getent passwd "$SERVICE_ACCOUNT" || true)"
  if [ -z "$passwd_entry" ]; then
    echo "[stage:02-users] FAIL: unable to resolve $SERVICE_ACCOUNT after provisioning." >&2
    exit 1
  fi

  IFS=: read -r _ _ _ account_gid _ account_home _ account_shell <<< "$passwd_entry"
  account_groups="$(id -G "$SERVICE_ACCOUNT")"
  if [ "$account_home" != "$SERVICE_HOME" ] || [ "$account_shell" != "$SERVICE_SHELL" ] || [ "$account_gid" != "$service_gid" ] || [ "$account_groups" != "$service_gid" ]; then
    echo "[stage:02-users] FAIL: existing $SERVICE_ACCOUNT does not match the hardened service-account policy." >&2
    echo "[stage:02-users] Found home=$account_home shell=$account_shell primary_gid=$account_gid groups=$account_groups; expected home=$SERVICE_HOME shell=$SERVICE_SHELL primary_gid=$service_gid and no supplementary groups. Refusing to rewrite it." >&2
    exit 1
  fi

  run_as_root passwd --lock "$SERVICE_ACCOUNT" >/dev/null
  run_as_root install -d -o "$SERVICE_ACCOUNT" -g "$SERVICE_GROUP" -m 700 "$SERVICE_HOME"
  run_as_root install -d -o root -g root -m 755 /etc/pi-security
  echo "[stage:02-users] PASS: hardened service account $SERVICE_ACCOUNT is ready"
}

mkdir -p "$STATE_DIR"

provision_service_account

case "$FLAVOR" in
  sysadmin)
    ROLE="sysadmin-hacker-designer"
    ;;
  scientific)
    ROLE="scholarly-research-writing"
    ;;
  *)
    echo "[stage:02-users] Unsupported flavor: $FLAVOR" >&2
    exit 1
    ;;
 esac

cat > "$PLAN_FILE" <<EOF
{
  "mode": "${MODE}",
  "flavor": "${FLAVOR}",
  "role": "${ROLE}",
  "service_account": "${SERVICE_ACCOUNT}",
  "status": "provisioned",
  "notes": [
    "The hardened service account was provisioned by the bootstrap.",
    "Do not grant access to SSH keys, qmd indexes, or the user's home directory.",
    "Keep service files under /etc/pi-security and separate from the project workspace.",
    "For sensitive tasks, prefer minimum required privileges and read-only state."
  ]
}
EOF

chmod 600 "$PLAN_FILE"

echo "[stage:02-users] mode=$MODE flavor=$FLAVOR"
echo "[stage:02-users] Provisioned user plan created at $PLAN_FILE"
echo "[stage:02-users] Service account recommendation: $SERVICE_ACCOUNT"
