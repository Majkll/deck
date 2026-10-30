# Bootstrap flow

This directory contains the deterministic, multi-stage bootstrap for a fresh Debian Trixie Raspberry Pi 400. Bash, FlipperZero, and Docker modes remain in the codebase. Current development scope is the Bash path; defer Flipper and Docker feature work until the Bash setup is solid.

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

Stage `01-packages.sh` also installs upstream qmd `@tobilu/qmd` version 2.8.3 using Bun for the invoking user; it does not use an apt qmd package. Stage `04-memory.sh` registers the `memory` collection only when `--enable-qmd` is selected, and fails if qmd is missing or registration cannot be verified. Ingest sanitized text with `python3 Pi-Scripts/safe_qmd_ingest.py memory`, then run `qmd update` to refresh the index. The wrapper stores private Markdown artifacts; it does not launch qmd or download models. The bootstrap does not start indexing.

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
```

All three mode options remain present. Use Bash for current setup development; Flipper and Docker work is deferred until the Bash setup is solid.

## Complete the target setup

For the full native Raspberry Pi setup, use `--mode bash` and choose either `sysadmin` or `scientific`. Flipper and Docker modes remain in the codebase but are outside the current development scope until the Bash setup is solid. Both flavors install the same automatic package set; the flavor selects profile metadata and does not install specialist applications or agent skills.

After the live bootstrap:

1. Review the run log and installed profile. Confirm all stages completed and inspect `~/.config/pi-harness/active-profile.env`.
2. Review `/etc/pi-security/security-policy.toml` and confirm its exact HTTPS hostname allowlist is appropriate. The socket stays disabled by default. Only after reviewing the policy and deciding to use the service, enable it with `sudo systemctl enable --now pi-safe-fetch.socket`; check it with `systemctl status pi-safe-fetch.socket`. Do not enable it with an empty or unreviewed policy.
3. Complete NymVPN account setup and configure/connect the headless client if you need VPN service. Bootstrap installs `nym-vpnd` and `nym-vpnc` but does not configure an account or connect the VPN; consult `nym-vpnc --help` and the vendor's current setup guidance.
4. Configure the chosen agent runtime with a model/provider and credentials through an OS-managed secret mechanism or runtime injection. Install and configure the actual skill implementations you want; profile skill names are metadata and are not downloaded by bootstrap.
5. Set up the optional memory and flavor-specific workflows you need. Bootstrap creates the memory/wiki directories, but does not install or initialize qmd or wiki tooling. For scientific work, add the LaTeX, bibliography, research, and PDF tools you use; for sysadmin work, add any specialist tools you require.
6. Review any separate integrations before relying on them. `Pi-Hooks` is not deployed by the bootstrap pipeline.

Run the system check after completing the installation:

```bash
./bootstrap/verify-system.sh
tail -n 50 ~/.local/share/pi-harness/bootstrap.log
```

The verifier checks the bootstrap's expected binaries and deployed state; it does not certify optional runtime integrations, VPN connectivity, memory indexing, or live systemd behavior. Follow the [production runbook](../docs/production-runbook.md) for the target review and sign-off.
