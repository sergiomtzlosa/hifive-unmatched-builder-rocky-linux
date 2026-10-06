#!/bin/bash
# Build OpenSBI firmware for HiFive Unmatched

set -e

echo "===================================="
echo "Building OpenSBI Firmware"
echo "===================================="

# Get workspace root (../workspace from scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../workspace" && pwd)"

# Configuration
OPENSBI_VERSION=${OPENSBI_VERSION:-v1.3}
BUILD_DIR=${BUILD_DIR:-${WORKSPACE_ROOT}/build}
OPENSBI_DIR="${BUILD_DIR}/opensbi"

# Set CROSS_COMPILE if not already set
if [ -z "$CROSS_COMPILE" ]; then
    export CROSS_COMPILE=riscv64-buildroot-linux-gnu-
fi

echo "Workspace: ${WORKSPACE_ROOT}"
echo "Build dir: ${BUILD_DIR}"
echo "Cross compiler: ${CROSS_COMPILE}"
echo ""

# Verify cross compiler is available
if ! command -v ${CROSS_COMPILE}gcc &> /dev/null; then
    echo "ERROR: RISC-V cross compiler not found!"
    echo "Expected: ${CROSS_COMPILE}gcc"
    echo "PATH: $PATH"
    echo ""
    echo "Please ensure RISC-V toolchain is installed and in PATH."
    exit 1
fi

echo "Using toolchain:"
${CROSS_COMPILE}gcc --version | head -1
echo ""

# Clone OpenSBI if not exists
if [ ! -d "${OPENSBI_DIR}" ]; then
    echo "Cloning OpenSBI repository..."
    git clone https://github.com/riscv/opensbi.git "${OPENSBI_DIR}"
fi

cd "${OPENSBI_DIR}"

# Checkout specific version
echo "Checking out OpenSBI ${OPENSBI_VERSION}..."
git fetch --tags
git checkout ${OPENSBI_VERSION}

# Clean previous build
echo "Cleaning previous build..."
make clean || true

# Build OpenSBI
echo "Building OpenSBI for generic platform..."
make CROSS_COMPILE=${CROSS_COMPILE} \
     PLATFORM=generic \
     FW_PIC=n \
     CC=${CROSS_COMPILE}gcc \
     -j$(nproc)

# Verify build
FIRMWARE="${OPENSBI_DIR}/build/platform/generic/firmware/fw_dynamic.bin"
if [ ! -f "${FIRMWARE}" ]; then
    echo "ERROR: OpenSBI build failed! fw_dynamic.bin not found."
    exit 1
fi

# Get file size
SIZE=$(stat -c%s "${FIRMWARE}")
echo "OpenSBI build successful!"
echo "Firmware: ${FIRMWARE}"
echo "Size: ${SIZE} bytes (~$(( SIZE / 1024 ))KB)"

# Export for U-Boot build
export OPENSBI="${FIRMWARE}"
echo "OPENSBI=${FIRMWARE}" > "${BUILD_DIR}/.env"

# Create checksum
cd "${BUILD_DIR}/opensbi/build/platform/generic/firmware"
sha256sum fw_dynamic.bin > fw_dynamic.bin.sha256
echo "Checksum created: fw_dynamic.bin.sha256"

echo "===================================="
echo "OpenSBI build complete!"
echo "===================================="
