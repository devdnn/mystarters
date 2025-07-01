#!/bin/sh

# -e: exit on error
# -u: exit on unset variables
set -eu

# Accept values from environment or default to empty
LASTPASS_LOGIN_USER="${LASTPASS_LOGIN_USER:-deepakn.dev@gmail.com}"
SSH_KEY_PREFIX="${SSH_KEY_PREFIX:-ssh_personal_github_ed25519}"
DOTFILES_REPO_COMPLETE_URL="${DOTFILES_REPO_COMPLETE_URL:-git@github.com:devdnn/dotfiles.git}"

# Detect OS
OS="$(uname -s)"
DISTRO=""
if [ "${OS}" = "Linux" ] && [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  DISTRO="${ID:-unknown}"
fi

# Color codes for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo "${YELLOW}ℹ️ [INFO] $*${NC}"; }
log_success() { echo "${GREEN}✅ [SUCCESS] $*${NC}"; }
log_error() { echo "${RED}❌ [ERROR] $*${NC}"; }

# log the login user and ssh key prefix
log_info "Login User: ${LASTPASS_LOGIN_USER:-<not set>}"
log_info "GitHub SSH Key Prefix: ${SSH_KEY_PREFIX:-<not set>}"

if [ "${OS}" = "Linux" ] && { [ "${DISTRO}" = "debian" ] || [ "${DISTRO}" = "ubuntu" ]; }; then
  if ! command -v lpass >/dev/null 2>&1; then
    log_info "Installing lastpass-cli on ${DISTRO}..."
    sudo apt-get update
    if sudo apt-get install -y lastpass-cli; then
      log_success "lastpass-cli installed."
    else
      log_error "Failed to install lastpass-cli."
    fi

  else
    log_success "lastpass-cli already installed."
  fi
fi

if [ "${OS}" = "Darwin" ]; then
  if ! command -v brew >/dev/null 2>&1; then
    log_info "Homebrew is not installed. Installing Homebrew..."

    log_info "📥 Downloading Homebrew install script to /tmp..."

    TEMP_SCRIPT="/tmp/install_homebrew.sh"

    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "${TEMP_SCRIPT}" || {
      log_error "Failed to download Homebrew install script"
      exit 1
    }

    log_info "🚀 Running Homebrew installer..."
    /bin/bash "${TEMP_SCRIPT}"

    log_info "🧹 Cleaning up..."
    rm -f "${TEMP_SCRIPT}"

    log_success "✅ Homebrew installation complete!"

    BREW_PREFIX="$(brew --prefix)"
    BREW_ENV="$("${BREW_PREFIX}/bin/brew" shellenv)" || {
      log_error "Failed to get Homebrew shell environment"
      exit 1
    }

    eval "${BREW_ENV}"

    log_success "Homebrew installed."
  fi

  # After Homebrew is installed, check/install lpass-cli
  if ! brew list lastpass-cli >/dev/null 2>&1; then
    log_info "Installing lastpass-cli with Homebrew..."
    if brew install lastpass-cli; then
      log_success "lastpass-cli installed."
    else
      log_error "Failed to install lastpass-cli."
    fi
  else
    log_success "lastpass-cli already installed."
  fi
fi

# login to LastPass using environment variables
if [ -n "${LASTPASS_LOGIN_USER}" ]; then
  log_info "Logging into LastPass..."
  mkdir -p ~/.config/lpass
  lpass login --trust "${LASTPASS_LOGIN_USER}"
  log_info "Logged into LastPass as ${LASTPASS_LOGIN_USER}."
fi

# private key from LastPass
if [ -n "${SSH_KEY_PREFIX}" ]; then
  log_info "Retrieving GitHub SSH key from LastPass..."
  SSH_KEY_PREFIX_CONTENT=$(lpass show --notes "${SSH_KEY_PREFIX}" || log_error "Failed to retrieve GitHub SSH key.")

  if [ -z "${SSH_KEY_PREFIX_CONTENT}" ]; then
    log_error "GitHub SSH key content is empty."
  else
    # Create the .ssh directory if it doesn't exist
    mkdir -p ~/.ssh
    echo "${SSH_KEY_PREFIX_CONTENT}" >~/.ssh/"${SSH_KEY_PREFIX}"
    chmod 600 ~/.ssh/"${SSH_KEY_PREFIX}"
    log_success "GitHub SSH key saved to ~/.ssh/${SSH_KEY_PREFIX}."
  fi
else
  log_error "SSH_KEY_PREFIX environment variable is not set."
fi

# check if git is installed, install if not
if ! command -v git >/dev/null; then
  log_info "Git is not installed. Installing git..." >&2
  if command -v apt-get >/dev/null; then
    sudo apt-get update && sudo apt-get install -y git
    log_success "Git installed."
  fi
fi

if ! chezmoi="$(command -v chezmoi)"; then
  bin_dir="/usr/local/bin"
  chezmoi="${bin_dir}/chezmoi"
  echo "Installing chezmoi system-wide to '${chezmoi}'" >&2
  if command -v curl >/dev/null; then
    chezmoi_install_script="$(curl -fsSL https://chezmoi.io/get)"
  elif command -v wget >/dev/null; then
    chezmoi_install_script="$(wget -qO- https://chezmoi.io/get)"
  else
    echo "To install chezmoi, you must have curl or wget installed." >&2
    exit 1
  fi
  echo "${chezmoi_install_script}" | sudo sh -s -- -b "${bin_dir}"
  unset chezmoi_install_script bin_dir
fi

# Add the SSH key to the ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/"${SSH_KEY_PREFIX}"

set -- init --apply "${DOTFILES_REPO_COMPLETE_URL}"

echo "Running 'chezmoi $*'" >&2

# exec: replace current process with chezmoi
exec "${chezmoi}" "$@"
