#!/usr/bin/env bash
set -eu

MODE="${1:-bash}"
FLAVOR="${2:-sysadmin}"

CONFIG_DIR="${HOME}/.config/pi-harness"
STATE_DIR="${HOME}/.local/share/pi-harness"
PROFILE_FILE="$CONFIG_DIR/active-profile.env"

mkdir -p "$CONFIG_DIR" "$STATE_DIR"

case "$FLAVOR" in
  sysadmin)
    PROFILE_LABEL="sysadmin-hacker-designer"
    SKILLS="bash,git,networking,grill-me-with-plans,user questions,debian,NYM,python3,using-uv,caveman,OWASP"
    ;;
  scientific)
    PROFILE_LABEL="scholarly-research-writing"
    SKILLS="bash,git,networking,grill-me-with-plans,user questions,debian,NYM,python3,using-uv"
    ;;
  *)
    echo "[stage:06-config] Unsupported flavor: $FLAVOR" >&2
    exit 1
    ;;
 esac

cat > "$PROFILE_FILE" <<EOF
MODE=${MODE}
FLAVOR=${FLAVOR}
PROFILE_LABEL=${PROFILE_LABEL}
PERSONA=Saturnin
MEMORY_ROOT=${HOME}/.local/share/pi-memory
WIKI_ROOT=${HOME}/.local/share/pi-wiki
SKILLS=${SKILLS}
EOF
chmod 600 "$PROFILE_FILE"

cat > "$STATE_DIR/profile.json" <<EOF
{
  "mode": "${MODE}",
  "flavor": "${FLAVOR}",
  "profile_label": "${PROFILE_LABEL}",
  "persona": "Saturnin",
  "memory_root": "${HOME}/.local/share/pi-memory",
  "wiki_root": "${HOME}/.local/share/pi-wiki",
  "skills": "${SKILLS}",
  "review_required": true,
  "notes": [
    "Keep the profile in the user config directory and do not commit it to the project repo.",
    "Review the loaded profile before enabling network fetch or privileged operations."
  ]
}
EOF

chmod 600 "$STATE_DIR/profile.json"

echo "[stage:06-config] Runtime configuration generated in $PROFILE_FILE"
echo "[stage:06-config] Review required before enabling privileged or networked runtime actions."
