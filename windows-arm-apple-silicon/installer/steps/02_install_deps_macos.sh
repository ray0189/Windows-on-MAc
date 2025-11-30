#!/usr/bin/env bash

# Step 02: Install dependencies on macOS
#
# This script ensures that Homebrew is available and uses it to install
# the tools required to build the boot components.  It is careful to
# prompt the user before installing Homebrew or erasing any data.

set -euo pipefail

echo "[02] Installing build dependencies…"

# Ensure running on macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This step is only for macOS hosts." >&2
    exit 1
fi

# Check for Homebrew
if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed on this system."
    echo -n "Would you like to install Homebrew now? [y/N] "
    read -r install_brew
    case "$install_brew" in
        [yY][eE][sS]|[yY])
            echo "Installing Homebrew…"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
                echo "Homebrew installation failed." >&2
                exit 1
            }
            echo "Homebrew installed."
            ;;
        *)
            echo "Homebrew is required to continue.  Aborting."
            exit 1
            ;;
    esac
fi

# Ensure brew commands are up to date
echo "Updating Homebrew…"
brew update --quiet

# Packages we need
REQUIRED_FORMULAE=(git cmake ninja python@3.11 llvm)

for pkg in "${REQUIRED_FORMULAE[@]}"; do
    if brew list --formula -1 | grep -q "^${pkg}\$"; then
        echo "[02] ${pkg} already installed."
    else
        echo "[02] Installing ${pkg}…"
        brew install "${pkg}" --quiet || {
            echo "Failed to install ${pkg}." >&2
            exit 1
        }
    fi
done

# After installation, verify commands are available
MISSING_TOOLS=()
for tool in git cmake ninja python3 clang; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [[ ${#MISSING_TOOLS[@]} -ne 0 ]]; then
    echo "The following required tools are still missing: ${MISSING_TOOLS[*]}" >&2
    echo "Please ensure they are on your PATH and try again."
    exit 1
fi

echo "[02] All dependencies are installed."
exit 0
