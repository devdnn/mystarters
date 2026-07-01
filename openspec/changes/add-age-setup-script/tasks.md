## 1. Environment Setup

- [x] 1.1 Add OS detection and `age` presence checks (depends on nothing; blocks 2.1)
- [x] 1.2 Add macOS Homebrew install path and Debian `apt` install path (depends on 1.1; blocks 2.2)
- [x] 1.3 Add `~/.config/age` directory creation and permission handling (depends on 1.1; blocks 2.1, 2.2)

## 2. Key Management

- [x] 2.1 Prompt for purpose and sanitize it into a filesystem-safe key filename (depends on 1.3; blocks 2.2, 3.1)
- [x] 2.2 Reuse an existing purpose key or create a new key in `~/.config/age` (depends on 2.1, 1.2, 1.3; blocks 3.1)

## 3. User Guidance

- [x] 3.1 Print the resolved key path, public key, and sample encrypt/decrypt commands (depends on 2.2; blocks none)

## 4. Verification

- [x] 4.1 Verify rerun behavior reuses an existing purpose key (depends on 2.2; blocks none)
- [x] 4.2 Verify macOS and Debian install paths do not run when `age` is already installed (depends on 1.1, 1.2; blocks none)
- [x] 4.3 Verify the printed example commands use the resolved key path and public key (depends on 3.1; blocks none)

## Dependency Graph

- `1.1` blocks `1.2`, `1.3`
- `1.2` blocks `2.2`, `4.2`
- `1.3` blocks `2.1`, `2.2`
- `2.1` blocks `2.2`, `3.1`
- `2.2` blocks `3.1`, `4.1`, `4.3`
- `3.1` blocks `4.3`

## Parallelizable Work

- `4.1`, `4.2`, and `4.3` can run in parallel after their dependencies are met.
