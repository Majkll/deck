# Production runbook

This runbook is for the operator who has reviewed the target, confirmed the recovery plan, and is ready to proceed with a live installation. The live pipeline requires sudo authentication and explicit `--approve` before it mutates the target.

## Preconditions

Before running the real bootstrap on the target Pi, confirm all of the following:

- the target is the correct machine and is not a shared or disposable system unless that is the intent
- the allowlist values to enter interactively during stage 03 are known and reviewed
- the service-account policy in docs/service-account-policy.md is understood and accepted
- a backup or recovery plan exists for the target state
- the operator has reviewed the bootstrapping log location and knows how to inspect it later

## Choose an entrypoint

After the Raspberry Pi OS netinstaller has completed, choose either an existing local checkout:

```bash
cd ~/WorkspacePi
./install-target.sh --mode bash --flavor sysadmin --approve
```

or the fetch-and-delegate entrypoint:

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/REPOSITORY/main/bootstrap/install-from-source.sh | \
bash -s -- \
	--repository-url https://github.com/OWNER/REPOSITORY.git \
	--mode bash \
	--flavor sysadmin \
	--approve
```

Replace `OWNER/REPOSITORY` with the actual GitHub owner and repository. The fetcher only acquires this repository and delegates to its normal installer. Raspberry Pi OS netinstall, SD-card removal, and operating-system replacement remain manual steps outside WorkspacePi.

The commands above are the live entrypoints and require explicit approval. Stage 03 will ask for exact HTTPS hostnames, display the proposed allowlist, and require confirmation.

```bash
cd ~/WorkspacePi
./bootstrap/bootstrap.sh --mode bash --flavor sysadmin --approve
```

The pipeline creates `pi-safe-fetch` with `/usr/sbin/nologin`, deploys the policy and runtime under `/etc/pi-security` and `/opt/pi-security`, installs the socket and service units, and leaves socket activation disabled.

A dry run is recommended before the first live execution:

```bash
cd ~/WorkspacePi
./bootstrap/bootstrap.sh --mode bash --flavor sysadmin --dry-run --approve
```

## Evidence to collect after the run

After the bootstrap completes, inspect the consolidated log file:

```bash
tail -n 50 ~/.local/share/pi-harness/bootstrap.log
```

A healthy run should end with a line similar to:

```text
2026-09-19T18:52:49Z | bootstrap complete mode=bash flavor=sysadmin
```

The log should show every stage moving from start to complete, without any FAIL or missing-stage entry.

## Stop conditions

Stop immediately and investigate if any of the following appear:

- a missing stage file
- a FAIL line in the stage output or log
- an empty or unreviewed allowlist entered during stage 03
- a service-account or privilege model that is wider than the stated requirement
- no recovery or rollback plan for the target machine

## Operator sign-off

The final sign-off should include:

- target identity
- flavor selected
- policy allowlist reviewed
- service account pattern approved
- backup plan confirmed
- bootstrap log reviewed
- systemd socket reviewed before enabling

Only then should the live target be considered production-ready for daily use.
