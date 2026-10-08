#!/bin/bash
# Build U-Boot bootloader for HiFive Unmatched

set -e

echo "===================================="
echo "Building U-Boot Bootloader"
echo "===================================="

# Get workspace root (../workspace from scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../workspace" && pwd)"

# Configuration
UBOOT_VERSION=${UBOOT_VERSION:-v2026.07}
BUILD_DIR=${BUILD_DIR:-${WORKSPACE_ROOT}/build}
UBOOT_DIR="${BUILD_DIR}/u-boot"

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

# Check if OpenSBI was built
if [ -f "${BUILD_DIR}/.env" ]; then
    source "${BUILD_DIR}/.env"
fi

if [ -z "${OPENSBI}" ] || [ ! -f "${OPENSBI}" ]; then
    echo "ERROR: OpenSBI firmware not found!"
    echo "Please run build-opensbi.sh first."
    exit 1
fi

echo "Using OpenSBI: ${OPENSBI}"

# Download U-Boot if not exists
if [ ! -d "${UBOOT_DIR}" ]; then
    echo "Downloading U-Boot ${UBOOT_VERSION}..."
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"
    
    # Remove 'v' prefix for tarball URL
    VERSION_NO_V=${UBOOT_VERSION#v}
    TARBALL_URL="https://ftp.denx.de/pub/u-boot/u-boot-${VERSION_NO_V}.tar.bz2"
    
    echo "Downloading from: ${TARBALL_URL}"
    wget -O u-boot.tar.bz2 "${TARBALL_URL}"
    
    echo "Extracting..."
    tar xf u-boot.tar.bz2
    mv u-boot-${VERSION_NO_V} u-boot
    rm u-boot.tar.bz2
    
    echo "U-Boot ${UBOOT_VERSION} downloaded and extracted"
fi

cd "${UBOOT_DIR}"

# Clean previous build
echo "Cleaning previous build..."
make clean || true

# Configure for HiFive Unmatched
echo "Configuring for HiFive Unmatched..."
make CROSS_COMPILE=${CROSS_COMPILE} sifive_unmatched_defconfig

# Create a temporary PATH that puts system Python BEFORE toolchain Python
# This ensures all Python calls use system Python which has setuptools
echo "Setting up Python environment..."
export PYTHON=/usr/bin/python3
export PYTHON3=/usr/bin/python3
export ORIG_PATH="${PATH}"
# Remove toolchain bin from PATH temporarily to prevent its Python from being used
export PATH=$(echo "${PATH}" | sed 's|/opt/riscv/toolchain/bin:||g')
# Add it back at the end so gcc is still available
export PATH="${PATH}:/opt/riscv/toolchain/bin"

echo "Python check:"
which python3
python3 --version
python3 -c "import setuptools; print('setuptools:', setuptools.__version__)"

# Build U-Boot
echo "Building U-Boot..."
make CROSS_COMPILE=${CROSS_COMPILE} \
     OPENSBI=${OPENSBI} \
     PYTHON=/usr/bin/python3 \
     -j$(nproc)

# Restore original PATH
export PATH="${ORIG_PATH}"

# Verify build outputs
SPL="${UBOOT_DIR}/spl/u-boot-spl.bin"
ITB="${UBOOT_DIR}/u-boot.itb"

if [ ! -f "${SPL}" ]; then
    echo "ERROR: U-Boot SPL build failed! u-boot-spl.bin not found."
    exit 1
fi

if [ ! -f "${ITB}" ]; then
    echo "ERROR: U-Boot ITB build failed! u-boot.itb not found."
    exit 1
fi

# Get file sizes
SPL_SIZE=$(stat -c%s "${SPL}")
ITB_SIZE=$(stat -c%s "${ITB}")

echo "U-Boot build successful!"
echo "SPL:  ${SPL} (${SPL_SIZE} bytes / ~$(( SPL_SIZE / 1024 ))KB)"
echo "ITB:  ${ITB} (${ITB_SIZE} bytes / ~$(( ITB_SIZE / 1024 ))KB)"

# Create checksums
cd "${UBOOT_DIR}"
sha256sum spl/u-boot-spl.bin > spl/u-boot-spl.bin.sha256
sha256sum u-boot.itb > u-boot.itb.sha256
echo "Checksums created"

# Copy to output directory
OUTPUT_DIR=${OUTPUT_DIR:-/workspace/output}
mkdir -p "${OUTPUT_DIR}"
cp spl/u-boot-spl.bin "${OUTPUT_DIR}/"
cp u-boot.itb "${OUTPUT_DIR}/"
cp spl/u-boot-spl.bin.sha256 "${OUTPUT_DIR}/"
cp u-boot.itb.sha256 "${OUTPUT_DIR}/"
echo "Artifacts copied to ${OUTPUT_DIR}"

echo "===================================="
echo "U-Boot build complete!"
echo "===================================="
