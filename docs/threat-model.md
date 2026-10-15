# Threat model

## Assets

- Provider credentials and OAuth tokens
- Pi session JSONL and qmd indexes
- Workspace files outside the intended project
- Agent context and model requests
- Raspberry Pi operating system and user account

## Threats

- Prompt injection in web pages, repository files, command output, or memory
- Secret exfiltration through tool output, URLs, logs, sessions, or qmd
- Shell metacharacter and path traversal bypasses
- SSRF through redirects or DNS resolution
- Resource exhaustion through large, compressed, or repeated content
- Malicious project-local Pi extensions and packages

## Controls

- Allowlisted commands and protected canonical paths
- Separate handling for model bash and user `!`/`!!` commands
- HTTPS-only, allowlisted, bounded retrieval with public-IP checks
- HTML active-content removal and deterministic secret redaction
- Sanitization at fetch, tool-result, context, compaction, and qmd boundaries
- Low-privilege retrieval service with minimal environment and filesystem access
- Short-lived secret injection outside the retrieval process
- Read-only and no-session launch presets

## Trust boundaries

The Pi process and its extensions run with the launcher user's permissions. The TypeScript extension is not a sandbox. The retrieval worker and its systemd/container boundary are the security boundary. The agent must treat every fetched or indexed string as untrusted data, even after sanitization.

## Target-side checks

On Debian Trixie, the operator must verify the dedicated service account, `ProtectHome`, `NoNewPrivileges`, `PrivateTmp`, read-only paths, network egress restrictions, DNS behavior, and `systemd-analyze security`. These checks cannot be performed from this development machine.
