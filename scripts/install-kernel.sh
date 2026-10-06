#!/bin/bash
# Install kernel into the rootfs image

set -e

echo "===================================="
echo "Installing Kernel to Rootfs"
echo "===================================="

# Get workspace root (../workspace from scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../workspace" && pwd)"

OUTPUT_DIR=${OUTPUT_DIR:-${WORKSPACE_ROOT}/output}
IMAGE_NAME=${IMAGE_NAME:-rocky-riscv-unmatched.img}
IMAGE_PATH="${OUTPUT_DIR}/${IMAGE_NAME}"
KERNEL_OUTPUT="${OUTPUT_DIR}/kernel"

# Check if image exists
if [ ! -f "${IMAGE_PATH}" ]; then
    echo "ERROR: Image not found at ${IMAGE_PATH}"
    echo "Please run create-image.sh first."
    exit 1
fi

# Check if kernel files exist
if [ ! -d "${KERNEL_OUTPUT}" ]; then
    echo "ERROR: Kernel output directory not found at ${KERNEL_OUTPUT}"
    echo "Please run build-kernel.sh first."
    exit 1
fi

# Get kernel version
if [ ! -f "${OUTPUT_DIR}/KERNEL_VERSION" ]; then
    echo "ERROR: KERNEL_VERSION file not found"
    echo "Please run build-kernel.sh first."
    exit 1
fi

KERNEL_RELEASE=$(cat "${OUTPUT_DIR}/KERNEL_VERSION")
echo "Kernel version: ${KERNEL_RELEASE}"

# Check for kernel files
KERNEL_IMAGE="${KERNEL_OUTPUT}/vmlinuz-${KERNEL_RELEASE}"
INITRAMFS="${KERNEL_OUTPUT}/initramfs-${KERNEL_RELEASE}.img"
MODULES_ARCHIVE="${KERNEL_OUTPUT}/modules-${KERNEL_RELEASE}.tar.gz"
DTB_DIR="${KERNEL_OUTPUT}/dtbs/${KERNEL_RELEASE}"

if [ ! -f "${KERNEL_IMAGE}" ]; then
    echo "ERROR: Kernel image not found: ${KERNEL_IMAGE}"
    exit 1
fi

if [ ! -f "${INITRAMFS}" ]; then
    echo "ERROR: Initramfs not found: ${INITRAMFS}"
    exit 1
fi

if [ ! -f "${MODULES_ARCHIVE}" ]; then
    echo "WARNING: Kernel modules not found: ${MODULES_ARCHIVE}"
fi

if [ ! -d "${DTB_DIR}" ]; then
    echo "ERROR: Device tree directory not found: ${DTB_DIR}"
    exit 1
fi

echo ""
echo "Installing kernel files to image..."
echo ""

# Function to cleanup on exit
cleanup() {
    local exit_code=$?
    if [ -n "${MOUNT_POINT}" ] && mountpoint -q "${MOUNT_POINT}" 2>/dev/null; then
        echo "Unmounting ${MOUNT_POINT}..."
        cd / # Ensure we're not in the mount point
        sync
        umount "${MOUNT_POINT}" 2>/dev/null || umount -l "${MOUNT_POINT}" 2>/dev/null
    fi
    if [ -n "${MOUNT_POINT}" ] && [ -d "${MOUNT_POINT}" ]; then
        rmdir "${MOUNT_POINT}" 2>/dev/null
    fi
    if [ -n "${LOOP_DEV}" ] && losetup "${LOOP_DEV}" &>/dev/null; then
        losetup -d "${LOOP_DEV}" 2>/dev/null
    fi
    if [ $exit_code -ne 0 ]; then
        echo "Error occurred during installation. Cleanup completed."
    fi
    exit $exit_code
}

# Set trap to cleanup on exit
trap cleanup EXIT INT TERM

# Mount the image
echo "Mounting image..."
LOOP_DEV=$(losetup --partscan --find --show "${IMAGE_PATH}")
# Give kernel time to create partition devices
sleep 2
MOUNT_POINT="/tmp/rootfs-kernel-$$"
mkdir -p "${MOUNT_POINT}"
mount "${LOOP_DEV}p3" "${MOUNT_POINT}"

# Ensure boot directory exists
echo "Creating boot directory structure..."
mkdir -p "${MOUNT_POINT}/boot"
mkdir -p "${MOUNT_POINT}/boot/extlinux"

# Copy kernel
echo "Installing kernel image..."
cp "${KERNEL_IMAGE}" "${MOUNT_POINT}/boot/"
echo "[OK] Copied: vmlinuz-${KERNEL_RELEASE}"

# Copy initramfs
echo "Installing initramfs..."
cp "${INITRAMFS}" "${MOUNT_POINT}/boot/"
echo "[OK] Copied: initramfs-${KERNEL_RELEASE}.img"

# Copy device tree blobs
echo "Installing device tree files..."
rm -rf "${MOUNT_POINT}/boot/dtbs"
cp -r "${KERNEL_OUTPUT}/dtbs" "${MOUNT_POINT}/boot/"
echo "[OK] Copied: dtbs/${KERNEL_RELEASE}/"

# Verify critical DTB
if [ -f "${MOUNT_POINT}/boot/dtbs/${KERNEL_RELEASE}/sifive/hifive-unmatched-a00.dtb" ]; then
    echo "[OK] HiFive Unmatched device tree installed"
else
    echo "WARNING: HiFive Unmatched device tree not found!"
fi

# Install kernel modules if available
if [ -f "${MODULES_ARCHIVE}" ]; then
    echo "Installing kernel modules..."
    # Extract to mount point without changing directory
    tar xzf "${MODULES_ARCHIVE}" -C "${MOUNT_POINT}"
    echo "[OK] Installed: kernel modules"
fi

# Verify installation
echo ""
echo "Verifying installation..."
echo ""
echo "Kernel files in /boot:"
ls -lh "${MOUNT_POINT}/boot/" | grep -E "vmlinuz|initramfs"
echo ""
echo "Device tree files:"
find "${MOUNT_POINT}/boot/dtbs" -name "hifive-unmatched*.dtb"
echo ""

if [ -d "${MOUNT_POINT}/lib/modules/${KERNEL_RELEASE}" ]; then
    echo "Kernel modules installed:"
    echo "  ${KERNEL_RELEASE}"
    MODULE_COUNT=$(find "${MOUNT_POINT}/lib/modules/${KERNEL_RELEASE}" -name "*.ko" | wc -l)
    echo "  Total modules: ${MODULE_COUNT}"
fi

echo ""
echo "===================================="
echo "Installation Summary"
echo "===================================="
echo "Kernel: vmlinuz-${KERNEL_RELEASE}"
echo "Initramfs: initramfs-${KERNEL_RELEASE}.img"
echo "DTB: dtbs/${KERNEL_RELEASE}/sifive/hifive-unmatched-a00.dtb"
if [ -f "${MODULES_ARCHIVE}" ]; then
    echo "Modules: ${MODULE_COUNT} kernel modules installed"
fi
echo ""

# Cleanup will be handled by trap
echo "Cleaning up..."
# The trap will handle unmounting and cleanup

echo "===================================="
echo "Kernel installation complete!"
echo "===================================="
echo ""
echo "Next step: Run setup-boot.sh to configure bootloader"

