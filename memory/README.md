# Memory layer

The memory layer combines qmd-backed memory (`pi-memory`) and a Karpathy-style LLM wiki with deterministic local indexing and clear retention boundaries.

## Goals

- preserve durable context without exposing secrets in the repo
- keep the memory layer reviewable and bounded
- allow both the daily-driver and the special agent to use the same local memory backbone

## Default expectations

- qmd indexes live outside ordinary agent-readable directories
- wiki content is versioned and curated
- prompts and retrievals are sanitized before ingestion
- all memory writes remain subject to the security policy
