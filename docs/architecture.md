# Pi harness bootstrap architecture

This repository is being refactored around a deterministic, multi-stage Raspberry Pi bootstrap instead of a single-purpose security package.

## Layers

### 1. Bootstrap layer

The bootstrap layer defines the repeatable installation stages and the required software manifest. The stage scripts live in `bootstrap/` and are designed to be run on a fresh Debian Trixie installation.

### 2. Daily-driver layer

A common personal-butler baseline is shared by both flavors. This layer is intentionally conservative and privacy-aware. The daily-driver is the system default for a user who wants a helpful assistant without the more specialist behavior of the research or hacker profile.

### 3. Flavor layer

Two flavors are supported:

- sysadmin / hacker / hardware-software designer
- scientific / research / LaTeX / article workflow

Both share the same daily-driver baseline and the same security defaults, but diverge once the persona-selection step is complete.

### 4. Runtime support layer

The runtime support layer keeps the working security controls already present in this repository, including:

- command and path policy
- sanitization
- fetch safety
- qmd ingestion wrapper
- verification wizard

This layer is not the whole project anymore; it is a subsystem that the agent runtime depends on.

## Deployment modes

- bash: direct installation on the device
- flipper: same stage logic in a FlipperZero payload-friendly layout
- docker: deterministic staging environment for validation and lab reproduction

## Secret model

Secrets are never stored in the repo, shell history, qmd, or logs. They must be externalized and injected only at runtime through OS-managed mechanisms or explicit runtime mounts.

## Memory model

The memory system combines:

- qmd-backed pi-memory
- Karpathy-style LLM wiki

The point is to keep durable context while preserving privacy and explicit retention controls.
