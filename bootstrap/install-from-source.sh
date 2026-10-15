#!/usr/bin/env bash
set -eu

REPOSITORY_URL=""
DESTINATION="${HOME}/WorkspacePi"
MODE="bash"
FLAVOR="sysadmin"
DRY_RUN=false
APPROVED=false

usage() {
  cat <<'EOF'
Usage: install-from-source.sh --repository-url <https-url> [options]

Fetch WorkspacePi into a clean Raspberry Pi OS environment and delegate to the
checked-out install-target.sh entrypoint.

Options:
  --repository-url URL  HTTPS Git repository to clone
  --destination PATH    Empty destination directory (default: ~/WorkspacePi)
  --mode MODE            Deployment mode (default: bash)
  --flavor FLAVOR       Flavor (default: sysadmin)
  --dry-run              Show actions without cloning or installing packages
  --approve              Approve live prerequisite installation and bootstrap
EOF
}

fail() {
  echo "[install-from-source] FAIL: $1" >&2
  exit 1
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

validate_inputs() {
  if [ -z "$REPOSITORY_URL" ]; then
    fail "--repository-url is required"
  fi
  if [[ "$REPOSITORY_URL" != https://* ]]; then
    fail "--repository-url must use HTTPS"
  fi
  if [[ "$DESTINATION" != /* ]]; then
    fail "--destination must be an absolute path"
  fi
  case "$MODE" in
    bash|flipper|docker)
      ;;
    *)
      fail "unsupported mode: $MODE"
      ;;
  esac
  case "$FLAVOR" in
    sysadmin|scientific)
      ;;
    *)
      fail "unsupported flavor: $FLAVOR"
      ;;
  esac
}

ensure_prerequisites() {
  if command -v git >/dev/null 2>&1 && { [ "$(id -u)" -eq 0 ] || command -v sudo >/dev/null 2>&1; }; then
    return 0
  fi
  if [ "$DRY_RUN" = true ]; then
    echo "DRY_RUN: would install git and sudo prerequisites"
    return 0
  fi
  if [ "$APPROVED" != true ]; then
    fail "live prerequisite installation requires --approve"
  fi
  if [ "$(id -u)" -eq 0 ]; then
    apt-get update
    apt-get install -y ca-certificates git sudo
  else
    command -v sudo >/dev/null 2>&1 || fail "sudo is required to install prerequisites"
    run_as_root apt-get update
    run_as_root apt-get install -y ca-certificates git sudo
  fi
}

clone_repository() {
  if [ -e "$DESTINATION" ]; then
    if [ ! -d "$DESTINATION" ] || [ "$(find "$DESTINATION" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
      fail "destination exists and is not empty: $DESTINATION"
    fi
  fi

  if [ "$DRY_RUN" = true ]; then
    echo "DRY_RUN: would clone $REPOSITORY_URL into $DESTINATION"
    return 0
  fi

  mkdir -p "$(dirname -- "$DESTINATION")"
  git clone -- "$REPOSITORY_URL" "$DESTINATION"
}

delegate_install() {
  local installer="$DESTINATION/install-target.sh"
  if [ "$DRY_RUN" = true ]; then
    echo "DRY_RUN: would run $installer --mode $MODE --flavor $FLAVOR"
    return 0
  fi
  [ -x "$installer" ] || chmod +x "$installer"
  local args=(--mode "$MODE" --flavor "$FLAVOR")
  if [ "$APPROVED" = true ]; then
    args+=(--approve)
  fi
  bash "$installer" "${args[@]}"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repository-url)
      [ "$#" -ge 2 ] || fail "--repository-url requires a value"
      REPOSITORY_URL="$2"
      shift 2
      ;;
    --destination)
      [ "$#" -ge 2 ] || fail "--destination requires a value"
      DESTINATION="$2"
      shift 2
      ;;
    --mode)
      [ "$#" -ge 2 ] || fail "--mode requires a value"
      MODE="$2"
      shift 2
      ;;
    --flavor)
      [ "$#" -ge 2 ] || fail "--flavor requires a value"
      FLAVOR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --approve)
      APPROVED=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

validate_inputs
ensure_prerequisites
clone_repository
delegate_install