# Difference between wsl.conf and .wslconfig

## wsl.conf
- **Purpose:** Configures settings for individual WSL distributions (e.g., Ubuntu, Debian).
- **Location:** Place inside the Linux filesystem at `/etc/wsl.conf` within each WSL distribution.
- **Scope:** Affects only the specific WSL distribution where the file is present.

## .wslconfig
- **Purpose:** Configures global WSL settings that affect all distributions (e.g., memory, processors, networking).
- **Location:** Place in your Windows user directory, typically at `C:\Users\<YourUsername>\.wslconfig`.
- **Scope:** Applies to all WSL distributions on the Windows machine.
