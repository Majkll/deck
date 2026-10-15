#!/usr/bin/env bash
set -eu

MODE="${1:-bash}"
FLAVOR="${2:-sysadmin}"

STATE_DIR="${HOME}/.local/share/pi-harness"
PERSONA_FILE="$STATE_DIR/persona.json"

mkdir -p "$STATE_DIR"

main() {
  echo "[stage:05-persona] mode=$MODE flavor=$FLAVOR"

  case "$FLAVOR" in
    sysadmin)
      PROFILE_NAME="sysadmin-hacker-designer"
      PERSONA_NAME="Saturnin"
      SKILLS="bash,git,networking,grill-me-with-plans,user questions,debian,NYM,python3,using-uv,caveman,OWASP"
      ;;
    scientific)
      PROFILE_NAME="scholarly-research-writing"
      PERSONA_NAME="Saturnin"
      SKILLS="bash,git,networking,grill-me-with-plans,user questions,debian,NYM,python3,using-uv"
      ;;
    *)
      echo "[stage:05-persona] Unsupported flavor: $FLAVOR" >&2
      exit 1
      ;;
  esac

  cat > "$PERSONA_FILE" <<EOF
{
  "mode": "${MODE}",
  "flavor": "${FLAVOR}",
  "persona": "${PERSONA_NAME}",
  "profile_name": "${PROFILE_NAME}",
  "skills": "${SKILLS}",
  "baseline": "daily-driver",
  "status": "selected"
}
EOF

  chmod 600 "$PERSONA_FILE"

  echo "[stage:05-persona] Daily-driver baseline: Saturnin"
  echo "[stage:05-persona] Selected flavor: $PROFILE_NAME"
  echo "[stage:05-persona] Persona configuration written to $PERSONA_FILE"
}

main "$@"
