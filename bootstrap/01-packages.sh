#!/usr/bin/env bash
set -eu

MODE="${1:-bash}"
FLAVOR="${2:-sysadmin}"

SYSTEM_COMMANDS=(
  fail2ban-client
  curl
  wget
  python3
)

USER_COMMANDS=(
  pi
  uv
)

NYM_VERSION="2026.12.4"
NYM_RELEASE_URL="https://github.com/nymtech/nym-vpn-client/releases/download/nym-vpn-v${NYM_VERSION}"

check_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    echo "[stage:01-packages] PASS: $name is installed"
    return 0
  fi

  echo "[stage:01-packages] MISSING: $name" >&2
  return 1
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

check_commands() {
  local failed=0
  local cmd

  for cmd in "$@"; do
    if ! check_command "$cmd"; then
      failed=1
    fi
  done

  return "$failed"
}

install_user_tools() {
  if ! command -v pi >/dev/null 2>&1; then
    echo "[stage:01-packages] Installing the Pi harness for the invoking user..."
    curl -fsSL https://pi.dev/install.sh | sh
  fi

  if ! command -v uv >/dev/null 2>&1; then
    echo "[stage:01-packages] Installing uv for the invoking user..."
    curl -fsSL https://astral.sh/uv/install.sh | sh
  fi
}

install_nym() {
  if dpkg-query -W -f='${Status}' nym-vpnd 2>/dev/null | grep -q 'install ok installed' && \
    dpkg-query -W -f='${Status}' nym-vpnc 2>/dev/null | grep -q 'install ok installed'; then
    echo "[stage:01-packages] PASS: headless NymVPN daemon and CLI are installed"
    return 0
  fi

  local architecture daemon_sha256 cli_sha256
  case "$(dpkg --print-architecture)" in
    arm64)
      architecture="arm64"
      daemon_sha256="3bac09456dd6cb4c3c163df8fea29e46f51c56d77dd37c2fca80d64175549b2d"
      cli_sha256="be19d9290e228707fd6c04977b8666d3c1d222805916d4900b2da33df8c98355"
      ;;
    amd64)
      architecture="amd64"
      daemon_sha256="c28260de21d6f4ab486a0f37268ab9968184fbab1a6c4432e0e1fc96673c7934"
      cli_sha256="dc1d7f43beef5cf05a2dcfa0cee6bc89b335c58bd4ac0ddaf73726cc08d49eab"
      ;;
    *)
      echo "[stage:01-packages] Unsupported architecture for official headless NymVPN packages: $(dpkg --print-architecture)" >&2
      return 1
      ;;
  esac

  local daemon_deb cli_deb
  daemon_deb="$(mktemp /tmp/nym-vpnd.XXXXXX.deb)"
  cli_deb="$(mktemp /tmp/nym-vpnc.XXXXXX.deb)"
  trap 'rm -f "$daemon_deb" "$cli_deb"' RETURN

  echo "[stage:01-packages] Installing official headless NymVPN daemon and CLI..."
  wget -q "$NYM_RELEASE_URL/nym-vpnd_${NYM_VERSION}_${architecture}.deb" -O "$daemon_deb"
  wget -q "$NYM_RELEASE_URL/nym-vpnc_${NYM_VERSION}_${architecture}.deb" -O "$cli_deb"
  printf '%s  %s\n' "$daemon_sha256" "$daemon_deb" | sha256sum -c - >/dev/null
  printf '%s  %s\n' "$cli_sha256" "$cli_deb" | sha256sum -c - >/dev/null
  run_as_root dpkg --install "$daemon_deb" "$cli_deb"
  run_as_root apt-get install -f -y
}

install_packages() {
  export DEBIAN_FRONTEND=noninteractive
  run_as_root apt-get update
  run_as_root apt-get install -y --no-install-recommends \
    fail2ban \
    curl \
    wget \
    python3 \
    python3-venv \
    ca-certificates

  install_user_tools
  install_nym

  if ! command -v pi >/dev/null 2>&1; then
    echo "[stage:01-packages] WARN: 'pi' binary is not on PATH. Install the Pi harness package or set PATH as required by your chosen agent runtime." >&2
  fi

  if ! command -v nym-vpnc >/dev/null 2>&1; then
    echo "[stage:01-packages] WARN: 'nym-vpnc' is not on PATH. Verify the official headless NymVPN CLI installation before use." >&2
  fi
}

main() {
  echo "[stage:01-packages] mode=$MODE flavor=$FLAVOR"

  if [ ! -f /etc/os-release ]; then
    echo "[stage:01-packages] /etc/os-release missing; cannot verify Debian Trixie setup." >&2
    exit 1
  fi

  if ! grep -qi 'debian' /etc/os-release; then
    echo "[stage:01-packages] This bootstrap targets Debian; detected a different OS." >&2
    exit 1
  fi

  local failed=0
  if ! check_commands "${SYSTEM_COMMANDS[@]}" "${USER_COMMANDS[@]}"; then
    failed=1
  fi

  if [ "$failed" -eq 0 ]; then
    install_nym
    echo "[stage:01-packages] Required software is already installed."
    return 0
  fi

  echo "[stage:01-packages] Installing required Debian packages and user toolchains..."
  install_packages

  echo "[stage:01-packages] Package installation complete."
}

main "$@"
