#!/bin/bash
set +e

detect_os() {
    case "$(uname -s)" in
        Linux*)     OS=Linux;;
        Darwin*)    OS=macOS;;
        MINGW*)     OS=WSL;;
        *)          OS=Unknown;;
    esac
    echo "$OS"
}

OS=$(detect_os)
echo "=== Tool Installer ($(date)) ==="
echo "Detected OS: $OS"

# ── 1. System Essentials ──────────────────────────────────────────────────────
echo ""
echo "=== [1/4] System Essentials ==="

if [ "$OS" = "macOS" ]; then
    if ! command -v git &>/dev/null; then
        echo "[INSTALL] git..."
        brew install git
    else
        echo "[SKIP] git already installed"
    fi
    if ! command -v curl &>/dev/null; then
        echo "[INSTALL] curl..."
        brew install curl
    else
        echo "[SKIP] curl already installed"
    fi
else
    # Linux / WSL
    echo "[INSTALL] apt packages (ca-certificates, curl, git, build-essential)..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl git build-essential > /dev/null 2>&1
    echo "[DONE] System essentials installed"
fi

# ── 2. Node.js via nvm ────────────────────────────────────────────────────────
echo ""
echo "=== [2/4] Node.js (via nvm) ==="

export NVM_DIR="$HOME/.nvm"
nvm_loaded=false

if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
    nvm_loaded=true
fi

if ! command -v node &>/dev/null; then
    echo "[INSTALL] Node.js via nvm..."
    if [ ! -d "$NVM_DIR" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash > /dev/null 2>&1
    fi
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        # shellcheck disable=SC1091
        . "$NVM_DIR/nvm.sh"
        nvm_loaded=true
    fi
    nvm install --lts > /dev/null 2>&1
    nvm alias default lts/* > /dev/null 2>&1
    echo "[DONE] Node.js installed via nvm"
else
    echo "[SKIP] Node.js already installed ($(node -v))"
fi

if $nvm_loaded && [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
fi

# npm packages
echo ""
echo "=== [2/4] npm packages ==="

if command -v npm &>/dev/null; then
    for pkg in opencode-ai @fission-ai/openspec@latest; do
        if npm list -g "$pkg" &>/dev/null; then
            echo "[SKIP] $pkg already installed"
        else
            echo "[INSTALL] $pkg..."
            npm install -g "$pkg" 2>/dev/null
        fi
    done
else
    echo "[SKIP] npm not available, skipping npm packages"
fi

# ── 3. PowerShell ─────────────────────────────────────────────────────────────
echo ""
echo "=== [3/4] PowerShell ==="

if command -v pwsh &>/dev/null; then
    echo "[SKIP] PowerShell already installed ($(pwsh --version))"
else
    if [ "$OS" = "macOS" ]; then
        echo "[INSTALL] PowerShell via Homebrew..."
        brew install powershell > /dev/null 2>&1
        echo "[DONE] PowerShell installed"
    else
        # Linux / WSL - install from Microsoft repo
        echo "[INSTALL] PowerShell via Microsoft apt repo..."
        if [ ! -f /etc/apt/trusted.gpg.d/microsoft.gpg ]; then
            curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg
        fi
        if [ ! -f /etc/apt/sources.list.d/microsoft.list ]; then
            curl -fsSL https://packages.microsoft.com/config/debian/12/prod.list | tee /etc/apt/sources.list.d/microsoft.list
        fi
        apt-get update -qq
        apt-get install -y -qq powershell > /dev/null 2>&1
        echo "[DONE] PowerShell installed"
    fi
fi

# ── 4. Zsh ─────────────────────────────────────────────────────────────────────
echo ""
echo "=== [4/4] Zsh ==="

if command -v zsh &>/dev/null; then
    echo "[SKIP] Zsh already installed ($(zsh --version))"
else
    if [ "$OS" = "macOS" ]; then
        echo "[INSTALL] Zsh via Homebrew..."
        brew install zsh > /dev/null 2>&1
        echo "[DONE] Zsh installed"
    else
        echo "[INSTALL] Zsh via apt..."
        apt-get update -qq
        apt-get install -y -qq zsh > /dev/null 2>&1
        echo "[DONE] Zsh installed"
    fi
fi

echo ""
echo "=== Install complete! ==="
echo "Run 'zsh' to start zsh, 'pwsh' for PowerShell"
