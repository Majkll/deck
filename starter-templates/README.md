# Starter templates

These files are examples only. This folder is intentionally separate from the install package and is not copied by `install-target.sh`.

Copy one template into a target project as `AGENTS.md`, or adapt it into the corresponding Pi `AGENTS.md`, `SYSTEM.md`, skill, prompt, or VS Code instruction file. Review every rule against the project before enabling it.

## Pairs

| Topic | Conservative version | Alternative version |
| --- | --- | --- |
| General project work | `AGENTS-general-conservative.md` | `AGENTS-general-pragmatic.md` |
| Review and inspection | `AGENTS-review-readonly.md` | `AGENTS-review-with-tests.md` |
| Web research | `AGENTS-web-research-sandboxed.md` | `AGENTS-web-research-proxy.md` |
| Secrets and sensitive files | `AGENTS-secrets-zero-trust.md` | `AGENTS-secrets-brokered.md` |

The conservative versions prioritize denial and explicit human review. The alternatives show how to allow more automation while keeping boundaries, logging, and redaction explicit.

## Safe use

- Do not put API keys, passwords, tokens, private keys, session contents, or real host paths into these examples.
- An `AGENTS.md` file guides an agent; it does not enforce a security boundary. Use the Pi security extension and OS-level isolation for enforcement.
- Keep project-local instructions untrusted until the project has been reviewed and approved.
- Replace placeholders such as `<workspace>` and `<approved-domain>` before use.
- Test the resulting policy in a disposable project with `--no-session` before using it on sensitive work.
- Prefer specific, short instructions over a large universal file. Put deterministic blocking in hooks, wrappers, or sandbox policy.
