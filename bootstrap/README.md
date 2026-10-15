# Bootstrap flow

This directory contains the deterministic, multi-stage bootstrap for a fresh Debian Trixie Raspberry Pi 400. The repo is designed to be portable and repeatable: the same stage definitions are used by the bash installer, the FlipperZero payload, and the Docker validation environment.

## Stages

- 00-base.sh: ensure the base Debian system is ready for a controlled setup.
- 01-packages.sh: install the required software stack.
- 02-users.sh: provision and harden the `pi-safe-fetch` service account.
- 03-security.sh: interactively install the reviewed policy, security runtime, and systemd units.
- 04-memory.sh: set up the local memory and wiki directories.
- 05-persona.sh: select the Saturnin daily-driver persona and flavor profile.
- 06-config.sh: generate the runtime config and environment profile.
- 07-verify.sh: validate required tools and deployed target state.
- 08-production-gate.sh: validate the reviewed target policy and explicit operator approval.

## Logging

Each bootstrap run writes a timestamped entry to a consolidated log file at:

```bash
${HOME}/.local/share/pi-harness/bootstrap.log
```

This includes the runtime mode, flavor, dry-run state, and each stage start/finish event. You can also point the run at a custom log file with:

```bash
PI_HARNESS_LOG=/path/to/custom.log ./bootstrap/bootstrap.sh --mode bash --flavor sysadmin
```

## Operator authentication

Every live bootstrap run prompts for the operator's sudo password and requires `--approve` before any target mutation begins. This includes runs filtered with `--stage`. The `--dry-run`, `--list-stages`, and `--help` commands remain available without authentication.

Stage `01-packages.sh` installs the Pi harness and uv for the invoking user. It installs the official headless NymVPN daemon (`nym-vpnd`) and command-line client (`nym-vpnc`) from the Nym release assets using the authenticated sudo session; it does not install the desktop `nym-vpn-app`.

Stage `03-security.sh` asks for exact HTTPS hostnames, confirms the resulting allowlist, installs the policy at `/etc/pi-security/security-policy.toml`, deploys the runtime to `/opt/pi-security/Pi-Scripts`, and installs the safe-fetch systemd units. The socket is deliberately not enabled or started automatically.

## Shared contract

The stage scripts are intentionally small, deterministic, and idempotent. They should fail clearly and explain what to fix when a requirement is missing.

The executable stage order is maintained in `stages.list`, which the pipeline validates before it authenticates or mutates a target. `stage-manifest.yaml` documents the same contract for humans and tooling; the bootstrap runner does not parse it directly, and tests keep the two lists aligned.

## Quick start

After manually completing the Raspberry Pi OS netinstaller, use one of these entrypoints:

Existing checkout:

```bash
cd ~/WorkspacePi
./install-target.sh --mode bash --flavor sysadmin --approve
```

Fetch and delegate:

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/REPOSITORY/main/bootstrap/install-from-source.sh | \
	bash -s -- \
	--repository-url https://HOST/OWNER/REPOSITORY.git \
	--mode bash \
	--flavor sysadmin \
	--approve
```

The fetcher requires an explicit HTTPS repository URL and delegates to the same `install-target.sh` used by an existing checkout. Netinstall and SD-card operations remain outside this repository.

For inspection before mutation:

```bash
./bootstrap/bootstrap.sh --list-stages
./bootstrap/bootstrap.sh --mode bash --flavor sysadmin --dry-run
./bootstrap/bootstrap.sh --mode bash --flavor sysadmin --stage 00-base.sh --dry-run
```

## Flow

```bash
./bootstrap/bootstrap.sh --mode bash --flavor sysadmin
./bootstrap/bootstrap.sh --mode flipper --flavor scientific
./bootstrap/bootstrap.sh --mode docker --flavor sysadmin
```

The deployment adapter decides how to execute the same stage pipeline, while the stage definitions remain the single source of truth.
