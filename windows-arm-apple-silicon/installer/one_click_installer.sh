#!/usr/bin/env bash

# Top‑level orchestrator for the experimental Windows ARM installer
#
# This script coordinates the execution of the individual step scripts in
# `installer/steps/`.  It performs basic environment checks, prints
# warnings, sources configuration, and handles error propagation.  See
# README.md for an overview.

set -euo pipefail

# ANSI colour codes for warnings
RED="\033[31m"
BOLD="\033[1m"
RESET="\033[0m"

warn() {
    printf "${RED}${BOLD}%s${RESET}\n" "$*"
}

# Determine the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Print a big warning banner
warn "**********************************************************************"
warn " WARNING: This installer is EXPERIMENTAL and for developers only! "
warn " It will attempt to build and stage a Windows ARM boot setup on   "
warn " your Apple Silicon Mac.  Data loss is possible if you choose the   "
warn " wrong disk.  Proceed at your own risk.                           "
warn "**********************************************************************"
echo

# Source default configuration
CONFIG_DIR="${SCRIPT_DIR}/config"
DEFAULT_ENV="${CONFIG_DIR}/default.env"
LOCAL_ENV="${CONFIG_DIR}/local.env"

if [[ -f "${DEFAULT_ENV}" ]]; then
    # shellcheck source=/dev/null
    source "${DEFAULT_ENV}"
fi

# Source local overrides if present
if [[ -f "${LOCAL_ENV}" ]]; then
    echo "Using local configuration overrides from ${LOCAL_ENV}"
    # shellcheck source=/dev/null
    source "${LOCAL_ENV}"
fi

# Auto‑detect the repository root if not provided
if [[ -z "${REPO_ROOT:-}" ]]; then
    # two levels up from this script: installer/ -> windows-arm-apple-silicon/
    REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fi

# Ensure we are running on an ARM64 macOS host
OS_NAME="$(uname -s)"
ARCH="$(uname -m)"
if [[ "${OS_NAME}" != "Darwin" || "${ARCH}" != "arm64" ]]; then
    warn "This installer must be run on an Apple Silicon Mac running macOS."
    warn "Detected OS: ${OS_NAME}, Architecture: ${ARCH}"
    exit 1
fi

# Run each step script sequentially
STEPS=(
    "01_check_env.sh"
    "02_install_deps_macos.sh"
    "03_build_boot_chain.sh"
    "04_prepare_windows_usb.sh"
    "05_stage_m1n1_and_uefi.sh"
    "99_cleanup.sh"
)

for step in "${STEPS[@]}"; do
    STEP_PATH="${SCRIPT_DIR}/steps/${step}"
    if [[ ! -x "${STEP_PATH}" ]]; then
        warn "Step script ${step} is missing or not executable."
        exit 1
    fi
    echo "\n=== Running ${step} ==="
    # Export variables so sub‑scripts can access and set them
    export REPO_ROOT
    export TARGET_MACHINE
    export BUILD_DIR
    export OUTPUT_DIR
    export DEFAULT_EDK2_BUILD_TARGET
    export MINIMUM_MACOS_VERSION
    export SELECTED_DISK
    export WINDOWS_ISO_PATH
    # shellcheck disable=SC1090
    "${STEP_PATH}"
    echo "=== Completed ${step} ===\n"
done

# Final summary
echo "\n================ Summary ================"
echo "Repository root: ${REPO_ROOT}"
if [[ -n "${BUILD_DIR:-}" ]]; then
    echo "Build directory: ${BUILD_DIR}"
else
    echo "Build directory: ${REPO_ROOT}/build"
fi
if [[ -n "${SELECTED_DISK:-}" ]]; then
    echo "USB installer prepared on: /dev/${SELECTED_DISK}"
else
    echo "USB installer was not prepared during this run."
fi
if [[ -n "${WINDOWS_ISO_PATH:-}" ]]; then
    echo "Windows ISO used: ${WINDOWS_ISO_PATH}"
fi
echo ""
echo "Next steps:"
echo " 1. Reboot your Mac."
echo " 2. Hold the power button to enter the boot picker or recovery."
echo " 3. Choose the experimental boot entry if present (this may be labelled as m1n1 or UEFI)."
echo ""
echo "Remember: this tool does not guarantee a working Windows boot. It simply stages the experimental components."
echo "For more details, consult the documentation in docs/ and the README in installer/."

exit 0
