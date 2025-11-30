#!/usr/bin/env bash

# Step 05: Stage m1n1 and UEFI for manual flashing
#
# This script copies the boot components built in step 03 into a staging
# directory.  It does **not** automatically flash anything to the
# internal preboot volume – doing so remains a manual, high‑risk
# operation that should only be attempted by experienced developers.
# Instead, it provides guidance on how to proceed with tethered boot
# testing or manual installation.

set -euo pipefail

echo "[05] Staging built components…"

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build}"
STAGING_DIR="${OUTPUT_DIR:-${BUILD_DIR}/staging}"

mkdir -p "${STAGING_DIR}"

# List of expected artifacts
ARTIFACTS=(
    "m1n1-stage1.bin"
    "m1n1-stage2.bin"
    "uboot.efi"
    "uboot.bin"
    "AppleSilicon_UEFI.fd"
)

copied_any=false
for file in "${ARTIFACTS[@]}"; do
    src="${BUILD_DIR}/${file}"
    if [[ -f "${src}" ]]; then
        cp -f "${src}" "${STAGING_DIR}/" && {
            echo "[05] Copied ${file} -> ${STAGING_DIR}/"
            copied_any=true
        }
    fi
done

if [[ "${copied_any}" == false ]]; then
    echo "[05] No boot artifacts found in ${BUILD_DIR}.  Make sure step 03 completed successfully." >&2
    exit 1
fi

echo ""
echo "[05] Staging complete.  The following files are available in ${STAGING_DIR}:"
ls -1 "${STAGING_DIR}"

cat <<'EOS'

=====================================================================
MANUAL INSTALLATION / TETHERED BOOT (EXPERIMENTAL)
=====================================================================

The files in the staging directory are the raw boot components required
to experiment with Windows ARM on Apple Silicon.  **They have not been
installed to your machine.**  Flashing m1n1 stage 1 to the hidden
preboot volume or chainloading into UEFI from m1n1 remain manual,
high‑risk operations.  Proceed only if you understand the risks and
have a recovery plan.

Suggested next steps:

  * **Tethered boot testing** – m1n1 can be loaded over USB without
    modifying your internal storage.  Consult the m1n1 documentation
    (Asahi Linux project) for instructions on how to run m1n1 in
    tethered mode and load a stage 2 or UEFI image from a connected
    host.
  * **Manual stage 1 installation** – if you choose to install m1n1
    permanently, follow the official Asahi Linux installation guide to
    prepare the preboot volume.  Replace the provided m1n1 binaries
    with the ones generated here.  This is experimental and could
    render your system unbootable.
  * **Chainload UEFI** – once m1n1 stage 1/2 are running, you can use
    m1n1's menu or command interface to load `uboot.efi` or
    `AppleSilicon_UEFI.fd` as a payload.  From there you can attempt
    to boot the Windows installer on your prepared USB stick.

These instructions are intentionally high‑level; the exact steps vary as
the research evolves.  Monitor the upstream projects (Asahi Linux,
U‑Boot, EDK2 Apple Silicon) for up‑to‑date guides.

EOS

exit 0
