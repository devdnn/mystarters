## Context

`age-setup.sh` is currently empty, so there is no standard way to provision an `age` identity for local encryption workflows. The change adds a small bootstrap script that detects the OS, installs `age` when needed, and manages purpose-based keys under `~/.config/age`.

## Goals / Non-Goals

**Goals:**
- Provide a repeatable way to create or reuse an `age` key by purpose.
- Support macOS via Homebrew and Debian-based Linux via `apt`.
- Keep the private key in a predictable local directory with safe permissions.
- Print copy-paste-ready encrypt/decrypt examples.

**Non-Goals:**
- Supporting all Linux package managers.
- Key rotation, syncing, or multi-user key sharing.
- Building a broader secrets management system.

## Decisions

- **Purpose-based filename**: store keys as `~/.config/age/<purpose>.key`.
  - Rationale: makes reuse deterministic and keeps keys easy to discover.
  - Alternatives considered: a single fixed key file, or a timestamped key store. Both make reuse less obvious.

- **Install only when missing**: check `command -v age` before installing.
  - Rationale: avoids unnecessary package manager calls and makes reruns fast.
  - Alternatives considered: always install/update. Rejected because it is slower and more intrusive.

- **OS-specific package path**: Homebrew on macOS, `apt` on Debian/Ubuntu.
  - Rationale: matches the requested support scope and avoids overengineering distro detection.
  - Alternatives considered: broader package manager abstraction. Rejected for this change.

- **Reusable key creation**: if the purpose-specific key exists, do not regenerate it.
  - Rationale: preserves established encryption identity for that purpose.
  - Alternatives considered: append a version suffix or always create new keys. Rejected because they complicate day-to-day usage.

- **User-facing usage examples**: print one encryption and one decryption example after completion.
  - Rationale: helps first-time users adopt the tool without consulting documentation.
  - Alternatives considered: just print the key path/public key. Rejected because it leaves the workflow incomplete.

## Risks / Trade-offs

- [Risk] Purpose names may contain spaces or special characters → [Mitigation] sanitize input into a filesystem-safe slug before deriving the filename.
- [Risk] Missing package-manager permissions on Linux → [Mitigation] fail with a clear message if `apt` install requires sudo and cannot proceed.
- [Risk] Existing keys might be accidentally shadowed by a changed purpose string → [Mitigation] use a stable sanitization rule and print the resolved path every run.
- [Risk] Printing the public key and example commands may be confusing to beginners → [Mitigation] keep the examples short and label them clearly.

## Migration Plan

1. Add the script without changing other automation.
2. Verify installation and key creation on macOS and Debian-based Linux.
3. Document or reference the new workflow where needed.
4. Roll back by removing the script if the UX or package assumptions prove incorrect.

## Open Questions

- Should the script accept a non-interactive purpose flag later?
- Should it warn when the purpose already exists rather than silently reusing the key?
