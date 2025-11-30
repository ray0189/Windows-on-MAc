#!/usr/bin/env bash

# Step 04: Prepare the Windows USB installer
#
# This script interactively asks the user for the path to a Windows 11 ARM
# installation ISO and the disk identifier of a USB drive.  It then
# erases and partitions the selected disk, mounts the ISO, and copies
# the installer files to the USB.  The operation is destructive – all
# data on the chosen USB drive will be lost.  Use with caution.

set -euo pipefail

echo "[04] Preparing Windows USB installer…"

# Ensure running on macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This step is only supported on macOS." >&2
    exit 1
fi

# Determine whether we need sudo for disk operations
SUDO=""
if [[ ${EUID} -ne 0 ]]; then
    SUDO="sudo"
fi

# If a direct Windows ISO URL is provided via the environment and no local path
# has been specified, offer to download it automatically.  This allows
# advanced users to pre‑define a download source (for example, a link to
# Microsoft's official Windows 11 Arm ISO) via the `WINDOWS_ISO_URL` variable.
# The downloaded file will be saved into the build directory or the current
# working directory if BUILD_DIR is unset.
if [[ -n "${WINDOWS_ISO_URL:-}" && -z "${WINDOWS_ISO_PATH:-}" ]]; then
    echo "A Windows ISO download URL is configured: ${WINDOWS_ISO_URL}"
    read -r -p "Do you want to download the Windows 11 ARM ISO now? [y/N] " download_confirm
    case "$download_confirm" in
        [yY][eE][sS]|[yY])
            iso_output="${BUILD_DIR:-$(pwd)}/windows11_arm.iso"
            echo "Downloading Windows ISO to ${iso_output}…"
            if command -v curl >/dev/null 2>&1; then
                if ! curl -L "${WINDOWS_ISO_URL}" -o "${iso_output}"; then
                    echo "Download failed with curl." >&2
                fi
            elif command -v wget >/dev/null 2>&1; then
                if ! wget -O "${iso_output}" "${WINDOWS_ISO_URL}"; then
                    echo "Download failed with wget." >&2
                fi
            else
                echo "Neither curl nor wget is available for downloading files." >&2
            fi
            if [[ -f "${iso_output}" ]]; then
                WINDOWS_ISO_PATH="${iso_output}"
                export WINDOWS_ISO_PATH
                echo "Download complete. ISO saved to ${WINDOWS_ISO_PATH}."
            else
                echo "ISO download was not successful. You will be prompted for a local file." >&2
            fi
            ;;
        *)
            echo "Skipping automatic download. You will be prompted to provide an ISO path."
            ;;
    esac
fi

# Prompt for the Windows ISO path if not already provided via environment
if [[ -z "${WINDOWS_ISO_PATH:-}" ]]; then
    read -r -p "Enter the full path to your Windows 11 ARM ISO: " WINDOWS_ISO_PATH
fi

if [[ ! -f "${WINDOWS_ISO_PATH}" ]]; then
    echo "The specified ISO file does not exist: ${WINDOWS_ISO_PATH}" >&2
    exit 1
fi

# List available disks
echo "Available disks:"
diskutil list

# Prompt for the USB disk identifier if not already provided
if [[ -z "${SELECTED_DISK:-}" ]]; then
    read -r -p "Enter the disk identifier to use as the USB installer (e.g. disk4): " SELECTED_DISK
fi

if [[ -z "${SELECTED_DISK}" ]]; then
    echo "No disk identifier provided.  Aborting." >&2
    exit 1
fi

# Warn before erasing the disk
echo ""
echo "WARNING: This will ERASE all data on /dev/${SELECTED_DISK}."
echo -n "Type the exact disk identifier (${SELECTED_DISK}) to confirm: "
read -r CONFIRM_DISK
if [[ "${CONFIRM_DISK}" != "${SELECTED_DISK}" ]]; then
    echo "Disk identifier did not match.  Aborting." >&2
    exit 1
fi

# Record volumes before partitioning to detect the new mountpoint
mapfile -t VOLUMES_BEFORE < <(ls /Volumes)

echo "[04] Erasing and partitioning /dev/${SELECTED_DISK}…"
${SUDO} diskutil eraseDisk FAT32 WINDOWS GPT "/dev/${SELECTED_DISK}" || {
    echo "Failed to erase and partition the disk." >&2
    exit 1
}

# Wait a moment for the disk to remount
sleep 3

# Identify the new mount point by comparing before/after volume lists
USB_MOUNT=""
mapfile -t VOLUMES_AFTER < <(ls /Volumes)
for vol in "${VOLUMES_AFTER[@]}"; do
    skip=false
    for old in "${VOLUMES_BEFORE[@]}"; do
        if [[ "${vol}" == "${old}" ]]; then
            skip=true
            break
        fi
    done
    if [[ ${skip} == false ]]; then
        USB_MOUNT="/Volumes/${vol}"
        break
    fi
done

if [[ -z "${USB_MOUNT}" ]]; then
    echo "Unable to determine mount point of the USB drive.  Please unmount and remount manually." >&2
    exit 1
fi

echo "[04] USB drive mounted at ${USB_MOUNT}"

# Create a temporary mount point for the ISO
ISO_MOUNT="$(mktemp -d /Volumes/iso-mnt.XXXXXX)"

echo "[04] Mounting ISO…"
if ! hdiutil attach -quiet "${WINDOWS_ISO_PATH}" -mountpoint "${ISO_MOUNT}" -nobrowse; then
    echo "Failed to mount ISO image." >&2
    rm -rf "${ISO_MOUNT}"
    exit 1
fi

echo "[04] Copying Windows installer files to USB…"

# Use rsync if available, otherwise fall back to cp
if command -v rsync >/dev/null 2>&1; then
    rsync -aH --info=progress2 "${ISO_MOUNT}/" "${USB_MOUNT}/" || {
        echo "File copy failed." >&2
        hdiutil detach "${ISO_MOUNT}" -quiet || true
        rm -rf "${ISO_MOUNT}"
        exit 1
    }
else
    # Use ditto for macOS specific recursive copy
    if command -v ditto >/dev/null 2>&1; then
        ditto -V "${ISO_MOUNT}" "${USB_MOUNT}" || {
            echo "File copy failed." >&2
            hdiutil detach "${ISO_MOUNT}" -quiet || true
            rm -rf "${ISO_MOUNT}"
            exit 1
        }
    else
        cp -R "${ISO_MOUNT}"/* "${USB_MOUNT}"/ || {
            echo "File copy failed." >&2
            hdiutil detach "${ISO_MOUNT}" -quiet || true
            rm -rf "${ISO_MOUNT}"
            exit 1
        }
    fi
fi

echo "[04] Windows installer successfully copied to ${USB_MOUNT}"

# Export variables so later steps can clean up
export WINDOWS_ISO_PATH
export SELECTED_DISK
export ISO_MOUNT
export USB_MOUNT

echo "[04] USB preparation complete."
exit 0
