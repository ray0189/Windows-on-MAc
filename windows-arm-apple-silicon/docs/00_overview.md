# Overview

This repository contains research materials, tooling and experimental code for
booting native Windows ARM on Apple Silicon Macs. Much of the work here is
unfinished and intended for developers familiar with low-level boot processes.

## Installer Layer (Experimental)

An experimental installer layer lives under the installer/ directory. It
provides a set of scripts that automate parts of the build and preparation
process for Windows ARM. Running ./installer/one_click_installer.sh from
macOS on an Apple Silicon host will:

1. Check that your environment meets the basic requirements (macOS + ARM64).
2. Optionally install Homebrew and required build tools.
3. Build the m1n1 boot monitor, U-Boot, and an AppleSilicon EDK2 firmware
   image from the sources in this repository.
4. Prompt you to select a Windows 11 ARM ISO and a USB drive, then erase
   the drive and copy the installer files to it.
5. Stage the built components in a safe directory and provide guidance on
   how to experiment with tethered boot or manual installation.
6. Clean up any mounted images and eject the USB drive.

### Typical Workflow

1. Open a terminal on your Apple Silicon Mac and navigate to the root of
   this repository.
2. Run:

   ```sh
   ./installer/one_click_installer.sh
   ```

3. Answer the prompts about installing dependencies, selecting the Windows 11
   ARM ISO, and choosing the USB disk to erase.
4. Allow the scripts to build the necessary binaries and prepare the USB
   installer. Depending on your internet connection and hardware this may
   take some time.
5. After completion, reboot your Mac, hold the power button to enter the
   boot picker, and use the experimental boot entries (m1n1/UEFI) to
   attempt booting the Windows installer. Results are not guaranteed and
   may vary as the research evolves.

This installer layer is intentionally separated from the core research code
so that it can evolve independently. Feedback and contributions are
welcome, but please remember that this work is experimental and not
intended for general consumers.
