# Experimental One‑Click Installer for Windows ARM on Apple Silicon

This directory contains a **highly experimental** set of scripts designed to bootstrap the research work of booting native Windows 11 ARM on Apple Silicon machines.  These scripts are intended **for developers and researchers only** – they are **not** polished installers for end users.

## What This Installer Does

The goal of the one‑click installer is to automate as many of the repetitive setup tasks as possible so that contributors can focus on the actual boot and driver research.  When invoked from macOS on an Apple Silicon machine, the installer will:

1. **Check your environment:** Ensure you are running on macOS, that your machine is using an ARM64 CPU, and that the Xcode command line tools are present.
2. **Install required dependencies:** Optionally install Homebrew and a handful of build tools (Git, CMake, Ninja, Python 3 and a modern C/C++ toolchain).
3. **Fetch and build the boot chain:** Build [`m1n1`](https://github.com/AsahiLinux/m1n1), U‑Boot and an AppleSilicon EDK2 firmware image from the sources in this repository.
4. **Prepare a Windows 11 ARM USB installer:** Interactively prompt you for a Windows 11 ARM ISO file and a target USB disk, then repartition and populate that disk with the Windows installer files.
5. **Stage the experimental boot setup:** Copy the built m1n1 and UEFI firmware components into a staging area ready for manual flashing or tethered boot.  The scripts will **not** automatically modify any hidden or preboot partitions without an explicit opt‑in.
6. **Clean up:** Safely unmount the mounted ISO and eject the USB disk at the end of the process.

At every destructive or risky step, the installer stops and asks for confirmation.  It will never silently erase your internal SSD or flash a preboot partition.  The expectation is that the user running this tool already understands the risks involved in low‑level boot hacking and is prepared to recover their system if things go wrong.

## Platform Assumptions

These scripts target **macOS on Apple Silicon** (for example, an M1 Mac mini or MacBook).  They make liberal use of macOS‑specific utilities such as `diskutil` and `hdiutil`.  Do not attempt to run them on Intel Macs or on Linux/Windows hosts.

## Interactive Choices

During execution you will be prompted for two key pieces of information:

* **Windows 11 ARM ISO path** – you need a copy of the official Windows 11 ARM installation ISO.  The installer does **not** download this for you.
* **USB device identifier** – the disk identifier of the USB stick you are willing to erase and convert into a Windows installer.  The script will display the output of `diskutil list` to help you choose.  Take care to select the correct disk; the chosen disk will be completely wiped.

## What Gets Built

From the sources in this repository the installer builds three primary artifacts:

| Component | Description |
|----------|-------------|
| **m1n1** | A minimal boot monitor used on Apple Silicon to perform low‑level boot and introspection tasks.  Both stage 1 and stage 2 binaries are generated. |
| **U‑Boot** | A modern bootloader which can chainload into EDK2 or other payloads.  For Windows we build it as an EFI application. |
| **AppleSilicon EDK2 firmware image** | A UEFI firmware image built with EDK2 that provides the runtime environment needed to boot Windows. |

The resulting binaries live in the top‑level `build/` directory.  They are **not** automatically flashed to your Mac.  Instead, see the staging script for instructions on how to perform a tethered boot or manual install.

## Limitations and Warnings

* **No guarantee of success.**  Booting Windows ARM natively on Apple Silicon is an ongoing research project.  Hardware support (particularly GPU, storage and networking) is incomplete and rapidly evolving.  Use at your own risk.
* **Data loss is possible.**  The process of preparing a USB installer requires wiping that USB stick.  If you choose the wrong disk identifier, you could erase the wrong drive.  Pay close attention to the prompts.
* **Requires developer knowledge.**  You should be comfortable working on the command line and recovering a machine from unusual boot states.  This is not a consumer‑friendly wizard.

## Overview of Step Scripts

The installer is broken into discrete scripts under `installer/steps/` to make it easier to reason about and extend.  Each script is an executable bash script.  They are executed sequentially by `one_click_installer.sh` and can also be run individually for testing.

| Step | Script | Purpose |
|----:|--------|---------|
| 01 | **01_check_env.sh** | Ensures the host is macOS on Apple Silicon with Xcode command line tools installed. |
| 02 | **02_install_deps_macos.sh** | Installs Homebrew (with consent) and required build dependencies (Git, CMake, Ninja, Python 3, LLVM/GCC). |
| 03 | **03_build_boot_chain.sh** | Builds m1n1, U‑Boot and the AppleSilicon EDK2 firmware.  Places the results in `build/`. |
| 04 | **04_prepare_windows_usb.sh** | Interactively erases a USB drive and copies the contents of a Windows 11 ARM ISO onto it. |
| 05 | **05_stage_m1n1_and_uefi.sh** | Copies built binaries into a `build/staging/` directory and prints instructions for manual flashing or tethered boot.  Does not modify any system partitions automatically. |
| 99 | **99_cleanup.sh** | Unmounts the ISO and ejects the USB drive.  Prints a final reminder that everything is still experimental. |

Refer to the comments in each script for further details.
