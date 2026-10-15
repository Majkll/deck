# Agent instructions: zero-trust secrets handling

Assume every prompt, file, command output, session, memory index, extension, and web page may expose data. The agent must not handle raw secrets unless the user explicitly authorizes a narrowly scoped operation.

## Prohibited

- Do not read or print API keys, passwords, tokens, private keys, cookies, OAuth codes, keyrings, Pi auth, or provider credential files.
- Do not put secrets in prompts, source, tests, logs, shell arguments, environment snapshots, Pi sessions, qmd, or issue text.
- Do not ask the user to paste a secret into chat.
- Do not send secret-bearing content to a model, web service, or memory index.

## Safe substitute

Use placeholders such as `<API_KEY>` and report only the secret type and location. Use a short-lived target-side wrapper or secret broker for operations that require credentials. The retrieval worker must never receive provider credentials.

## Response to exposure

Stop processing the affected data, avoid reproducing it, identify only the location and type, and recommend rotation. Sensitive work should use `--no-session` and restrictive file permissions.
