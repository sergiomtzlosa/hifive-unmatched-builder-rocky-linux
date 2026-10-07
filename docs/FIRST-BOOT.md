# First Boot Instructions

## Two Scenarios

Your build process may complete in one of two ways depending on whether QEMU user-mode emulation was available during the build.

### Scenario 1: Packages Installed During Build

If you see this during the build:
```
QEMU user-mode emulation detected, proceeding with package installation...
[OK] System packages installed successfully!
```

**Good news!** Your system is fully configured and ready to use.

After first boot:
- systemd is installed and running
- SSH server is enabled and running
- NetworkManager is configured with DHCP
- All essential packages are installed

**You can skip the first-boot setup script.**

Just login and optionally:
```bash
# Change root password
passwd

# Update system
dnf update -y
```

---

### Scenario 2: Packages NOT Installed During Build (Most Common)

If you see this during the build:
```
WARNING: Cannot chroot into RISC-V rootfs
[SKIP] Package installation will need to be done after first boot.
```

**This is normal!** The build system runs on x86_64 and cannot execute RISC-V binaries without QEMU user-mode emulation support.

Your image is still bootable, but you'll need to install essential packages after first boot.

## First Boot Setup Process

### Step 1: Boot the System

1. Flash the image to SD card
2. Insert into HiFive Unmatched
3. Set MSEL switches: 1011
4. Connect serial console (115200 baud)
5. Power on the board

### Step 2: Login

```
unmatched-riscv login: root
Password: rockylinux
```

### Step 3: Check Network

```bash
# Check if network is up
ip addr show

# If not, manually configure
dhclient eth0
```

### Step 4: Run First-Boot Setup Script

The setup script is already on your system at `/root/first-boot-setup.sh`:

```bash
# Make it executable (should already be)
chmod +x /root/first-boot-setup.sh

# Run the setup
./first-boot-setup.sh
```

**Note**: You need internet connectivity for this step. The script will download and install packages from Rocky Linux/Fedora repositories.

### What the Script Does

The first-boot-setup.sh script will:

1. Verify you're on RISC-V hardware
2. Update package database
3. Install systemd and init system
4. Install basic utilities (bash, coreutils, etc.)
5. Install SSH server
6. Install NetworkManager
7. Install logging (rsyslog)
8. Install filesystem tools
9. Enable and start all services
10. Configure hostname and networking

**Time required**: 10-20 minutes depending on network speed

### Step 5: Verify Installation

After the script completes:

```bash
# Check services are running
systemctl status sshd
systemctl status NetworkManager

# Check network
ip addr show

# Check disk usage
df -h
```

### Step 6: Post-Setup Tasks

```bash
# Change root password
passwd

# Update the system
dnf update -y

# Install additional packages as needed
dnf install -y git gcc make

# Optionally reboot to ensure everything is clean
reboot
```

## Manual Installation (Alternative)

If you prefer to install packages manually without using the script:

```bash
# Update package database
dnf makecache --refresh

# Install essential packages
dnf install -y systemd systemd-udev openssh-server NetworkManager \
  bash coreutils util-linux procps-ng iproute iputils \
  passwd shadow-utils rsyslog kmod e2fsprogs

# Enable services
systemctl enable sshd NetworkManager rsyslog

# Start services
systemctl start sshd NetworkManager rsyslog
```

## Troubleshooting

### No Network on First Boot

```bash
# Check interface name
ip link show

# Manually request DHCP
dhclient eth0

# Or configure static IP
ip addr add 192.168.1.100/24 dev eth0
ip route add default via 192.168.1.1
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

### Cannot Access Package Repositories

```bash
# Check DNS
ping -c 3 8.8.8.8          # Should work
ping -c 3 google.com       # Should work if DNS is configured

# If DNS fails
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
```

### Script Fails to Install Packages

```bash
# Check what failed
journalctl -xe

# Try manually installing core packages first
dnf install -y systemd
dnf install -y openssh-server
dnf install -y NetworkManager

# Then run the script again
./first-boot-setup.sh
```

### Disk Full

```bash
# Check disk space
df -h

# If root partition is small, expand it
# (Assuming SD card is larger than 4GB)
growpart /dev/mmcblk0 3
resize2fs /dev/mmcblk0p3
```

## SSH Access After Setup

Once NetworkManager is running and SSH is enabled:

```bash
# From another computer on the same network
ssh root@<board-ip-address>
# Password: rockylinux (or what you changed it to)
```

## NVMe Boot (Optional Performance Boost)

After completing first-boot setup, consider moving to NVMe SSD for 20-30x performance improvement.

See [docs/NVME-BOOT.md](docs/NVME-BOOT.md) for instructions.

## Getting Help

If you encounter issues during first boot:

1. **Check serial console** - All boot messages appear here
2. **Check system logs** - `journalctl -xe` and `dmesg`
3. **Verify hardware** - Ensure MSEL switches are correct (1011)
4. **Test network** - Must have internet access to install packages
5. **Check SD card** - Try a different SD card if boot fails

## Performance Expectations

After first-boot setup:

- **Boot time**: ~30-45 seconds from power-on to login prompt
- **SSH latency**: <1ms on local network
- **Package installation**: ~5-10 minutes for dnf update
- **Disk I/O**: ~50 MB/s sequential read on Class 10 SD card

For better performance, use NVMe SSD (1500+ MB/s).

## Summary

1. Build creates bootable image (with or without packages pre-installed)
2. Flash to SD card and boot on HiFive Unmatched
3. Login as root (password: rockylinux)
4. Run `/root/first-boot-setup.sh` if packages weren't pre-installed
5. Change password and update system
6. Enjoy your Rocky Linux RISC-V system!
