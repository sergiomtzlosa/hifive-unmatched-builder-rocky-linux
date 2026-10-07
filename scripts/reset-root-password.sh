#!/bin/bash
# Reset root password in the rootfs

set -e

echo "===================================="
echo "Resetting Root Password"
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

# Default password (can be overridden by environment variable)
ROOT_PASSWORD=${ROOT_PASSWORD:-rockylinux}

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

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up..."
    umount "${MOUNT_POINT}" 2>/dev/null || true
    losetup -d "${LOOP_DEVICE}" 2>/dev/null || true
}
trap cleanup EXIT

echo ""
echo "Setting root password to: ${ROOT_PASSWORD}"
echo ""

# Check if we can chroot (need QEMU user-mode for RISC-V)
if chroot "${MOUNT_POINT}" /bin/true 2>/dev/null; then
    # We have QEMU user-mode emulation, can use chroot
    echo "Using chroot method..."
    chroot "${MOUNT_POINT}" /bin/bash <<CHROOT_EOF
set -e
echo "root:${ROOT_PASSWORD}" | chpasswd
echo "Root password set successfully!"
CHROOT_EOF
else
    # No QEMU user-mode, modify shadow file directly
    echo "No QEMU user-mode available, using direct shadow file method..."
    
    # Generate password hash
    # Use openssl passwd or python to create hash
    if command -v openssl >/dev/null 2>&1; then
        PASSWORD_HASH=$(openssl passwd -6 "${ROOT_PASSWORD}")
    elif command -v python3 >/dev/null 2>&1; then
        PASSWORD_HASH=$(python3 -c "import crypt; print(crypt.crypt('${ROOT_PASSWORD}', crypt.mksalt(crypt.METHOD_SHA512)))")
    else
        echo "ERROR: Cannot generate password hash (need openssl or python3)"
        exit 1
    fi
    
    # Backup shadow file
    cp "${MOUNT_POINT}/etc/shadow" "${MOUNT_POINT}/etc/shadow.bak"
    
    # Replace root password in shadow file
    sed -i "s|^root:[^:]*:|root:${PASSWORD_HASH}:|" "${MOUNT_POINT}/etc/shadow"
    
    echo "Root password set successfully using direct method!"
fi

# Also allow root login via SSH
if [ -f "${MOUNT_POINT}/etc/ssh/sshd_config" ]; then
    echo "Configuring SSH for root login..."
    
    # Backup original sshd_config
    cp "${MOUNT_POINT}/etc/ssh/sshd_config" "${MOUNT_POINT}/etc/ssh/sshd_config.bak"
    
    # Enable root login with password
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' "${MOUNT_POINT}/etc/ssh/sshd_config"
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' "${MOUNT_POINT}/etc/ssh/sshd_config"
    
    echo "SSH configured for root login"
fi

# Set up serial console for root autologin (optional, for debugging)
if [ -d "${MOUNT_POINT}/etc/systemd/system" ]; then
    echo "Setting up serial console autologin..."
    mkdir -p "${MOUNT_POINT}/etc/systemd/system/serial-getty@ttyS0.service.d"
    cat > "${MOUNT_POINT}/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf" <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f root' --noclear --autologin root %I $TERM
EOF
fi

echo ""
echo "Root password reset complete!"
echo ""
echo "Credentials:"
echo "  Username: root"
echo "  Password: ${ROOT_PASSWORD}"
echo ""
echo "SSH access enabled for root"
echo ""

