# Pi harness bootstrap

A deterministic Raspberry Pi bootstrap for a fresh Debian Trixie install, with a shared daily-driver baseline, a Saturnin butler personality, and two operator-facing flavors.

## What this repo is

This project is built to do four things well:

- prepare a clean Pi from a repeatable bootstrap flow
- run a common personal-butler baseline for everyday work
- branch into a sysadmin or scientific flavor
- keep the security, memory, and secret model explicit and reviewable

## Core model

The bootstrap is stage-based and shared across all deployment modes:

1. base OS readiness
2. Debian package installation
3. users and permissions
4. security hardening
5. memory setup
6. persona selection
7. runtime config
8. verification
9. production gate

The deployment adapter changes, but the stage logic stays the same.

## Deployment modes

### Clean Raspberry Pi OS installation

After manually completing the Raspberry Pi OS netinstaller, use either an existing checkout:

```bash
cd ~/WorkspacePi
./install-target.sh --mode bash --flavor sysadmin --approve
```

or fetch the repository and delegate to the same installer:

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/REPOSITORY/main/bootstrap/install-from-source.sh | \
bash -s -- \
	--repository-url https://github.com/OWNER/REPOSITORY.git \
	--mode bash \
	--flavor sysadmin \
	--approve
```

Replace `OWNER/REPOSITORY` with the actual GitHub owner and repository. The fetch path requires an explicit HTTPS repository URL, uses `~/WorkspacePi`, and does not perform Raspberry Pi OS installation or SD-card operations.

### Bash

```bash
cd /path/to/WorkspacePi
./install-target.sh --mode bash --flavor sysadmin --approve
```

### FlipperZero BadUSB payload

```bash
cd /path/to/WorkspacePi
./deploy/flipper/generate_payload.sh --flavor sysadmin
```

### Docker validation

```bash
cd /path/to/WorkspacePi
docker build -f deploy/docker/Dockerfile -t pi-harness .
```

## Daily driver and flavors

Both flavors inherit the same Saturnin baseline.

- Saturnin: practical, privacy-aware butler persona
- sysadmin flavor: systems, networking, security, developer workflows
- scientific flavor: research, writing, literature review, notes, and structured work

## Required software

Core stack:

- pi
- fail2ban
- curl
- wget
- astral-uv
- python3
- NYM

Common skills:

- bash
- git
- networking
- grill-me-with-plans
- user questions
- debian
- NYM
- python3
- using-uv

Sysadmin flavor adds:

- caveman
- OWASP

## Memory and secrets

Memory combines:

- qmd-backed local memory
- Karpathy-style LLM wiki

Secrets stay out of the repo, shell history, logs, qmd indexes, and AGENTS files. Use OS-managed secret stores or runtime injection, not plaintext in project files.

## Security layer

The repo keeps existing security controls in [Pi-Scripts](Pi-Scripts), [Pi-Hooks](Pi-Hooks), and [config](config). They remain a guardrail layer for the bootstrap and runtime, not the whole project story.

## Production gate

Live target installation is blocked until the operator explicitly approves the policy gate. The gate checks the reviewed allowlist in [config/security-policy.toml](config/security-policy.toml), verifies the service-account guidance in [docs/service-account-policy.md](docs/service-account-policy.md), and requires a clean recovery plan before any system mutation.

```bash
./bootstrap/bootstrap.sh --mode bash --flavor sysadmin --approve
```

The same flow can be previewed without execution:

```bash
./bootstrap/bootstrap.sh --mode bash --flavor sysadmin --dry-run --approve
```

## Detailed installation sequence

The supported install targets a fresh Debian Trixie Raspberry Pi after the Raspberry Pi OS netinstaller has completed. Run these commands on the Pi as the normal operator account. Choose either the local-checkout or fetch-and-delegate path above, then continue with validation and the live run.

### 1. Prepare a local checkout, if needed

```bash
sudo apt-get update
sudo apt-get install -y bash ca-certificates git sudo
git clone REPOSITORY_URL ~/WorkspacePi
cd ~/WorkspacePi
chmod +x install-target.sh bootstrap/*.sh deploy/bash/install.sh deploy/flipper/generate_payload.sh
```

If the repository was copied to the Pi instead of cloned, skip `git clone` and change into its directory:

```bash
cd ~/WorkspacePi
```

### 2. Inspect and validate before mutation

```bash
./bootstrap/bootstrap.sh --help
./bootstrap/bootstrap.sh --list-stages
./bootstrap/bootstrap.sh --mode bash --flavor sysadmin --dry-run
bash -n bootstrap/*.sh install-target.sh deploy/bash/install.sh deploy/flipper/generate_payload.sh
python3 -m py_compile Pi-Scripts/*.py
python3 tests/test_bootstrap_scripts.py
python3 tests/test_security.py
```

The dry run does not authenticate with sudo, install packages, create accounts, write `/etc`, or create bootstrap log state.

### 3. Run the live installation from the checkout

Choose one flavor, then run the shared pipeline with explicit production approval:

```bash
cd ~/WorkspacePi
./bootstrap/bootstrap.sh --mode bash --flavor sysadmin --approve
```

For the scientific flavor, use:

```bash
./bootstrap/bootstrap.sh --mode bash --flavor scientific --approve
```

The command authenticates with sudo before stages begin. During security setup, enter exact HTTPS hostnames for the fetch allowlist and confirm the displayed policy. Do not continue with an empty or unreviewed allowlist. The stages install the required Debian packages, user tools, hardened `pi-safe-fetch` account, security runtime, policy, systemd units, memory/persona/configuration, and verification state. The socket is installed but not enabled or started automatically.

The compatibility entrypoint is also available for inspection and legacy integrations. It accepts and forwards `--approve`, so it can be used for a live install as well:

```bash
./install-target.sh --mode bash --flavor sysadmin --approve
```

### 4. Review the installed state

```bash
tail -n 50 ~/.local/share/pi-harness/bootstrap.log
getent passwd pi-safe-fetch
id pi-safe-fetch
sudo systemctl cat pi-safe-fetch.socket
sudo systemctl cat 'pi-safe-fetch@.service'
sudo stat /etc/pi-security/security-policy.toml /opt/pi-security/Pi-Scripts/safe_fetch_service.py
```

Review the policy and socket activation before enabling any service. Keep the recovery plan and bootstrap log with the installation record.

To validate the repository without any target mutation:

```bash
cd /path/to/WorkspacePi
bash -n bootstrap/*.sh install-target.sh deploy/bash/install.sh deploy/flipper/generate_payload.sh bootstrap/first-run.sh bootstrap/flavor-loader.sh bootstrap/verify-system.sh bootstrap/backup.sh bootstrap/stage-status.sh
python3 -m unittest discover -s tests -q
python3 -m py_compile Pi-Scripts/*.py
```

## Repo layout

- [bootstrap](bootstrap) — deterministic stage scripts and entrypoints
- [deploy](deploy) — bash, Flipper, and Docker adapters
- [flavors](flavors) — flavor manifests and docs
- [pantheon](pantheon) — persona definitions like Saturnin
- [memory](memory) — memory model and layout
- [secrets](secrets) — secret-handling guidance
- [Pi-Scripts](Pi-Scripts) — security, policy, and validation tooling
- [Pi-Hooks](Pi-Hooks) — target-side policy and sanitization layer
- [starter-templates](starter-templates) — AGENTS starters
- [systemd](systemd) — service templates
- [docs](docs) — architecture notes

## Useful one-liners

```bash
./bootstrap/bootstrap.sh --list-stages
./bootstrap/bootstrap.sh --mode bash --flavor sysadmin --dry-run
./bootstrap/bootstrap.sh --mode bash --flavor sysadmin --stage 00-base.sh --dry-run
./install-target.sh --mode bash --flavor scientific --dry-run
./deploy/flipper/generate_payload.sh --flavor sysadmin
```

## Production runbook

For the live target install, follow the operator checklist in [docs/production-runbook.md](docs/production-runbook.md). It covers approval, live execution, and how to review the bootstrap log after the run.

## Notes

- The repo is intentionally safe for prep-machine validation.
- The target-side allowlist is operator-managed and intentionally empty until reviewed.
- Runtime state is kept under the target user home, not inside the repo itself.
- Bootstrap runs are logged to ~/.local/share/pi-harness/bootstrap.log for later inspection.
