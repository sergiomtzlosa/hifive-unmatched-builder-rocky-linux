#!/bin/bash
# Setup boot configuration in the rootfs

set -e

echo "===================================="
echo "Configuring Boot Files"
echo "===================================="

# Get workspace root (../workspace from scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../workspace" && pwd)"

OUTPUT_DIR=${OUTPUT_DIR:-${WORKSPACE_ROOT}/output}
IMAGE_NAME=${IMAGE_NAME:-rocky-riscv-unmatched.img}
IMAGE_PATH="${OUTPUT_DIR}/${IMAGE_NAME}"

if [ ! -f "${IMAGE_PATH}" ]; then
    echo "ERROR: Image not found at ${IMAGE_PATH}"
    echo "Please run create-image.sh first."
    exit 1
fi

# Mount the image
echo "Mounting image..."
LOOP_DEV=$(losetup --partscan --find --show "${IMAGE_PATH}")
# Give kernel time to create partition devices
sleep 2
MOUNT_POINT="/tmp/rootfs-config-$$"
mkdir -p "${MOUNT_POINT}"
mount "${LOOP_DEV}p3" "${MOUNT_POINT}"

# Create boot directory structure
echo "Creating boot directory structure..."
mkdir -p "${MOUNT_POINT}/boot/extlinux"
mkdir -p "${MOUNT_POINT}/boot/dtbs"

# Check for kernel in rootfs
KERNEL_PATH=$(find "${MOUNT_POINT}/boot" -name "vmlinuz*" -o -name "vmlinux*" 2>/dev/null | head -1)
if [ -z "${KERNEL_PATH}" ]; then
    echo "WARNING: No kernel found in rootfs!"
    echo "You'll need to install a kernel manually or build one."
    KERNEL_VERSION="KERNEL_VERSION"
else
    KERNEL_FILE=$(basename "${KERNEL_PATH}")
    KERNEL_VERSION=$(echo ${KERNEL_FILE} | sed 's/vmlinuz-//;s/vmlinux-//')
    echo "Found kernel: ${KERNEL_FILE} (version: ${KERNEL_VERSION})"
fi

# Create extlinux.conf
echo "Creating extlinux.conf..."
cat << EOF | tee "${MOUNT_POINT}/boot/extlinux/extlinux.conf" >/dev/null
menu title Rocky Linux on HiFive Unmatched
timeout 50
default rocky

label rocky
    menu label Rocky Linux (kernel ${KERNEL_VERSION})
    kernel /boot/vmlinuz-${KERNEL_VERSION}
    fdt /boot/dtbs/${KERNEL_VERSION}/sifive/hifive-unmatched-a00.dtb
    initrd /boot/initramfs-${KERNEL_VERSION}.img
    append earlyprintk rw root=/dev/mmcblk0p3 rootfstype=ext4 rootwait console=ttySIF0,115200 LANG=en_US.UTF-8 earlycon

label rocky-recovery
    menu label Rocky Linux (recovery mode)
    kernel /boot/vmlinuz-${KERNEL_VERSION}
    fdt /boot/dtbs/${KERNEL_VERSION}/sifive/hifive-unmatched-a00.dtb
    initrd /boot/initramfs-${KERNEL_VERSION}.img
    append earlyprintk rw root=/dev/mmcblk0p3 rootfstype=ext4 rootwait console=ttySIF0,115200 LANG=en_US.UTF-8 earlycon single
EOF

echo "extlinux.conf created"

# Configure fstab
echo "Configuring /etc/fstab..."
cat << EOF | tee "${MOUNT_POINT}/etc/fstab" >/dev/null
# <file system>        <mount point>   <type>  <options>                    <dump>  <pass>
LABEL=rootfs           /               ext4    defaults,noatime             0       1
tmpfs                  /tmp            tmpfs   defaults,noatime,mode=1777   0       0
EOF

# Set hostname
echo "Setting hostname..."
echo "hifive-unmatched" | tee "${MOUNT_POINT}/etc/hostname" >/dev/null

# Configure hosts
echo "Configuring /etc/hosts..."
cat << EOF | tee "${MOUNT_POINT}/etc/hosts" >/dev/null
127.0.0.1   localhost
127.0.1.1   hifive-unmatched
::1         localhost ip6-localhost ip6-loopback
EOF

# Enable serial console
echo "Enabling serial console..."
if [ ! -d "${MOUNT_POINT}/etc/systemd/system/getty.target.wants" ]; then
    mkdir -p "${MOUNT_POINT}/etc/systemd/system/getty.target.wants"
fi

# Link serial console service
if [ -f "${MOUNT_POINT}/usr/lib/systemd/system/serial-getty@.service" ]; then
    ln -sf /usr/lib/systemd/system/serial-getty@.service \
        "${MOUNT_POINT}/etc/systemd/system/getty.target.wants/serial-getty@ttySIF0.service"
    echo "Serial console enabled on ttySIF0"
fi

# Set root password
echo "Setting root password..."
ROOT_PASSWORD=${ROOT_PASSWORD:-rockylinux}
echo "root:${ROOT_PASSWORD}" | chroot "${MOUNT_POINT}" chpasswd 2>/dev/null || \
    echo "WARNING: Could not set root password. Set it manually after first boot."

# Configure network (DHCP)
echo "Configuring network..."
mkdir -p "${MOUNT_POINT}/etc/systemd/network"
cat << EOF | tee "${MOUNT_POINT}/etc/systemd/network/20-wired.network" >/dev/null
[Match]
Name=eth* en*

[Network]
DHCP=yes
EOF

# Enable networkd if available
if [ -d "${MOUNT_POINT}/etc/systemd/system/multi-user.target.wants" ]; then
    ln -sf /usr/lib/systemd/system/systemd-networkd.service \
        "${MOUNT_POINT}/etc/systemd/system/multi-user.target.wants/systemd-networkd.service" 2>/dev/null || true
fi

# Display configuration
echo ""
echo "Configuration summary:"
echo "  Hostname: hifive-unmatched"
echo "  Root password: ${ROOT_PASSWORD}"
echo "  Serial console: ttySIF0 @ 115200"
echo "  Network: DHCP on all interfaces"
echo "  Root device: /dev/mmcblk0p3"

# Cleanup
echo "Cleaning up..."
umount "${MOUNT_POINT}"
rmdir "${MOUNT_POINT}"
losetup -d "${LOOP_DEV}"

echo "===================================="
echo "Boot configuration complete!"
echo "===================================="
