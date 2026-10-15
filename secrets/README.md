# Secret handling

Secrets are never committed to the repository, never stored in AGENTS files, and never written to qmd or logs.

## Allowed patterns

- OS-managed secret stores
- runtime environment injection
- mounted secret files with strict permissions
- systemd credentials or equivalent host-managed secret delivery

## Forbidden patterns

- plaintext values in project files
- shell arguments containing provider keys
- prompt text containing credentials
- session dumps with provider material
- qmd ingestion of unredacted secret-bearing content

## Default security posture

All runtime components must fail closed if a secret is missing or a secret path is invalid.
