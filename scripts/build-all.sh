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
log "  [1/8] Building OpenSBI Firmware"
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
log "  [2/8] Building U-Boot Bootloader"
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
log "  [3/8] Downloading Rocky Linux Rootfs"
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
log "  [4/8] Building Linux Kernel"
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
log "  [5/8] Creating Bootable Disk Image"
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
log "  [6/8] Installing Kernel to Rootfs"
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
log "  [7/8] Configuring Boot Files"
log "===================================================================="
if bash "${SCRIPT_DIR}/setup-boot.sh"; then
    log "[OK] Boot configuration completed successfully"
else
    log "[ERROR] Boot configuration failed!"
    log "Check log file: ${LOG_FILE}"
    exit 1
fi

# Step 8: Generate documentation
log ""
log "===================================================================="
log "  [8/8] Generating Build Information"
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
U-Boot:   ${UBOOT_VERSION:-v2024.01}
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

Next Steps:
-----------
1. Test in QEMU:
   /scripts/run-qemu.sh

2. Flash to SD card (on Linux host):
   sudo dd if=${OUTPUT_DIR}/${IMAGE_NAME:-rocky-riscv-unmatched.img} of=/dev/sdX bs=4M status=progress conv=fsync

3. For Windows, use tools like:
   - Rufus
   - Win32 Disk Imager
   - balenaEtcher

4. Insert SD card into HiFive Unmatched
5. Set MSEL switches: 1011 (ON-ON-OFF-ON)
6. Connect serial console (115200 baud)
7. Power on and watch boot process

Default Credentials:
--------------------
Username: root
Password: ${ROOT_PASSWORD:-rockylinux}

Serial Console:
---------------
Device: ttySIF0
Baud: 115200
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
log "  ? BUILD COMPLETE!"
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
log "Next steps:"
log "  1. Test in QEMU:       /scripts/run-qemu.sh"
log "  2. Or flash to SD:     See BUILD_INFO.txt for instructions"
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
