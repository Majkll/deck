#!/usr/bin/env bash
set -eu

MODE="bash"
FLAVOR="sysadmin"
DRY_RUN=false
STAGE_FILTER=""
STAGE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAGE_REGISTRY="$STAGE_DIR/stages.list"
LOG_FILE="${PI_HARNESS_LOG:-${HOME}/.local/share/pi-harness/bootstrap.log}"
STAGES=()

usage() {
  cat <<'EOF'
Usage: bootstrap.sh --mode <bash|flipper|docker> --flavor <sysadmin|scientific> [--dry-run] [--list-stages] [--stage <stage-name>] [--approve]

This script launches the deterministic Pi bootstrap pipeline.
It keeps a single stage definition and allows different deployment adapters.
When --dry-run is set, the stage list is printed without executing any target-side script.
Use --list-stages to print the available stage names. Use --stage to run a single stage by basename or path.
The production gate requires explicit operator approval before a live target install is permitted.
EOF
}

load_stages() {
  local stage_name
  local line_number=0
  local -A seen_stages=()

  if [ ! -f "$STAGE_REGISTRY" ]; then
    echo "Missing stage registry: $STAGE_REGISTRY" >&2
    exit 1
  fi

  while IFS= read -r stage_name || [ -n "$stage_name" ]; do
    line_number=$((line_number + 1))
    if [[ ! "$stage_name" =~ ^[0-9]{2}-[a-z0-9-]+\.sh$ ]]; then
      echo "Invalid stage registry entry on line $line_number: $stage_name" >&2
      exit 1
    fi
    if [ -n "${seen_stages[$stage_name]+x}" ]; then
      echo "Duplicate stage registry entry on line $line_number: $stage_name" >&2
      exit 1
    fi
    if [ ! -f "$STAGE_DIR/$stage_name" ]; then
      echo "Missing stage file for registry entry: $stage_name" >&2
      exit 1
    fi
    seen_stages[$stage_name]=1
    STAGES+=("$STAGE_DIR/$stage_name")
  done < "$STAGE_REGISTRY"

  if [ "${#STAGES[@]}" -eq 0 ]; then
    echo "Stage registry is empty: $STAGE_REGISTRY" >&2
    exit 1
  fi
}

list_stages() {
  for stage in "${STAGES[@]}"; do
    if [ -f "$stage" ]; then
      basename "$stage"
    fi
  done
}

matches_stage_filter() {
  local stage_path="$1"
  local stage_name
  stage_name="$(basename "$stage_path")"

  if [ -z "$STAGE_FILTER" ]; then
    return 0
  fi

  if [ "$stage_path" = "$STAGE_FILTER" ] || [ "$stage_name" = "$STAGE_FILTER" ]; then
    return 0
  fi

  return 1
}

load_stages

log_run() {
  local message="$1"
  if [ "$DRY_RUN" = true ]; then
    return 0
  fi
  mkdir -p "$(dirname -- "$LOG_FILE")"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $message" >> "$LOG_FILE"
}

require_operator_authentication() {
  if [ "$DRY_RUN" = true ]; then
    return 0
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "A sudo-enabled operator session is required for a live bootstrap, but sudo is not installed." >&2
    exit 1
  fi

  echo "Authenticate with sudo before the bootstrap begins."
  if ! sudo -v; then
    echo "Sudo authentication failed; the bootstrap has not started." >&2
    exit 1
  fi
}

require_production_approval() {
  if [ "$DRY_RUN" = true ]; then
    return 0
  fi

  if [ "${PI_HARNESS_PRODUCTION_APPROVED:-}" != "1" ] && [ "${PI_HARNESS_PRODUCTION_APPROVED:-}" != "true" ]; then
    echo "Production approval is required before target mutations begin." >&2
    echo "Review the target, recovery plan, and security policy, then re-run with --approve." >&2
    exit 1
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --flavor)
      FLAVOR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --approve)
      export PI_HARNESS_PRODUCTION_APPROVED=1
      shift
      ;;
    --list-stages)
      list_stages
      exit 0
      ;;
    --stage)
      if [ "$#" -lt 2 ]; then
        echo "--stage requires a stage name or path." >&2
        usage >&2
        exit 2
      fi
      STAGE_FILTER="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$MODE" in
  bash|flipper|docker)
    ;;
  *)
    echo "Unsupported mode: $MODE" >&2
    exit 2
    ;;
 esac

case "$FLAVOR" in
  sysadmin|scientific)
    ;;
  *)
    echo "Unsupported flavor: $FLAVOR" >&2
    exit 2
    ;;
 esac

if [ -n "$STAGE_FILTER" ] && [ "$DRY_RUN" != true ]; then
  echo "Live --stage execution is disabled because it can bypass required stage prerequisites." >&2
  echo "Use --dry-run with --stage for inspection, or run the complete approved pipeline." >&2
  exit 2
fi

require_operator_authentication
require_production_approval
log_run "bootstrap start mode=$MODE flavor=$FLAVOR dry_run=$DRY_RUN"

# The stage runner keeps a single shared pipeline for bash, flipper, and docker
# deployments while preserving review-safe defaults for the target Pi.
# Any live system changes should be validated in a disposable environment first.

for stage in "${STAGES[@]}"; do
  if [ ! -f "$stage" ]; then
    echo "==> Missing stage file: $stage" >&2
    echo "The stage pipeline cannot continue without the exact bootstrap stage. Investigate the missing script before running on a target system." >&2
    log_run "missing stage: $stage"
    exit 1
  fi

  if ! matches_stage_filter "$stage"; then
    continue
  fi

  if [ "$DRY_RUN" = true ]; then
    echo "DRY_RUN: would run $stage (mode: $MODE, flavor: $FLAVOR)"
    log_run "dry_run would run $(basename "$stage")"
    continue
  fi

  echo "==> Running $stage (mode: $MODE, flavor: $FLAVOR)"
  log_run "starting stage $(basename "$stage")"
  bash "$stage" "$MODE" "$FLAVOR"
  log_run "completed stage $(basename "$stage")"
done

if [ "$DRY_RUN" = true ]; then
  echo "DRY_RUN: Bootstrap pipeline preview complete in mode: $MODE, flavor: $FLAVOR"
  log_run "dry_run complete mode=$MODE flavor=$FLAVOR"
  exit 0
fi

echo "Bootstrap pipeline finished in mode: $MODE, flavor: $FLAVOR"
log_run "bootstrap complete mode=$MODE flavor=$FLAVOR"
