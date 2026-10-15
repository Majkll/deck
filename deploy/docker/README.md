# Docker mode

This directory contains the deterministic Docker-based validation mode for the Pi harness bootstrap.

## Purpose

- validate the same stage logic in a clean, reproducible environment
- exercise the bootstrap without affecting a real Pi target
- support lab testing, soak tests, and operator review before on-device install

## Safety posture

- no secrets in the image
- no provider credentials or host IDs baked into the image
- environment variables are expected to be injected externally
