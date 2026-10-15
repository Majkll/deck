#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

prompt_choice() {
  local prompt="$1"
  shift
  local choice
  echo "$prompt"
  PS3='Choice> '
  select choice in "$@"; do
    case "$choice" in
      "")
        echo "Please select a valid option." >&2
        ;;
      *)
        echo "$choice"
        return 0
        ;;
    esac
  done
}

confirm_install() {
  local confirmation
  printf 'Proceed with the approved live bootstrap? [y/N] ' >&2
  read -r confirmation
  case "$confirmation" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      echo "Bootstrap cancelled." >&2
      return 1
      ;;
  esac
}

main() {
  echo "== Saturnin first-run selector =="
  echo "Select the mode for this Pi."
  echo
  local mode
  mode="$(prompt_choice "What do you want to start?" "Daily Driver" "Special Agent")"

  case "$mode" in
    "Daily Driver")
      echo "Daily Driver selected. Saturnin will start with the personal butler baseline."
      confirm_install
      bash "$ROOT_DIR/bootstrap.sh" --mode bash --flavor sysadmin --approve
      ;;
    "Special Agent")
      local flavor
      flavor="$(prompt_choice "Which special agent flavor do you want?" "sysadmin" "scientific")"
      echo "Special Agent selected: $flavor"
      confirm_install
      bash "$ROOT_DIR/bootstrap.sh" --mode bash --flavor "$flavor" --approve
      ;;
    *)
      echo "Unsupported selection: $mode" >&2
      exit 2
      ;;
  esac
}

main "$@"
