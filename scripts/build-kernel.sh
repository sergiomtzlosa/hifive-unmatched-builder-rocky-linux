#!/bin/bash
# Build Linux kernel for HiFive Unmatched RISC-V board

set -e

echo "===================================="
echo "Building Linux Kernel"
echo "===================================="

# Get workspace root (../workspace from scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../workspace" && pwd)"

BUILD_DIR=${BUILD_DIR:-${WORKSPACE_ROOT}/build}
OUTPUT_DIR=${OUTPUT_DIR:-${WORKSPACE_ROOT}/output}
KERNEL_BUILD_DIR="${BUILD_DIR}/linux"

# Kernel configuration
KERNEL_VERSION=${KERNEL_VERSION:-v6.6}
KERNEL_REPO="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"

# Toolchain - should be set in environment
if [ -z "${CROSS_COMPILE}" ]; then
    echo "WARNING: CROSS_COMPILE not set, defaulting to riscv64-buildroot-linux-gnu-"
    export CROSS_COMPILE=riscv64-buildroot-linux-gnu-
fi

# Verify toolchain
if ! command -v ${CROSS_COMPILE}gcc &> /dev/null; then
    echo "ERROR: Cross compiler ${CROSS_COMPILE}gcc not found!"
    echo "Please install RISC-V toolchain first."
    exit 1
fi

echo "Toolchain: $(${CROSS_COMPILE}gcc --version | head -1)"
echo "Kernel version: ${KERNEL_VERSION}"
echo "Build directory: ${KERNEL_BUILD_DIR}"
echo ""

# Clone or update kernel source
if [ ! -d "${KERNEL_BUILD_DIR}" ]; then
    echo "Cloning Linux kernel repository..."
    git clone --depth 1 --branch ${KERNEL_VERSION} ${KERNEL_REPO} "${KERNEL_BUILD_DIR}"
else
    echo "Linux kernel source already exists, updating..."
    cd "${KERNEL_BUILD_DIR}"
    git fetch --depth 1 origin ${KERNEL_VERSION}
    git checkout ${KERNEL_VERSION}
fi

cd "${KERNEL_BUILD_DIR}"

echo ""
echo "Configuring kernel..."

# Use defconfig for RISC-V
make ARCH=riscv CROSS_COMPILE=${CROSS_COMPILE} defconfig

# Enable necessary features for HiFive Unmatched
# These can be set via defconfig or menuconfig
cat >> .config << 'EOF'
# HiFive Unmatched specific options
CONFIG_SOC_SIFIVE=y
CONFIG_SERIAL_SIFIVE=y
CONFIG_SERIAL_SIFIVE_CONSOLE=y
CONFIG_SPI_SIFIVE=y
CONFIG_PWM_SIFIVE=y
CONFIG_GPIO_SIFIVE=y
CONFIG_HW_RANDOM_VIRTIO=y
CONFIG_MMC=y
CONFIG_MMC_SPI=y
CONFIG_MMC_SDHCI=y
CONFIG_MMC_SDHCI_PLTFM=y
CONFIG_MMC_SDHCI_CADENCE=y
CONFIG_PCI=y
CONFIG_PCIE_XILINX=y
CONFIG_USB=y
CONFIG_USB_XHCI_HCD=y
CONFIG_USB_XHCI_PLATFORM=y
CONFIG_USB_STORAGE=y
CONFIG_EXT4_FS=y
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_BLK_DEV_INITRD=y
EOF

# Run olddefconfig to resolve any dependencies
make ARCH=riscv CROSS_COMPILE=${CROSS_COMPILE} olddefconfig

echo ""
echo "Starting kernel compilation..."
echo "This will take a while (15-30 minutes)..."
echo ""

# Get number of CPU cores for parallel build
NPROC=$(nproc 2>/dev/null || echo 4)
echo "Using ${NPROC} parallel jobs"

# Build kernel, modules, and device trees
make ARCH=riscv CROSS_COMPILE=${CROSS_COMPILE} -j${NPROC} \
    Image \
    modules \
    dtbs

echo ""
echo "Kernel compilation completed!"
echo ""

# Get kernel version string
KERNEL_RELEASE=$(make ARCH=riscv CROSS_COMPILE=${CROSS_COMPILE} -s kernelrelease)
echo "Kernel version: ${KERNEL_RELEASE}"

# Create output structure
KERNEL_OUTPUT="${OUTPUT_DIR}/kernel"
mkdir -p "${KERNEL_OUTPUT}"

# Copy kernel image
echo "Copying kernel image..."
cp arch/riscv/boot/Image "${KERNEL_OUTPUT}/vmlinuz-${KERNEL_RELEASE}"

# Create initramfs (empty for now - can be populated later)
echo "Creating initramfs..."
INITRAMFS_DIR="${BUILD_DIR}/initramfs"
mkdir -p "${INITRAMFS_DIR}"
cd "${INITRAMFS_DIR}"
mkdir -p bin sbin etc proc sys dev tmp lib

# Create a minimal init script
cat > init << 'INIT_EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
exec /sbin/init
INIT_EOF
chmod +x init

# Create initramfs
cd "${INITRAMFS_DIR}"
find . | cpio -o -H newc | gzip > "${KERNEL_OUTPUT}/initramfs-${KERNEL_RELEASE}.img"

echo "Initramfs created: initramfs-${KERNEL_RELEASE}.img"

# Copy device tree blobs
echo "Copying device tree files..."
mkdir -p "${KERNEL_OUTPUT}/dtbs/${KERNEL_RELEASE}"
cd "${KERNEL_BUILD_DIR}"
cp -r arch/riscv/boot/dts/sifive "${KERNEL_OUTPUT}/dtbs/${KERNEL_RELEASE}/"

# Verify critical DTB exists
if [ -f "${KERNEL_OUTPUT}/dtbs/${KERNEL_RELEASE}/sifive/hifive-unmatched-a00.dtb" ]; then
    echo "[OK] HiFive Unmatched device tree found"
else
    echo "WARNING: HiFive Unmatched device tree not found!"
fi

# Install kernel modules to a staging directory
echo ""
echo "Installing kernel modules..."
MODULES_STAGING="${BUILD_DIR}/modules"
mkdir -p "${MODULES_STAGING}"
cd "${KERNEL_BUILD_DIR}"
make ARCH=riscv CROSS_COMPILE=${CROSS_COMPILE} \
    INSTALL_MOD_PATH="${MODULES_STAGING}" \
    modules_install

echo ""
echo "Creating modules archive..."
cd "${MODULES_STAGING}"
tar czf "${KERNEL_OUTPUT}/modules-${KERNEL_RELEASE}.tar.gz" lib/modules/${KERNEL_RELEASE}

echo ""
echo "===================================="
echo "Kernel Build Summary"
echo "===================================="
echo "Kernel version: ${KERNEL_RELEASE}"
echo ""
echo "Files created in ${KERNEL_OUTPUT}:"
ls -lh "${KERNEL_OUTPUT}/"
echo ""
echo "Device trees:"
find "${KERNEL_OUTPUT}/dtbs" -name "*.dtb" | head -5
echo ""
echo "Modules archive: modules-${KERNEL_RELEASE}.tar.gz"
echo ""
echo "===================================="
echo "Kernel build complete!"
echo "===================================="

# Save kernel version for later use
echo "${KERNEL_RELEASE}" > "${OUTPUT_DIR}/KERNEL_VERSION"

