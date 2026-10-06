#!/bin/bash
# Create bootable disk image with U-Boot and rootfs

set -e

echo "===================================="
echo "Creating Bootable Disk Image"
echo "===================================="

# Get workspace root (../workspace from scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../workspace" && pwd)"

# Configuration
BUILD_DIR=${BUILD_DIR:-${WORKSPACE_ROOT}/build}
OUTPUT_DIR=${OUTPUT_DIR:-${WORKSPACE_ROOT}/output}
IMAGE_SIZE=${IMAGE_SIZE:-4G}
IMAGE_NAME=${IMAGE_NAME:-rocky-riscv-unmatched.img}
IMAGE_PATH="${OUTPUT_DIR}/${IMAGE_NAME}"

# Check if U-Boot artifacts exist
UBOOT_SPL="${BUILD_DIR}/u-boot/spl/u-boot-spl.bin"
UBOOT_ITB="${BUILD_DIR}/u-boot/u-boot.itb"
ROOTFS_DIR="${BUILD_DIR}/rootfs/rootfs"

if [ ! -f "${UBOOT_SPL}" ]; then
    echo "ERROR: U-Boot SPL not found at ${UBOOT_SPL}"
    echo "Please run build-uboot.sh first."
    exit 1
fi

if [ ! -f "${UBOOT_ITB}" ]; then
    echo "ERROR: U-Boot ITB not found at ${UBOOT_ITB}"
    echo "Please run build-uboot.sh first."
    exit 1
fi

if [ ! -d "${ROOTFS_DIR}" ]; then
    echo "ERROR: Rootfs not found at ${ROOTFS_DIR}"
    echo "Please run download-rootfs.sh first."
    exit 1
fi

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Remove old image if exists
if [ -f "${IMAGE_PATH}" ]; then
    echo "Removing old image..."
    rm -f "${IMAGE_PATH}"
fi

# Create empty image file
echo "Creating ${IMAGE_SIZE} disk image..."
# Calculate size in MB for dd seek parameter
SIZE_MB=$(echo ${IMAGE_SIZE} | sed 's/G/*1024/' | sed 's/M//' | bc)
# Use truncate for faster sparse file creation
truncate -s ${IMAGE_SIZE} "${IMAGE_PATH}" || {
    echo "ERROR: Failed to create disk image"
    exit 1
}
echo "Disk image created (${IMAGE_SIZE})"
ls -lh "${IMAGE_PATH}"

# Create GPT partition table
echo "Creating GPT partition table..."
sgdisk -g --clear --set-alignment=1 \
    --new=1:34:+1M:      --change-name=1:'spl'           --typecode=1:5b193300-fc78-40cd-8002-e86c45580b47 \
    --new=2:2082:+4M:    --change-name=2:'uboot'         --typecode=2:2e54b353-1271-4842-806f-e436d6af6985 \
    --new=3:16384:-0     --change-name=3:'rootfs'        --typecode=3:0FC63DAF-8483-4772-8E79-3D69D8477DE4 \
    --attributes=3:set:2 \
    "${IMAGE_PATH}"

echo "Partition table created successfully!"
sgdisk -p "${IMAGE_PATH}"

# Setup loop device
echo "Setting up loop device..."
echo "Available loop devices:"
ls -la /dev/loop* 2>/dev/null | head -10 || echo "No loop devices found in /dev"

# Check if loop module is loaded
lsmod | grep loop || echo "Loop module not loaded"

# Try to load loop module if not present
modprobe loop 2>/dev/null || echo "Cannot load loop module (may already be loaded)"

# Verify file exists and is readable
if [ ! -f "${IMAGE_PATH}" ]; then
    echo "ERROR: Image file does not exist: ${IMAGE_PATH}"
    exit 1
fi
echo "Image file: $(ls -lh "${IMAGE_PATH}")"

LOOP_DEV=$(losetup --find --show --partscan "${IMAGE_PATH}" 2>&1)
LOSETUP_EXIT=$?
if [ ${LOSETUP_EXIT} -ne 0 ]; then
    echo "ERROR: losetup failed with exit code ${LOSETUP_EXIT}"
    echo "Output: ${LOOP_DEV}"
    echo ""
    echo "This may be a Docker container limitation."
    echo "Loop devices require:"
    echo "  1. Container running with --privileged flag"
    echo "  2. Or specific capabilities: --cap-add SYS_ADMIN --device /dev/loop-control:/dev/loop-control"
    exit 1
fi
echo "Loop device: ${LOOP_DEV}"

# Force kernel to re-read partition table
partprobe ${LOOP_DEV} 2>/dev/null || true
blockdev --rereadpt ${LOOP_DEV} 2>/dev/null || true
sleep 2

# Verify partitions exist
echo "Checking for partition devices..."
if [ ! -b "${LOOP_DEV}p1" ] || [ ! -b "${LOOP_DEV}p2" ] || [ ! -b "${LOOP_DEV}p3" ]; then
    echo "ERROR: Partition block devices not created"
    echo "Loop device info:"
    losetup -l | grep $(basename ${LOOP_DEV}) || true
    ls -la ${LOOP_DEV}* || true
    
    # Try alternative partition naming (loop24p1 vs loop24_1)
    if [ -b "${LOOP_DEV}1" ]; then
        echo "Using alternative partition naming scheme"
        PART1="${LOOP_DEV}1"
        PART2="${LOOP_DEV}2"
        PART3="${LOOP_DEV}3"
    else
        losetup -d ${LOOP_DEV}
        exit 1
    fi
else
    PART1="${LOOP_DEV}p1"
    PART2="${LOOP_DEV}p2"
    PART3="${LOOP_DEV}p3"
fi

echo "Partition devices:"
ls -la ${LOOP_DEV}* 2>/dev/null || ls -la ${LOOP_DEV}[0-9]* 2>/dev/null

# Write U-Boot SPL
echo "Writing U-Boot SPL to partition 1..."
dd if="${UBOOT_SPL}" of="${PART1}" bs=4k conv=fsync status=progress

# Write U-Boot ITB
echo "Writing U-Boot ITB to partition 2..."
dd if="${UBOOT_ITB}" of="${PART2}" bs=4k conv=fsync status=progress

# Format root partition
echo "Formatting root partition as ext4..."
mkfs.ext4 -F -L rootfs "${PART3}"

# Mount root partition
MOUNT_POINT="/tmp/rootfs-mount-$$"
mkdir -p "${MOUNT_POINT}"
mount "${PART3}" "${MOUNT_POINT}"

echo "Copying rootfs to partition 3..."
rsync -aAXv "${ROOTFS_DIR}/" "${MOUNT_POINT}/"

# Create necessary directories
mkdir -p "${MOUNT_POINT}"/{boot,dev,proc,sys,tmp,run,mnt,media}
chmod 1777 "${MOUNT_POINT}/tmp"

echo "Rootfs copied successfully!"
df -h "${MOUNT_POINT}"

# Unmount and cleanup
echo "Cleaning up..."
umount "${MOUNT_POINT}"
rmdir "${MOUNT_POINT}"
losetup -d "${LOOP_DEV}"

# Calculate and display final size
IMAGE_SIZE_MB=$(du -m "${IMAGE_PATH}" | cut -f1)
echo "===================================="
echo "Disk image created successfully!"
echo "Location: ${IMAGE_PATH}"
echo "Size: ${IMAGE_SIZE_MB} MB"
echo "===================================="
echo ""
echo "Next steps:"
echo "  1. Run setup-boot.sh to configure boot files"
echo "  2. Run run-qemu.sh to test in emulator"
echo "  3. Or flash to SD card with flash-sdcard.sh"
