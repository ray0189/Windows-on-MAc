#!/usr/bin/env bash

# Step 03: Build the boot chain (m1n1, U‑Boot, EDK2)
#
# This script uses the sources checked out in the repository to build the
# components necessary for booting Windows ARM.  It attempts to be
# reasonably robust: it will initialise git submodules, build each
# component if its source directory exists, and copy the resulting
# artifacts into a central build directory.  If any component fails to
# build the script will abort and return a non‑zero exit code.

set -euo pipefail

echo "[03] Building boot chain…"

# Determine repository root and build directory
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build}"

mkdir -p "${BUILD_DIR}"

# Initialise submodules
if command -v git >/dev/null 2>&1; then
    echo "[03] Updating git submodules…"
    git -C "${REPO_ROOT}" submodule update --init --recursive || {
        echo "Failed to initialise git submodules." >&2
        exit 1
    }
fi

CPU_CORES=1
if command -v sysctl >/dev/null 2>&1; then
    CPU_CORES=$(sysctl -n hw.ncpu || echo 1)
fi

# Helper to build a component
build_m1n1() {
    local src_dir="${REPO_ROOT}/boot/m1n1"
    if [[ ! -d "${src_dir}" ]]; then
        echo "[03] m1n1 source not found at ${src_dir}, skipping." >&2
        return 0
    fi
    echo "[03] Building m1n1…"
    pushd "${src_dir}" >/dev/null
    if ! make -j"${CPU_CORES}"; then
        echo "[03] Failed to build m1n1." >&2
        popd >/dev/null
        return 1
    fi
    # Copy stage1 and stage2 if they exist
    if [[ -f build/m1n1.bin ]]; then
        cp -f build/m1n1.bin "${BUILD_DIR}/m1n1-stage1.bin"
        echo "[03] m1n1 stage1 copied to ${BUILD_DIR}/m1n1-stage1.bin"
    fi
    if [[ -f build/m1n1_stage2.bin ]]; then
        cp -f build/m1n1_stage2.bin "${BUILD_DIR}/m1n1-stage2.bin"
        echo "[03] m1n1 stage2 copied to ${BUILD_DIR}/m1n1-stage2.bin"
    fi
    popd >/dev/null
}

build_uboot() {
    local src_dir="${REPO_ROOT}/boot/uboot"
    if [[ ! -d "${src_dir}" ]]; then
        echo "[03] U‑Boot source not found at ${src_dir}, skipping." >&2
        return 0
    fi
    echo "[03] Building U‑Boot…"
    pushd "${src_dir}" >/dev/null
    # Attempt a default configuration; adjust as needed for your target
    if [[ ! -f .config ]]; then
        # Try a known Apple configuration if available
        if make help 2>/dev/null | grep -q "apple_m1_defconfig"; then
            make apple_m1_defconfig
        elif make help 2>/dev/null | grep -q "asahi_defconfig"; then
            make asahi_defconfig
        fi
    fi
    if ! make -j"${CPU_CORES}"; then
        echo "[03] Failed to build U‑Boot." >&2
        popd >/dev/null
        return 1
    fi
    # Try to locate an EFI binary
    local uboot_efi
    uboot_efi=$(find . -name 'u-boot*.efi' -print -quit || true)
    if [[ -n "${uboot_efi}" ]]; then
        cp -f "${uboot_efi}" "${BUILD_DIR}/uboot.efi"
        echo "[03] U‑Boot EFI copied to ${BUILD_DIR}/uboot.efi"
    else
        # Fallback: copy raw u-boot binary
        local uboot_bin
        uboot_bin=$(find . -name 'u-boot.bin' -print -quit || true)
        if [[ -n "${uboot_bin}" ]]; then
            cp -f "${uboot_bin}" "${BUILD_DIR}/uboot.bin"
            echo "[03] U‑Boot binary copied to ${BUILD_DIR}/uboot.bin"
        fi
    fi
    popd >/dev/null
}

build_edk2() {
    local src_dir="${REPO_ROOT}/uefi/edk2-apple-silicon"
    if [[ ! -d "${src_dir}" ]]; then
        echo "[03] EDK2 source not found at ${src_dir}, skipping." >&2
        return 0
    fi
    echo "[03] Building EDK2 firmware…"
    pushd "${src_dir}" >/dev/null
    # The build method varies; try a wrapper script first
    if [[ -x build.sh ]]; then
        ./build.sh -b "${DEFAULT_EDK2_BUILD_TARGET:-RELEASE}" || {
            echo "[03] EDK2 build script failed." >&2
            popd >/dev/null
            return 1
        }
    elif [[ -x edk2-build.sh ]]; then
        ./edk2-build.sh -b "${DEFAULT_EDK2_BUILD_TARGET:-RELEASE}" || {
            echo "[03] EDK2 build script failed." >&2
            popd >/dev/null
            return 1
        }
    else
        # Fallback: attempt to use the edk2 build system directly
        if ! make -j"${CPU_CORES}"; then
            echo "[03] Failed to build EDK2 via make." >&2
            popd >/dev/null
            return 1
        fi
    fi
    # Locate the firmware image (.fd)
    local firmware
    firmware=$(find Build -name '*.fd' -print -quit || true)
    if [[ -n "${firmware}" ]]; then
        cp -f "${firmware}" "${BUILD_DIR}/AppleSilicon_UEFI.fd"
        echo "[03] Firmware image copied to ${BUILD_DIR}/AppleSilicon_UEFI.fd"
    else
        echo "[03] No firmware image (.fd) found after build." >&2
    fi
    popd >/dev/null
}

build_m1n1 || exit 1
build_uboot || exit 1
build_edk2 || exit 1

echo "[03] Boot chain built.  Artifacts are located in ${BUILD_DIR}."
exit 0
