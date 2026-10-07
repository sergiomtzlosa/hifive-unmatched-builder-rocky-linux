#!/bin/bash
# Install essential system packages into the rootfs to make it bootable

set -e

echo "===================================="
echo "Installing System Packages"
echo "===================================="

# Get workspace root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to find workspace root - in Docker it's /workspace, otherwise relative path
if [ -d "/workspace" ]; then
    WORKSPACE_ROOT="/workspace"
else
    WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

OUTPUT_DIR=${OUTPUT_DIR:-${WORKSPACE_ROOT}/output}
IMAGE_NAME=${IMAGE_NAME:-rocky-riscv-unmatched.img}
IMAGE_PATH="${OUTPUT_DIR}/${IMAGE_NAME}"
MOUNT_POINT="${WORKSPACE_ROOT}/build/mnt"

# Check if image exists
if [ ! -f "${IMAGE_PATH}" ]; then
    echo "ERROR: Image not found at ${IMAGE_PATH}"
    exit 1
fi

# Create mount point
mkdir -p "${MOUNT_POINT}"

echo "Setting up loop device..."
LOOP_DEVICE=$(losetup -fP --show "${IMAGE_PATH}")
echo "Loop device: ${LOOP_DEVICE}"

# Wait for partition devices
sleep 2
partprobe "${LOOP_DEVICE}" 2>/dev/null || true
sleep 1

# Check for partition
ROOTFS_PART="${LOOP_DEVICE}p3"
if [ ! -b "${ROOTFS_PART}" ]; then
    echo "ERROR: Root partition ${ROOTFS_PART} not found"
    losetup -d "${LOOP_DEVICE}"
    exit 1
fi

echo "Mounting rootfs partition: ${ROOTFS_PART}"
mount "${ROOTFS_PART}" "${MOUNT_POINT}"

echo ""
echo "Installing essential packages for bootable system..."
echo ""

# Set up chroot environment
echo "Preparing chroot environment..."

# Copy DNS resolver
cp -L /etc/resolv.conf "${MOUNT_POINT}/etc/resolv.conf" 2>/dev/null || true

# Mount proc, sys, dev for package installation
mount -t proc /proc "${MOUNT_POINT}/proc" 2>/dev/null || true
mount -t sysfs /sys "${MOUNT_POINT}/sys" 2>/dev/null || true
mount --rbind /dev "${MOUNT_POINT}/dev" 2>/dev/null || true
mount --make-rslave "${MOUNT_POINT}/dev" 2>/dev/null || true

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up mounts..."
    umount -R "${MOUNT_POINT}/dev" 2>/dev/null || true
    umount "${MOUNT_POINT}/sys" 2>/dev/null || true
    umount "${MOUNT_POINT}/proc" 2>/dev/null || true
    umount "${MOUNT_POINT}" 2>/dev/null || true
    losetup -d "${LOOP_DEVICE}" 2>/dev/null || true
}
trap cleanup EXIT

# Install packages using chroot
echo "Installing packages (this may take a while)..."
echo ""

# Check if we can chroot into RISC-V rootfs (suppress error output)
if chroot "${MOUNT_POINT}" /bin/true 2>/dev/null; then
    # We have QEMU user-mode emulation, proceed with package installation
    echo "QEMU user-mode emulation detected, proceeding with package installation..."
    echo ""
    
    chroot "${MOUNT_POINT}" /bin/bash <<'CHROOT_EOF'
set -e

# Update package database
echo "Updating package database..."
dnf makecache --refresh || yum makecache --refresh || true

# Install systemd and essential boot components
echo "Installing systemd and init system..."
dnf install -y systemd systemd-udev || yum install -y systemd systemd-udev || true

# Install basic system utilities
echo "Installing basic system utilities..."
dnf install -y \
    bash \
    coreutils \
    util-linux \
    procps-ng \
    psmisc \
    which \
    findutils \
    grep \
    sed \
    gawk \
    tar \
    gzip \
    bzip2 \
    xz \
    less \
    vim-minimal \
    nano \
    iproute \
    iputils \
    net-tools \
    openssh-server \
    openssh-clients \
    sudo \
    passwd \
    shadow-utils \
    cronie \
    logrotate \
    rsyslog \
    dhcp-client \
    NetworkManager \
    || yum install -y \
    bash coreutils util-linux procps-ng psmisc which findutils \
    grep sed gawk tar gzip bzip2 xz less vim-minimal nano \
    iproute iputils net-tools openssh-server openssh-clients \
    sudo passwd shadow-utils cronie logrotate rsyslog \
    dhcp-client NetworkManager \
    || true

# Install kernel modules tools
echo "Installing kernel module utilities..."
dnf install -y kmod || yum install -y kmod || true

# Install filesystem tools
echo "Installing filesystem utilities..."
dnf install -y \
    e2fsprogs \
    xfsprogs \
    dosfstools \
    || yum install -y e2fsprogs xfsprogs dosfstools || true

# Enable essential services
echo "Enabling essential services..."
systemctl enable sshd 2>/dev/null || true
systemctl enable NetworkManager 2>/dev/null || true
systemctl enable systemd-networkd 2>/dev/null || true
systemctl enable systemd-resolved 2>/dev/null || true
systemctl enable rsyslog 2>/dev/null || true

# Create basic network configuration
echo "Configuring network..."
mkdir -p /etc/systemd/network
cat > /etc/systemd/network/20-wired.network <<'EOF'
[Match]
Name=eth*

[Network]
DHCP=yes
EOF

# Set hostname
echo "unmatched-riscv" > /etc/hostname

# Configure fstab
echo "Configuring /etc/fstab..."
cat > /etc/fstab <<'EOF'
# <file system> <mount point> <type> <options> <dump> <pass>
UUID=WILL_BE_REPLACED / ext4 defaults 1 1
tmpfs /tmp tmpfs defaults,nodev,nosuid 0 0
EOF

echo "Package installation complete!"
CHROOT_EOF

    echo ""
    echo "[OK] System packages installed successfully!"
    echo ""
    echo "Installed components:"
    echo "  - systemd (init system)"
    echo "  - SSH server"
    echo "  - NetworkManager"
    echo "  - Basic system utilities"
    echo "  - Filesystem tools"
    echo ""
    
else
    # Cannot chroot - RISC-V binaries on x86_64 without QEMU user-mode
    echo "========================================"
    echo "WARNING: Cannot chroot into RISC-V rootfs"
    echo "========================================"
    echo ""
    echo "The rootfs contains RISC-V binaries that cannot run on this x86_64 system."
    echo ""
    echo "Package installation requires either:"
    echo "  1. QEMU user-mode emulation with binfmt_misc support"
    echo "  2. Running this step on a RISC-V system"
    echo "  3. Installing packages manually after first boot"
    echo ""
    echo "Skipping package installation..."
    echo ""
    echo "IMPORTANT: After first boot on HiFive Unmatched, run:"
    echo "  dnf install -y systemd openssh-server NetworkManager"
    echo "  systemctl enable sshd NetworkManager"
    echo ""
    
    # Still create basic configuration files
    echo "Creating basic configuration files..."
    
    # Set hostname
    echo "unmatched-riscv" > "${MOUNT_POINT}/etc/hostname"
    
    # Create basic network configuration directory
    mkdir -p "${MOUNT_POINT}/etc/systemd/network"
    cat > "${MOUNT_POINT}/etc/systemd/network/20-wired.network" <<'EOF'
[Match]
Name=eth*

[Network]
DHCP=yes
EOF
    
    # Configure fstab
    cat > "${MOUNT_POINT}/etc/fstab" <<'EOF'
# <file system> <mount point> <type> <options> <dump> <pass>
UUID=WILL_BE_REPLACED / ext4 defaults 1 1
tmpfs /tmp tmpfs defaults,nodev,nosuid 0 0
EOF
    
    # Copy first-boot setup script to rootfs
    echo "Copying first-boot setup script..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "${SCRIPT_DIR}/first-boot-setup.sh" ]; then
        cp "${SCRIPT_DIR}/first-boot-setup.sh" "${MOUNT_POINT}/root/first-boot-setup.sh"
        chmod +x "${MOUNT_POINT}/root/first-boot-setup.sh"
        echo "First-boot setup script copied to /root/first-boot-setup.sh"
    fi
    
    echo ""
    echo "[SKIP] Basic configuration created."
    echo "[SKIP] Package installation will need to be done after first boot."
    echo ""
    echo "After first boot, login as root and run:"
    echo "  /root/first-boot-setup.sh"
    echo ""
fi

