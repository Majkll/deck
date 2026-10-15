# FlipperZero BadUSB payload notes

This directory holds the payload-generation workflow for the FlipperZero deployment mode.

## Design intent

The Flipper payload is not a separate implementation of the bootstrap. It is a transport adapter around the same centralized stage pipeline and the same flavor model.

## Safety posture

- review the generated payload before use
- keep the target environment under operator control
- never transmit secrets or provider credentials through the payload
- prefer a dry-run review before physical execution
