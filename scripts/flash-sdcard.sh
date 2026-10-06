#!/bin/bash
# Flash the built image to a physical SD card

set -e

echo "===================================="
echo "SD Card Flash Utility"
echo "===================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Get workspace root (../workspace from scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../workspace" && pwd)"

# Configuration
OUTPUT_DIR=${OUTPUT_DIR:-${WORKSPACE_ROOT}/output}
IMAGE_NAME=${IMAGE_NAME:-rocky-riscv-unmatched.img}
IMAGE_PATH="${OUTPUT_DIR}/${IMAGE_NAME}"

# Check if image exists
if [ ! -f "${IMAGE_PATH}" ]; then
    echo "ERROR: Image not found at ${IMAGE_PATH}"
    echo "Please run build-all.sh first."
    exit 1
fi

# Check if device was provided
if [ -z "$1" ]; then
    echo "ERROR: No device specified!"
    echo ""
    echo "Usage: sudo $0 /dev/sdX"
    echo ""
    echo "Available devices:"
    lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -E "disk|sd|mmcblk"
    echo ""
    echo "WARNING: Be very careful to select the correct device!"
    echo "         All data on the selected device will be DESTROYED!"
    exit 1
fi

DEVICE=$1

# Validate device
if [ ! -b "${DEVICE}" ]; then
    echo "ERROR: ${DEVICE} is not a valid block device!"
    exit 1
fi

# Check if device is mounted
MOUNTED=$(mount | grep "^${DEVICE}" || true)
if [ -n "${MOUNTED}" ]; then
    echo "ERROR: ${DEVICE} or its partitions are currently mounted:"
    echo "${MOUNTED}"
    echo ""
    echo "Please unmount all partitions first:"
    mount | grep "^${DEVICE}" | awk '{print $1}' | xargs -n1 echo "  umount"
    exit 1
fi

# Display device information
echo ""
echo "Device information:"
lsblk "${DEVICE}" -o NAME,SIZE,TYPE,MODEL,FSTYPE,LABEL
echo ""

# Get device size
DEVICE_SIZE=$(blockdev --getsize64 "${DEVICE}")
IMAGE_SIZE=$(stat -c%s "${IMAGE_PATH}")
DEVICE_SIZE_GB=$((DEVICE_SIZE / 1024 / 1024 / 1024))
IMAGE_SIZE_GB=$((IMAGE_SIZE / 1024 / 1024 / 1024))

echo "Device size: ${DEVICE_SIZE_GB}GB"
echo "Image size:  ${IMAGE_SIZE_GB}GB"

if [ ${IMAGE_SIZE} -gt ${DEVICE_SIZE} ]; then
    echo "ERROR: Image is larger than the device!"
    exit 1
fi

# Final confirmation
echo ""
echo "+------------------------------------------------------------+"
echo "|                       WARNING                              |"
echo "|                                                            |"
echo "|  This will COMPLETELY ERASE all data on ${DEVICE}          |"
echo "|  This operation CANNOT be undone!                          |"
echo "+------------------------------------------------------------+"
echo ""
read -p "Are you absolutely sure you want to continue? (type 'yes'): " CONFIRM

if [ "${CONFIRM}" != "yes" ]; then
    echo "Operation cancelled."
    exit 0
fi

echo ""
echo "Last chance to abort!"
read -p "Type 'DESTROY ${DEVICE}' to proceed: " FINAL_CONFIRM

if [ "${FINAL_CONFIRM}" != "DESTROY ${DEVICE}" ]; then
    echo "Operation cancelled."
    exit 0
fi

# Unmount any automounted partitions (just in case)
echo ""
echo "Unmounting any mounted partitions..."
umount ${DEVICE}* 2>/dev/null || true

# Flash image
echo ""
echo "Flashing image to ${DEVICE}..."
echo "This may take several minutes..."
echo ""

dd if="${IMAGE_PATH}" of="${DEVICE}" bs=4M status=progress conv=fsync

# Sync and verify
echo ""
echo "Syncing filesystems..."
sync

echo "Verifying write..."
dd if="${DEVICE}" of=/dev/null bs=4M count=$((IMAGE_SIZE / 4 / 1024 / 1024)) status=progress

echo ""
echo "===================================="
echo "[OK] SD Card flashed successfully!"
echo "===================================="
echo ""
echo "Partition layout:"
lsblk "${DEVICE}"
echo ""
echo "You can now:"
echo "  1. Safely remove the SD card"
echo "  2. Insert it into HiFive Unmatched"
echo "  3. Set MSEL switches to 1011 (ON-ON-OFF-ON)"
echo "  4. Connect serial console (115200 baud)"
echo "  5. Power on the board"
echo ""
echo "Default login:"
echo "  Username: root"
echo "  Password: ${ROOT_PASSWORD:-rockylinux}"
echo ""
