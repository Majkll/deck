# Deployment adapters

This directory holds the concrete deployment adapters for the phase-based bootstrap pipeline.

## Bash adapter

Runs the standard bootstrap flow directly on a target Raspberry Pi through `install-target.sh` or `bootstrap/bootstrap.sh`.

## Flipper adapter

Generates a payload-friendly version using the same stage registry and stage logic as the Bash path.

## Docker adapter

Builds a containerized validation environment for the same logical stages.
