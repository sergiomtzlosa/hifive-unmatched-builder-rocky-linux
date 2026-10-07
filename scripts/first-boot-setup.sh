#!/bin/bash
# First Boot Setup Script
# Run this on the HiFive Unmatched board after first boot if packages were not installed during build

set -e

echo "========================================"
echo "HiFive Unmatched First Boot Setup"
echo "========================================"
echo ""
echo "This script will install essential system packages and configure your system."
echo ""

# Check if we're on RISC-V
ARCH=$(uname -m)
if [ "$ARCH" != "riscv64" ]; then
    echo "ERROR: This script must run on a RISC-V system!"
    echo "Current architecture: $ARCH"
    exit 1
fi

# Check if we're root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

echo "Detected RISC-V 64-bit system - proceeding with setup..."
echo ""

# Update package database
echo "Step 1: Updating package database..."
dnf makecache --refresh || yum makecache --refresh

# Install systemd and essential boot components
echo ""
echo "Step 2: Installing systemd and init system..."
dnf install -y systemd systemd-udev || yum install -y systemd systemd-udev

# Install basic system utilities
echo ""
echo "Step 3: Installing basic system utilities..."
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
    dhcp-client NetworkManager

# Install kernel modules tools
echo ""
echo "Step 4: Installing kernel module utilities..."
dnf install -y kmod || yum install -y kmod

# Install filesystem tools
echo ""
echo "Step 5: Installing filesystem utilities..."
dnf install -y e2fsprogs xfsprogs dosfstools || yum install -y e2fsprogs xfsprogs dosfstools

# Enable essential services
echo ""
echo "Step 6: Enabling essential services..."
systemctl enable sshd
systemctl enable NetworkManager
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable rsyslog

# Start services now
echo ""
echo "Step 7: Starting services..."
systemctl start sshd
systemctl start NetworkManager
systemctl start rsyslog

# Set hostname if not already set
if [ ! -f /etc/hostname ] || [ ! -s /etc/hostname ]; then
    echo ""
    echo "Step 8: Setting hostname..."
    echo "unmatched-riscv" > /etc/hostname
    hostnamectl set-hostname unmatched-riscv
fi

# Create basic network configuration if not exists
if [ ! -f /etc/systemd/network/20-wired.network ]; then
    echo ""
    echo "Step 9: Configuring network..."
    mkdir -p /etc/systemd/network
    cat > /etc/systemd/network/20-wired.network <<'EOF'
[Match]
Name=eth*

[Network]
DHCP=yes
EOF
fi

# Check and update fstab if needed
echo ""
echo "Step 10: Verifying /etc/fstab..."
if ! grep -q "^[^#].*/" /etc/fstab 2>/dev/null; then
    echo "Creating basic fstab..."
    cat > /etc/fstab <<'EOF'
# <file system> <mount point> <type> <options> <dump> <pass>
UUID=WILL_BE_REPLACED / ext4 defaults 1 1
tmpfs /tmp tmpfs defaults,nodev,nosuid 0 0
EOF
fi

echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "Installed and configured:"
echo "  - systemd (init system)"
echo "  - OpenSSH server (running)"
echo "  - NetworkManager (running)"
echo "  - System logging (rsyslog)"
echo "  - Basic system utilities"
echo "  - Filesystem tools"
echo ""
echo "Network status:"
ip addr show
echo ""
echo "Services status:"
systemctl is-active sshd && echo "  [OK] SSH server running" || echo "  [FAIL] SSH server not running"
systemctl is-active NetworkManager && echo "  [OK] NetworkManager running" || echo "  [FAIL] NetworkManager not running"
systemctl is-active rsyslog && echo "  [OK] Rsyslog running" || echo "  [FAIL] Rsyslog not running"
echo ""
echo "Next steps:"
echo "  1. Change root password: passwd"
echo "  2. Update system: dnf update -y"
echo "  3. Install additional software as needed"
echo ""
echo "You may want to reboot for all changes to take effect:"
echo "  reboot"
echo ""
