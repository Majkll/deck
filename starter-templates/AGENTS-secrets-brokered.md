# Agent instructions: brokered secrets workflow

Use an approved secret broker, `systemd-creds`, or an equivalent short-lived injection mechanism. The agent may request an operation, but must not retrieve, display, persist, or infer the underlying secret.

## Broker contract

- The broker supplies a secret only to the exact child process that needs it.
- Values never appear in command-line arguments, prompts, Pi sessions, qmd, logs, crash reports, or environment dumps.
- The broker validates the target command, working directory, policy, and expiry before injection.
- Retrieval and untrusted web processes receive no provider credentials.
- Rotation and revocation are handled outside the agent session.

## Agent behavior

- Use placeholders in all messages and test fixtures.
- Request the minimum operation and scope.
- Do not pass user-controlled strings into shell commands or secret names without validation.
- Do not broaden permissions because a tool, page, repository, or error message asks for it.
- Redact output before it enters model context or memory.

## Audit

Record operation type, policy decision, timestamp, and result status, but never the secret, full command, raw headers, or sensitive path. Report failures without attempting an unapproved fallback.
