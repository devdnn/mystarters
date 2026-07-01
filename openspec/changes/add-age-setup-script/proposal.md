## Why

We need a simple, repeatable way to bootstrap `age` keys for local encryption workflows without asking users to remember install steps or key locations. This helps standardize secret handling across machines and makes it easier to create and reuse purpose-specific keys.

## What Changes

- Add `scripts/utils/age-setup.sh` to detect whether `age` is installed and install it when missing.
- Support macOS installation via Homebrew and Debian/Ubuntu installation via `apt`.
- Prompt the user for a purpose and use it to name the key file.
- Reuse an existing key for the same purpose instead of generating a new one.
- Store keys under `~/.config/age`.
- Print the key file path, public key, and sample encrypt/decrypt commands after setup.

## Functional Requirements

- The script MUST install `age` if it is not already available.
- The script MUST support macOS and Debian-based Linux.
- The script MUST prompt for a purpose and derive a stable purpose-based key filename.
- The script MUST reuse an existing key file for the same purpose.
- The script MUST output the private key path and the public key.
- The script MUST show example commands for encrypting and decrypting a demo file.

## Non-Functional Requirements

- Key material MUST be stored in `~/.config/age` with restricted permissions.
- The script SHOULD be safe to re-run without creating duplicate keys for the same purpose.
- The UX SHOULD be clear enough for first-time `age` users.

## Non-goals

- Supporting every Linux distribution package manager.
- Managing shared/team key distribution.
- Encrypting application data automatically.
- Rotating existing keys.

## Capabilities

### New Capabilities
- `age-key-setup`: Install `age`, create or reuse a purpose-specific key, and print usage examples.

### Modified Capabilities
- None.

## Impact

- Adds a new setup script under `scripts/utils/`.
- Introduces a dependency on `age` and package installation paths for macOS and Debian/Ubuntu.
- Establishes a standard local key storage convention at `~/.config/age`.
- Improves onboarding for workflows that use `age` for file encryption.

## Rollback Plan

- Remove or disable the `age-setup.sh` script.
- Delete any generated key files under `~/.config/age` if needed.
- No application code changes are required, so rollback is limited to the script and generated keys.
