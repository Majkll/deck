# Service account policy guide

This guide is intentionally small and production-oriented. The bootstrap applies this policy when it provisions the target service account.

## Principles

- do not run privileged services as the interactive user
- use one dedicated service account per runtime responsibility
- keep service accounts with the minimum set of filesystem and network privileges
- isolate the service account from the user session, secrets, qmd indexes, and SSH material
- prefer read-only access to local state whenever possible

## Default practice

Use a dedicated account such as `pi-safe-fetch` for fetch or network-facing tasks, and make sure it cannot read:

- user SSH keys
- provider credentials
- qmd indexes
- session files
- other unrelated home directories

## Operational checklist

- create a dedicated group and service account
- set the home directory to a minimal non-user path or `/nonexistent`
- set the account shell to `/usr/sbin/nologin` when possible
- bind the service to its own dedicated working directory
- keep policy files outside ordinary user-writable paths
- review logs and retention settings separately from the main agent workspace

The default bootstrap creates `pi-safe-fetch` as a system account and group with `/var/lib/pi-safe-fetch` as its private working directory, `/usr/sbin/nologin` as its shell, a locked password, and no supplementary groups. Existing accounts with conflicting settings are rejected rather than rewritten.

## Safety rule

If a service needs broader access, document why and keep the scope explicit. Do not expand access just because a tool needs it.
