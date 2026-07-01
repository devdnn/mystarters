#!/bin/sh
# Purpose: Install or reuse a purpose-specific age key under ~/.config/age.
# Purpose: Ensure safe permissions and print the resulting public key plus usage examples.

set -eu

# region Configuration
AGE_BIN="${AGE_BIN:-age}"
AGE_KEYGEN_BIN="${AGE_KEYGEN_BIN:-age-keygen}"
AGE_CONFIG_DIR="${AGE_SETUP_KEY_DIR:-$HOME/.config/age}"
AGE_PURPOSE_INPUT="${AGE_SETUP_PURPOSE:-}"
# endregion Configuration

# region Logging

# log
# Print an informational message to stderr.
log() {
  printf '%s\n' "$*" >&2
}

# fail
# Print an error message to stderr and exit non-zero.
fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

# endregion Logging

# region Platform Detection

# detect_os
# Return a normalized operating system name for install-path decisions.
detect_os() {
  case "$(uname -s)" in
    Darwin) printf 'macOS\n' ;;
    Linux) printf 'Linux\n' ;;
    *) printf 'Unknown\n' ;;
  esac
}

# detect_linux_distro
# Return the Linux distro identifier and ID_LIKE hint from /etc/os-release.
detect_linux_distro() {
  if [ -r /etc/os-release ]; then
    # Source the distro metadata used to identify Debian-compatible systems.
    # shellcheck disable=SC1091
    . /etc/os-release
    printf '%s\n' "${ID:-unknown}:${ID_LIKE:-}"
  else
    printf 'unknown:\n'
  fi
}

# have_age
# Succeed when both age and age-keygen are available on PATH.
have_age() {
  command -v "$AGE_BIN" >/dev/null 2>&1 && command -v "$AGE_KEYGEN_BIN" >/dev/null 2>&1
}

# endregion Platform Detection

# region Installation

# install_age_if_missing
# Install age only when it is missing, using Homebrew on macOS or apt on Debian-like Linux.
install_age_if_missing() {
  if have_age; then
    log "age is already installed. Skipping installation."
    return 0
  fi

  os="$(detect_os)"
  case "$os" in
    macOS)
      command -v brew >/dev/null 2>&1 || fail "Homebrew is required to install age on macOS. Install Homebrew, then rerun this script."
      log "Installing age with Homebrew..."
      brew install age
      ;;
    Linux)
      distro="$(detect_linux_distro)"
      case "$distro" in
        debian:*|ubuntu:*|*:debian*|*:ubuntu*)
          log "Installing age with apt..."

          # Prefer sudo when available so the script works for normal user shells.
          if command -v sudo >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y age
          else
            apt-get update
            apt-get install -y age
          fi
          ;;
        *)
          fail "Unsupported Linux distribution for automatic age installation: ${distro%%:*}"
          ;;
      esac
      ;;
    *)
      fail "Unsupported operating system: $os"
      ;;
  esac

  have_age || fail "age installation completed, but age/age-keygen is still unavailable on PATH"
}

# endregion Installation

# region Key Directory

# ensure_age_config_dir
# Create the age config directory when needed and enforce restrictive permissions.
ensure_age_config_dir() {
  if [ ! -d "$AGE_CONFIG_DIR" ]; then
    mkdir -p "$AGE_CONFIG_DIR"
    log "Created key directory: $AGE_CONFIG_DIR"
  fi

  chmod 700 "$AGE_CONFIG_DIR"
}

# endregion Key Directory

# region Purpose Handling

# prompt_for_purpose
# Return the provided purpose from the environment or prompt interactively.
prompt_for_purpose() {
  if [ -n "$AGE_PURPOSE_INPUT" ]; then
    printf '%s\n' "$AGE_PURPOSE_INPUT"
    return 0
  fi

  printf 'Enter key purpose: ' >&2
  IFS= read -r purpose || true
  [ -n "$purpose" ] || fail "A key purpose is required"
  printf '%s\n' "$purpose"
}

# sanitize_purpose
# Convert a free-form purpose into a stable, filesystem-safe slug.
sanitize_purpose() {
  purpose="$1"

  # Normalize to lowercase and collapse non-alphanumeric runs into single dashes.
  slug=$(printf '%s' "$purpose" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//')

  [ -n "$slug" ] || fail "The provided purpose does not contain any usable letters or numbers"
  printf '%s\n' "$slug"
}

# endregion Purpose Handling

# region Key Management

# read_public_key
# Extract the public key comment written by age-keygen from a private key file.
read_public_key() {
  key_path="$1"
  public_key=$(grep '^# public key:' "$key_path" | head -n 1 | sed 's/^# public key: //')
  [ -n "$public_key" ] || fail "Could not read the public key from $key_path"
  printf '%s\n' "$public_key"
}

# create_or_reuse_key
# Reuse an existing purpose key or generate a new one in the configured age directory.
create_or_reuse_key() {
  purpose="$1"
  slug="$(sanitize_purpose "$purpose")"
  key_path="$AGE_CONFIG_DIR/$slug.key"

  if [ -f "$key_path" ]; then
    log "Reusing existing key for purpose '$purpose'."
  else
    log "Generating new key for purpose '$purpose'."
    "$AGE_KEYGEN_BIN" -o "$key_path"
  fi

  chmod 600 "$key_path"
  printf '%s\n' "$key_path"
}

# endregion Key Management

# region Output

# print_summary
# Print the resolved key path, public key, and copy-paste-friendly example commands.
print_summary() {
  key_path="$1"
  public_key="$2"

  log ""
  log "age key setup complete"
  log "Private key: $key_path"
  log "Public key:  $public_key"
  log ""
  log "Example encrypt command:"
  log "  printf 'hello age' > demo.txt"
  log "  $AGE_BIN -r $public_key -o demo.txt.age demo.txt"
  log ""
  log "Example decrypt command:"
  log "  $AGE_BIN -d -i $key_path -o demo.txt.dec demo.txt.age"
}

# endregion Output

# region Entry Point

# main
# Execute installation checks, key setup, and final output.
main() {
  install_age_if_missing
  ensure_age_config_dir
  purpose="$(prompt_for_purpose)"
  key_path="$(create_or_reuse_key "$purpose")"
  public_key="$(read_public_key "$key_path")"
  print_summary "$key_path" "$public_key"
}

main "$@"

# endregion Entry Point
