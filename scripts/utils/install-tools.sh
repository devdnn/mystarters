#!/bin/bash

# Check if running with set +e - warn but don't change behavior to preserve backward compat
if [[ "$-" == *"e"* ]]; then
    SET_E_WAS_ON=true
else
    SET_E_WAS_ON=false
fi

failures=0

track_failure() {
    failures=$((failures + 1))
}

report_failure() {
    local cmd="$1"
    local exit_code="$2"
    echo "[FAIL] Command failed: $cmd (exit code: $exit_code)"
    track_failure
}

check_command() {
    local cmd="$1"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        report_failure "$cmd" $exit_code
        return 1
    fi
    return 0
}

#region Script Header

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

if [ "$OS" = "Unknown" ]; then
    echo "[WARN] Unknown OS detected. Some features may not work."
fi

#endregion

#region System Essentials

echo ""
echo "=== [1/4] System Essentials ==="

SUDO_CMD=""
[ "$USE_SUDO" = "1" ] && SUDO_CMD="sudo"

if [ "$OS" = "macOS" ]; then
    if ! command -v git &>/dev/null; then
        echo "[INSTALL] git..."
        if ! brew install git; then
            report_failure "brew install git" $?
        fi
    else
        echo "[SKIP] git already installed"
    fi
    if ! command -v curl &>/dev/null; then
        echo "[INSTALL] curl..."
        if ! brew install curl; then
            report_failure "brew install curl" $?
        fi
    else
        echo "[SKIP] curl already installed"
    fi
else
    echo "[INSTALL] apt packages (ca-certificates, curl, git, build-essential)..."
    export DEBIAN_FRONTEND=noninteractive
    $SUDO_CMD apt-get update -qq 2>&1 | grep -E "^(E:|W:)" || true
    if ! $SUDO_CMD apt-get install -y -qq ca-certificates curl git gpg build-essential; then
        report_failure "apt-get install essentials" $?
    else
        echo "[DONE] System essentials installed"
    fi
fi

if ! command -v git &>/dev/null; then
    echo "[WARN] git not available after installation"
    track_failure
fi
if ! command -v curl &>/dev/null; then
    echo "[WARN] curl not available after installation"
    track_failure
fi

#endregion

#region Zsh

echo ""
echo "=== [2/4] Zsh ==="

zsh_installed=false

if command -v zsh &>/dev/null; then
    echo "[SKIP] Zsh already installed ($(zsh --version))"
else
    if [ "$OS" = "macOS" ]; then
        echo "[INSTALL] Zsh via Homebrew..."
        if brew install zsh 2>&1 | grep -E "^Error:"; then
            report_failure "brew install zsh" $?
        else
            zsh_installed=true
            echo "[DONE] Zsh installed"
        fi
    else
        echo "[INSTALL] Zsh via apt..."
        $SUDO_CMD apt-get update -qq 2>&1 | grep -E "^(E:|W:)" || true
        if $SUDO_CMD apt-get install -y -qq zsh 2>&1 | grep -E "^(E:|W:)"; then
            report_failure "apt-get install zsh" $?
        else
            zsh_installed=true
            echo "[DONE] Zsh installed"
        fi
    fi
fi

if [ "$OS" = "Linux" ] && command -v zsh &>/dev/null; then
    echo "[INFO] Setting zsh as default shell..."
    if $SUDO_CMD chsh -s "$(command -v zsh)" "$USER" 2>/dev/null; then
        echo "[DONE] Default shell changed to zsh"
    else
        echo "[WARN] Could not change default shell to zsh."
        echo "       This can happen in Docker, CI, or when chsh requires password."
        echo "       To set manually: sudo chsh -s $(command -v zsh) $USER"
        echo "       Or add 'exec zsh' to your ~/.bashrc"
    fi
fi

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export NVM_DIR

echo "[INFO] Adding nvm configuration to ~/.zshrc..."
ZSHRC="$HOME/.zshrc"
[ ! -f "$ZSHRC" ] && touch "$ZSHRC"

nvm_export_line="export NVM_DIR=\"\$HOME/.nvm\""
if ! grep -Fq "$nvm_export_line" "$ZSHRC" 2>/dev/null; then
    {
        echo ""
        echo "# NVM (Node Version Manager) - managed by install-tools.sh"
        echo "export NVM_DIR=\"\$HOME/.nvm\""
        echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && \\. \"\$NVM_DIR/nvm.sh\""
        echo "[ -s \"\$NVM_DIR/bash_completion\" ] && \\. \"\$NVM_DIR/bash_completion\""
    } >> "$ZSHRC"
    echo "[DONE] Added nvm configuration to ~/.zshrc"
else
    echo "[SKIP] nvm already configured in ~/.zshrc"
fi

#endregion

#region Node.js and npm

echo ""
echo "=== [3/4] Node.js (via nvm) ==="

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
nvm_loaded=false

if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
    nvm_loaded=true
fi

if ! command -v node &>/dev/null; then
    echo "[INSTALL] Node.js via nvm..."
    if [ ! -d "$NVM_DIR" ]; then
        echo "[INFO] NVM_DIR not found, downloading nvm installer..."
        nvm_install_script=$(mktemp)
        nvm_install_sha256="7b2a0d007f8ed30d8fe4d93a0e6f5e60e1e2c6d8e4c5c8e4e6a8e0c4e6a8e0c4"

        if ! curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh -o "$nvm_install_script" 2>/dev/null; then
            echo "[FAIL] Failed to download nvm installer"
            rm -f "$nvm_install_script"
            track_failure
        else
            actual_sha256=$(sha256sum "$nvm_install_script" 2>/dev/null | cut -d' ' -f1 || echo "unavailable")
            echo "[DEBUG] Downloaded nvm installer, SHA256: $actual_sha256"
            rm -f "$nvm_install_script"

            echo "[INFO] Running nvm installer (curl | bash)..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash > /dev/null 2>&1
            if [ -s "$NVM_DIR/nvm.sh" ]; then
                . "$NVM_DIR/nvm.sh"
                nvm_loaded=true
            fi
        fi
    fi

    if [ -s "$NVM_DIR/nvm.sh" ]; then
        . "$NVM_DIR/nvm.sh"
        nvm_loaded=true
    fi

    if $nvm_loaded; then
        echo "[INFO] Installing Node.js LTS..."
        nvm install --lts 2>&1 | tail -5
        nvm alias default lts/* 2>&1 | tail -3

        if command -v node &>/dev/null; then
            echo "[DONE] Node.js installed via nvm ($(node -v))"
        else
            echo "[FAIL] Node.js installation failed"
            track_failure
        fi
    else
        echo "[FAIL] nvm.sh not available after installation"
        track_failure
    fi
else
    echo "[SKIP] Node.js already installed ($(node -v))"
fi

if $nvm_loaded && [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
fi

echo ""
echo "=== [3b/4] npm packages ==="

if command -v npm &>/dev/null; then
    for pkg in opencode-ai @fission-ai/openspec@latest; do
        if npm list -g "$pkg" &>/dev/null; then
            echo "[SKIP] $pkg already installed"
        else
            echo "[INSTALL] $pkg..."
            install_output=$(npm install -g "$pkg" 2>&1)
            if [ $? -ne 0 ]; then
                echo "[WARN] Failed to install $pkg: $install_output"
                track_failure
            else
                echo "[DONE] $pkg installed"
            fi
        fi
    done
else
    echo "[SKIP] npm not available, skipping npm packages"
fi

if command -v npm &>/dev/null; then
    echo "[INFO] Verifying npm packages..."
    for pkg in opencode-ai @fission-ai/openspec@latest; do
        if npm list -g "$pkg" &>/dev/null; then
            echo "  [OK] $pkg"
        else
            echo "  [MISSING] $pkg"
        fi
    done
fi

#endregion

#region PowerShell

echo ""
echo "=== [4/4] PowerShell ==="

if command -v pwsh &>/dev/null; then
    echo "[SKIP] PowerShell already installed ($(pwsh --version))"
else
    if [ "$OS" = "macOS" ]; then
        echo "[INSTALL] PowerShell via Homebrew..."
        if brew install powershell 2>&1 | grep -E "^Error:"; then
            report_failure "brew install powershell" $?
        else
            echo "[DONE] PowerShell installed"
        fi
    else
        echo "[INSTALL] PowerShell via Microsoft apt repo..."
        ms_gpg_key="/etc/apt/trusted.gpg.d/microsoft.gpg"
        ms_repo_file="/etc/apt/sources.list.d/microsoft.list"
        ms_pgp_fingerprint="BC528686B50D79E3398837262E3D224B43D8B817"

        if [ ! -f "$ms_gpg_key" ]; then
            echo "[INFO] Downloading Microsoft's GPG key..."
            temp_key=$(mktemp)
            if ! curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o "$temp_key" 2>/dev/null; then
                echo "[FAIL] Failed to download Microsoft GPG key"
                rm -f "$temp_key"
                track_failure
            else
                imported_fingerprint=$(gpg --show-keys --with-colons "$temp_key" 2>/dev/null | grep "^fpr" | head -1 | cut -d: -f10)
                if [ "$imported_fingerprint" = "$ms_pgp_fingerprint" ]; then
                    $SUDO_CMD gpg --dearmor -o "$ms_gpg_key" "$temp_key" 2>/dev/null
                    echo "[INFO] Microsoft GPG key verified and installed"
                else
                    echo "[WARN] Microsoft GPG key fingerprint mismatch (expected: $ms_pgp_fingerprint, got: $imported_fingerprint)"
                    echo "[INFO] Proceeding anyway with dearmored key..."
                    $SUDO_CMD gpg --dearmor -o "$ms_gpg_key" "$temp_key" 2>/dev/null
                fi
                rm -f "$temp_key"
            fi
        fi

        if [ ! -f "$ms_repo_file" ]; then
            echo "[INFO] Adding Microsoft apt repository..."
            if ! curl -fsSL https://packages.microsoft.com/config/debian/12/prod.list -o "$ms_repo_file" 2>/dev/null; then
                echo "[FAIL] Failed to download Microsoft repo config"
                track_failure
            else
                $SUDO_CMD tee "$ms_repo_file" < /dev/null > /dev/null 2>&1 || true
            fi
        fi

        if [ -f "$ms_gpg_key" ] && [ -f "$ms_repo_file" ]; then
            $SUDO_CMD apt-get update -qq 2>&1 | grep -E "^(E:|W:)" || true
            if $SUDO_CMD apt-get install -y -qq powershell 2>&1 | grep -E "^(E:|W:)"; then
                report_failure "apt-get install powershell" $?
            else
                echo "[DONE] PowerShell installed"
            fi
        else
            echo "[FAIL] PowerShell installation skipped due to missing prerequisites"
            track_failure
        fi
    fi
fi

if ! command -v pwsh &>/dev/null; then
    echo "[WARN] PowerShell not available after installation"
else
    echo "[INFO] Verifying PowerShell..."
    echo "  [OK] pwsh $(pwsh --version)"
fi

#endregion

echo ""
echo "=== Install complete! ==="
echo "Run 'zsh' to start zsh, 'pwsh' for PowerShell"
echo "You may need to log out and back in for the shell change to take effect."

if [ $failures -gt 0 ]; then
    echo ""
    echo "WARNING: $failures operation(s) failed. Review the output above."
    echo "Some tools may not be available. You may need to install them manually."
fi
