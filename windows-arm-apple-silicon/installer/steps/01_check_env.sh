#!/usr/bin/env bash

# Step 01: Environment checks
#
# This script verifies that the host machine meets the basic requirements
# for building and preparing the Windows ARM installer.  It checks for
# macOS on Apple Silicon, validates the CPU architecture, and ensures
# the Xcode command line tools are installed.  Optionally, it can warn
# about older macOS versions if MINIMUM_MACOS_VERSION is defined.

set -euo pipefail

echo "[01] Checking host environment…"

# Ensure running on macOS
OS_NAME="$(uname -s)"
if [[ "${OS_NAME}" != "Darwin" ]]; then
    echo "This script must be run on macOS.  Detected OS: ${OS_NAME}" >&2
    exit 1
fi

# Ensure running on Apple Silicon
ARCH="$(uname -m)"
if [[ "${ARCH}" != "arm64" ]]; then
    echo "This script requires an Apple Silicon Mac (arm64).  Detected architecture: ${ARCH}" >&2
    exit 1
fi

# Optionally warn about minimum macOS version
if [[ -n "${MINIMUM_MACOS_VERSION:-}" ]]; then
    CURRENT_VERSION=$(sw_vers -productVersion)
    # compare versions using sort -V
    if [[ "$(printf '%s\n%s' "$MINIMUM_MACOS_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" != "$MINIMUM_MACOS_VERSION" ]]; then
        echo "Warning: your macOS version (${CURRENT_VERSION}) is older than the recommended minimum (${MINIMUM_MACOS_VERSION})." >&2
    fi
fi

# Check for Xcode command line tools
if ! xcode-select -p >/dev/null 2>&1; then
    echo "Xcode command line tools are not installed.  Run 'xcode-select --install' and re‑run this installer." >&2
    exit 1
fi

echo "[01] Environment looks good."
exit 0
