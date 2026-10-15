# WorkspacePi agent guide

## Project shape

WorkspacePi bootstraps a fresh Debian Trixie Raspberry Pi into a deterministic Saturnin daily-driver environment. The shared pipeline supports Bash, FlipperZero payload, and Docker validation modes plus `sysadmin` and `scientific` flavors.

- `bootstrap/bootstrap.sh` owns stage ordering, mode/flavor validation, approval, authentication, logging, and dry-run behavior.
- `bootstrap/*.sh` contains the stage implementation; keep stages small, idempotent, and explicit about target mutations.
- `bootstrap/install-from-source.sh` is the clean-OS fetcher; it must only acquire the repository and delegate to its checked-out installer.
- `Pi-Scripts/` is the Python policy, sanitization, safe-fetch, qmd-ingestion, and verification runtime.
- `Pi-Hooks/` is a separate TypeScript hook layer and is not deployed by the bootstrap pipeline.
- `systemd/`, `config/`, and `docs/` define the service isolation, reviewed policy, and operational contracts.

Read [README.md](README.md) for the quick start, [docs/architecture.md](docs/architecture.md) for boundaries, and [bootstrap/README.md](bootstrap/README.md) for the stage contract.

## Validation

Run focused checks for the area changed, then the full local baseline when practical:

```bash
bash -n bootstrap/*.sh install-target.sh deploy/bash/install.sh deploy/flipper/generate_payload.sh
python3 -m unittest discover -s tests -q
python3 -m py_compile Pi-Scripts/*.py
```

Useful non-mutating inspections:

```bash
./bootstrap/bootstrap.sh --help
./bootstrap/bootstrap.sh --list-stages
./bootstrap/bootstrap.sh --mode bash --flavor sysadmin --dry-run
```

There is no disposable Debian/systemd integration test in the local suite. Do not describe source-level tests as proof that target permissions, egress, DNS, or systemd hardening work on a live Pi.

## Safety invariants

- Live bootstrap requires both sudo authentication and explicit `--approve`.
- The source fetcher requires an explicit HTTPS repository URL and must refuse non-empty destinations.
- `--help`, `--list-stages`, and `--dry-run` must remain non-mutating and must not authenticate with sudo or create bootstrap logs.
- Do not re-enable live `--stage` execution; selecting a stage is intended for dry-run inspection only.
- Keep the service account as `pi-safe-fetch`, with a locked password, `/usr/sbin/nologin`, no supplementary groups, and its documented state directory.
- Keep the policy reviewed and fail closed. The default allowlist in [config/security-policy.toml](config/security-policy.toml) is empty.
- Treat the systemd service, `/opt/pi-security/Pi-Scripts`, `/etc/pi-security/security-policy.toml`, and service-account paths as one coupled deployment contract.
- Never put credentials or session data in the repository, shell history, logs, qmd indexes, tests, or agent customization files. See [SECURITY.md](SECURITY.md) and [docs/threat-model.md](docs/threat-model.md).

## Change conventions

Prefer existing Bash and Python standard-library patterns. Preserve public command-line flags and compatibility adapters unless the task explicitly changes them. When changing a bootstrap stage, update its nearby tests and the relevant operational documentation. Treat `bootstrap/stage-manifest.yaml` as descriptive metadata, not executable input.

Before proposing a live-install change, consult [docs/production-runbook.md](docs/production-runbook.md), [docs/service-account-policy.md](docs/service-account-policy.md), and [docs/threat-model.md](docs/threat-model.md). Review [tests/test_bootstrap_scripts.py](tests/test_bootstrap_scripts.py) and [tests/test_security.py](tests/test_security.py) for executable expectations.

