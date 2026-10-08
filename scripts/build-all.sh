#!/bin/bash
# Master build script - Build everything in one go

set -e

# Get script directory and workspace root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../workspace" && pwd)"

# Set up logging
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="${WORKSPACE_ROOT}/logs"
LOG_FILE="${LOG_DIR}/build-all-${TIMESTAMP}.log"

# Create log directory
mkdir -p "${LOG_DIR}"

# Function to log messages to both console and file
log() {
    echo "$@" | tee -a "${LOG_FILE}"
}

# Function to log without newline
log_n() {
    echo -n "$@" | tee -a "${LOG_FILE}"
}

# Redirect all output to log file while still showing on console
exec > >(tee -a "${LOG_FILE}") 2>&1

log "======================================================================="
log "  HiFive Unmatched U-Boot + Rocky Linux - Complete Build Script"
log "======================================================================="
log ""
log "Build started: $(date)"
log "Log file: ${LOG_FILE}"
log ""

# Change to workspace root
cd "${WORKSPACE_ROOT}"

# Set up environment variables relative to workspace
export BUILD_DIR="${WORKSPACE_ROOT}/build"
export OUTPUT_DIR="${WORKSPACE_ROOT}/output"
export WORKSPACE="${WORKSPACE_ROOT}"

# Create directories if they don't exist
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

# Check if we're in the right directory
if [ ! -f "${SCRIPT_DIR}/build-opensbi.sh" ]; then
    log "ERROR: Build scripts not found!"
    log "Please run this script from the scripts directory or workspace root."
    exit 1
fi

log "Workspace: ${WORKSPACE_ROOT}"
log "Build dir: ${BUILD_DIR}"
log "Output dir: ${OUTPUT_DIR}"
log "Log dir: ${LOG_DIR}"
log ""

# Start time
START_TIME=$(date +%s)

log ""
log "Build started at: $(date)"
log ""

# Step 1: Build OpenSBI
log ""
log "===================================================================="
log "  [1/10] Building OpenSBI Firmware"
log "===================================================================="
if bash "${SCRIPT_DIR}/build-opensbi.sh"; then
    log "[OK] OpenSBI build completed successfully"
else
    log "[ERROR] OpenSBI build failed!"
    log "Check log file: ${LOG_FILE}"
    exit 1
fi

# Step 2: Build U-Boot
log ""
log "===================================================================="
log "  [2/10] Building U-Boot Bootloader"
log "===================================================================="
if bash "${SCRIPT_DIR}/build-uboot.sh"; then
    log "[OK] U-Boot build completed successfully"
else
    log "[ERROR] U-Boot build failed!"
    log "Check log file: ${LOG_FILE}"
    exit 1
fi

# Step 3: Download rootfs
log ""
log "===================================================================="
log "  [3/10] Downloading Rocky Linux Rootfs"
log "===================================================================="
if bash "${SCRIPT_DIR}/download-rootfs.sh"; then
    log "[OK] Rootfs download completed successfully"
else
    log "[ERROR] Rootfs download failed!"
    log "Check log file: ${LOG_FILE}"
    exit 1
fi

# Step 4: Build Linux kernel
log ""
log "===================================================================="
log "  [4/10] Building Linux Kernel"
log "===================================================================="
if bash "${SCRIPT_DIR}/build-kernel.sh"; then
    log "[OK] Kernel build completed successfully"
else
    log "[ERROR] Kernel build failed!"
    log "Check log file: ${LOG_FILE}"
    exit 1
fi

# Step 5: Create disk image
log ""
log "===================================================================="
log "  [5/10] Creating Bootable Disk Image"
log "===================================================================="
if bash "${SCRIPT_DIR}/create-image.sh"; then
    log "[OK] Disk image created successfully"
else
    log "[ERROR] Disk image creation failed!"
    log "Check log file: ${LOG_FILE}"
    exit 1
fi

# Step 6: Install kernel to rootfs
log ""
log "===================================================================="
log "  [6/10] Installing Kernel to Rootfs"
log "===================================================================="
if bash "${SCRIPT_DIR}/install-kernel.sh"; then
    log "[OK] Kernel installation completed successfully"
else
    log "[ERROR] Kernel installation failed!"
    log "Check log file: ${LOG_FILE}"
    exit 1
fi

# Step 7: Setup boot configuration
log ""
log "===================================================================="
log "  [7/10] Configuring Boot Files"
log "===================================================================="
if bash "${SCRIPT_DIR}/setup-boot.sh"; then
    log "[OK] Boot configuration completed successfully"
else
    log "[ERROR] Boot configuration failed!"
    log "Check log file: ${LOG_FILE}"
    exit 1
fi

# Step 8: Install system packages
log ""
log "===================================================================="
log "  [8/10] Installing System Packages (systemd, SSH, etc.)"
log "===================================================================="
log "This step will install essential packages to make the rootfs bootable."
log "Note: Requires QEMU user-mode emulation or will be skipped."
log ""
if bash "${SCRIPT_DIR}/install-system-packages.sh"; then
    log "[OK] System packages step completed"
else
    log "[WARN] System package installation had issues"
    log "Packages may need to be installed manually after first boot"
fi

# Step 9: Reset root password
log ""
log "===================================================================="
log "  [9/10] Setting Root Password"
log "===================================================================="
if bash "${SCRIPT_DIR}/reset-root-password.sh"; then
    log "[OK] Root password set successfully"
else
    log "[ERROR] Root password reset failed!"
    log "Check log file: ${LOG_FILE}"
    exit 1
fi

# Step 10: Generate documentation
log ""
log "===================================================================="
log "  [10/10] Generating Build Information"
log "===================================================================="

OUTPUT_DIR=${OUTPUT_DIR:-/workspace/output}
BUILD_INFO="${OUTPUT_DIR}/BUILD_INFO.txt"

cat > "${BUILD_INFO}" << EOF
HiFive Unmatched U-Boot + Rocky Linux Build
============================================

Build Date: $(date)
Built on: $(uname -a)
Log File: ${LOG_FILE}

Components:
-----------
OpenSBI:  ${OPENSBI_VERSION:-v1.3}
U-Boot:   ${UBOOT_VERSION:-v2026.07}
Rootfs:   Rocky Linux / Fedora RISC-V

Toolchain:
----------
$(${CROSS_COMPILE}gcc --version | head -1)

Files Generated:
----------------
$(ls -lh "${OUTPUT_DIR}" | grep -v BUILD_INFO)

Image Location:
---------------
${OUTPUT_DIR}/${IMAGE_NAME:-rocky-riscv-unmatched.img}

Next Steps - Flash to Real Hardware:
------------------------------------
  NOTE: This image does NOT work in QEMU!
  It is built for SiFive HiFive Unmatched hardware only.

1. Flash to SD card (Linux/Mac):
   sudo dd if=${OUTPUT_DIR}/${IMAGE_NAME:-rocky-riscv-unmatched.img} of=/dev/sdX bs=4M status=progress conv=fsync
   sudo sync

2. Flash to SD card (Windows):
   Use one of these tools:
   - Rufus (https://rufus.ie/)
   - Win32 Disk Imager
   - balenaEtcher (https://www.balena.io/etcher/)

3. Insert SD card into HiFive Unmatched board
   - Use the SD card slot on the board

4. Set MSEL DIP switches for SD card boot:
   Position: 1011 (ON-ON-OFF-ON from left to right)

5. Connect serial console:
   - Baud rate: 115200, 8N1
   - Device: ttySIF0 on board (ttyUSB0 or similar on host)
   - Use minicom, screen, or PuTTY

6. Connect Ethernet cable (DHCP will auto-configure)

7. Power on the board and watch boot process

Default Credentials:
--------------------
Username: root
Password: ${ROOT_PASSWORD:-rockylinux}
SSH: Enabled on port 22

First Boot Setup:
-----------------
If system packages were not installed during build, run after first boot:
  /root/first-boot-setup.sh

This will install systemd, SSH, NetworkManager, and all essential packages.

Installed Software:
-------------------
- systemd (full init system)
- OpenSSH server
- NetworkManager (DHCP configured)
- Basic system utilities
- vim, nano text editors
EOF

log "Build information saved to: ${BUILD_INFO}"
log "[OK] Build documentation generated successfully"

# End time and duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

log ""
log "======================================================================="
log "  BUILD COMPLETE!"
log "======================================================================="
log ""
log "Build ended: $(date)"
log "Total build time: ${MINUTES}m ${SECONDS}s"
log ""
log "Generated files:"
log "  - ${OUTPUT_DIR}/${IMAGE_NAME:-rocky-riscv-unmatched.img}"
log "  - ${OUTPUT_DIR}/u-boot-spl.bin"
log "  - ${OUTPUT_DIR}/u-boot.itb"
log "  - ${OUTPUT_DIR}/BUILD_INFO.txt"
log "  - ${LOG_FILE}"
log ""
log "Next Steps - Flash to REAL Hardware:"
log "======================================"
log ""
log "WARNING: This image does NOT work in QEMU!"
log "WARNING: Use SiFive HiFive Unmatched hardware only."
log ""
log "1. Flash to SD card:"
log "   Linux/Mac:  sudo dd if=${OUTPUT_DIR}/${IMAGE_NAME:-rocky-riscv-unmatched.img} of=/dev/sdX bs=4M status=progress"
log "   Windows:    Use Rufus or balenaEtcher"
log ""
log "2. Insert SD card into HiFive Unmatched"
log "3. Set MSEL switches: 1011 (ON-ON-OFF-ON)"
log "4. Connect serial console (115200 baud)"
log "5. Power on board"
log ""
log "Default login: root / ${ROOT_PASSWORD:-rockylinux}"
log ""
log "See BUILD_INFO.txt for detailed instructions."
log ""
log "======================================================================="
log ""
log "Full build log saved to: ${LOG_FILE}"
log ""

# Create symlink to latest log
LATEST_LOG="${LOG_DIR}/build-all-latest.log"
rm -f "${LATEST_LOG}"
ln -s "$(basename ${LOG_FILE})" "${LATEST_LOG}"
log "Latest log symlink: ${LATEST_LOG}"
