#!/usr/bin/env bash
set -eu

MODE="${1:-bash}"
FLAVOR="${2:-sysadmin}"

HOME_ROOT="${HOME:-/home/pi}"
MEMORY_DIR="$HOME_ROOT/.local/share/pi-memory"
WIKI_DIR="$HOME_ROOT/.local/share/pi-wiki"
QMD_ENABLED="${PI_BOOTSTRAP_ENABLE_QMD:-false}"
QMD_DIR="$MEMORY_DIR/qmd"
QMD_COLLECTION_DIR="$MEMORY_DIR/qmd/collections"
QMD_COLLECTION_NAME="memory"

main() {
  local collection_details

  echo "[stage:04-memory] mode=$MODE flavor=$FLAVOR qmd=${QMD_ENABLED}"
  mkdir -p "$MEMORY_DIR" "$WIKI_DIR"
  chmod 700 "$MEMORY_DIR" "$WIKI_DIR"

  if [ "$QMD_ENABLED" = "true" ] || [ "$QMD_ENABLED" = "1" ]; then
    if ! command -v qmd >/dev/null 2>&1; then
      echo "[stage:04-memory] FAIL: qmd is required for --enable-qmd; install it in stage 01 before enabling collection setup." >&2
      exit 1
    fi

    mkdir -p "$QMD_COLLECTION_DIR"
    chmod 700 "$QMD_DIR" "$QMD_COLLECTION_DIR"
    if ! collection_details="$(qmd collection show "$QMD_COLLECTION_NAME" 2>/dev/null)"; then
      if ! qmd collection add "$QMD_COLLECTION_DIR" --name "$QMD_COLLECTION_NAME"; then
        echo "[stage:04-memory] FAIL: qmd could not register the memory collection." >&2
        exit 1
      fi
    fi
    if ! collection_details="$(qmd collection show "$QMD_COLLECTION_NAME")"; then
      echo "[stage:04-memory] FAIL: unable to verify the qmd memory collection registration." >&2
      exit 1
    fi
    if ! grep -Fxq "  Path:     $QMD_COLLECTION_DIR" <<< "$collection_details"; then
      echo "[stage:04-memory] FAIL: qmd collection '$QMD_COLLECTION_NAME' points to an unexpected path." >&2
      exit 1
    fi

    echo "[stage:04-memory] PASS: qmd collection '$QMD_COLLECTION_NAME' is registered"
    echo "[stage:04-memory] Qmd root: $QMD_DIR"
    echo "[stage:04-memory] Collection root: $QMD_COLLECTION_DIR"
    echo "[stage:04-memory] Collection setup is opt-in; ingest only through the sanitized wrapper in Pi-Scripts/safe_qmd_ingest.py."
  else
    echo "[stage:04-memory] INFO: qmd memory collection remains opt-in; enable it with --enable-qmd or PI_BOOTSTRAP_ENABLE_QMD=1."
  fi

  echo "[stage:04-memory] PASS: memory directories created"
  echo "[stage:04-memory] Memory root: $MEMORY_DIR"
  echo "[stage:04-memory] Wiki root: $WIKI_DIR"
}

main "$@"
