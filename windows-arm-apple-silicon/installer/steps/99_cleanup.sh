#!/usr/bin/env bash

# Step 99: Cleanup
#
# This optional step unmounts any mounted disk images and ejects the
# prepared USB drive.  It prints a friendly final message reminding the
# user of the experimental nature of this project.  Any errors during
# cleanup are non‑fatal – the script will attempt all actions and then
# exit.

set -euo pipefail

echo "[99] Performing cleanup…"

# Determine whether we need sudo for disk operations
SUDO=""
if [[ ${EUID} -ne 0 ]]; then
    SUDO="sudo"
fi

# Detach ISO mount if it exists
if [[ -n "${ISO_MOUNT:-}" && -d "${ISO_MOUNT}" ]]; then
    echo "[99] Detaching ISO mounted at ${ISO_MOUNT}…"
    hdiutil detach "${ISO_MOUNT}" -quiet || true
    rm -rf "${ISO_MOUNT}"
fi

# Eject USB drive
if [[ -n "${SELECTED_DISK:-}" ]]; then
    echo "[99] Ejecting /dev/${SELECTED_DISK}…"
    ${SUDO} diskutil eject "/dev/${SELECTED_DISK}" >/dev/null 2>&1 || true
fi

echo "[99] Cleanup complete."
echo "Remember: this is a research‑grade tool.  Booting Windows ARM on Apple Silicon is experimental and may not work on your machine.  Good luck!"

exit 0
