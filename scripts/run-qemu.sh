#!/bin/bash
# Run the built image in QEMU RISC-V emulator

set -e

echo "===================================="
echo "Starting QEMU RISC-V Emulator"
echo "===================================="

# Get workspace root (../workspace from scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../workspace" && pwd)"

# Configuration
BUILD_DIR=${BUILD_DIR:-${WORKSPACE_ROOT}/build}
OUTPUT_DIR=${OUTPUT_DIR:-${WORKSPACE_ROOT}/output}
IMAGE_NAME=${IMAGE_NAME:-rocky-riscv-unmatched.img}
IMAGE_PATH="${OUTPUT_DIR}/${IMAGE_NAME}"

OPENSBI="${BUILD_DIR}/opensbi/build/platform/generic/firmware/fw_dynamic.bin"
UBOOT="${BUILD_DIR}/u-boot/u-boot.bin"

QEMU_MEMORY=${QEMU_MEMORY:-4G}
QEMU_CPUS=${QEMU_CPUS:-4}
QEMU_SSH_PORT=${QEMU_SSH_PORT:-2222}

# Check if image exists
if [ ! -f "${IMAGE_PATH}" ]; then
    echo "ERROR: Image not found at ${IMAGE_PATH}"
    echo "Please run create-image.sh first."
    exit 1
fi

# Check if OpenSBI exists
if [ ! -f "${OPENSBI}" ]; then
    echo "ERROR: OpenSBI firmware not found at ${OPENSBI}"
    echo "Please run build-opensbi.sh first."
    exit 1
fi

# Check if U-Boot exists
if [ ! -f "${UBOOT}" ]; then
    echo "ERROR: U-Boot not found at ${UBOOT}"
    echo "Please run build-uboot.sh first."
    exit 1
fi

# Check if QEMU is installed
if ! command -v qemu-system-riscv64 &> /dev/null; then
    echo "ERROR: qemu-system-riscv64 not found!"
    echo "Please install QEMU with RISC-V support."
    exit 1
fi

QEMU_VERSION=$(qemu-system-riscv64 --version | head -1)
echo "QEMU version: ${QEMU_VERSION}"

echo ""
echo "Starting QEMU with configuration:"
echo "  Machine: virt"
echo "  CPU: rv64, ${QEMU_CPUS} cores"
echo "  Memory: ${QEMU_MEMORY}"
echo "  Disk: ${IMAGE_PATH}"
echo "  Firmware: ${OPENSBI}"
echo "  Bootloader: ${UBOOT}"
echo "  SSH forwarding: localhost:${QEMU_SSH_PORT} -> guest:22"
echo ""
echo "To exit QEMU: Press Ctrl+A, then X"
echo "To access via SSH (once booted): ssh -p ${QEMU_SSH_PORT} root@localhost"
echo ""
echo "Starting in 3 seconds..."
sleep 3

# Launch QEMU
qemu-system-riscv64 \
    -M virt \
    -cpu rv64 \
    -smp ${QEMU_CPUS} \
    -m ${QEMU_MEMORY} \
    -bios ${OPENSBI} \
    -kernel ${UBOOT} \
    -device virtio-blk-device,drive=hd0 \
    -drive file=${IMAGE_PATH},format=raw,id=hd0 \
    -device virtio-net-device,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::${QEMU_SSH_PORT}-:22 \
    -nographic

echo ""
echo "QEMU session ended."
