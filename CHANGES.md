# Changes Made to Support Full Bootable OS

## Summary
Modified the build system to create a **full bootable Rocky Linux system** instead of a minimal container rootfs. The previous container image lacked systemd, init system, and essential packages needed to boot as a standalone OS.

## New Scripts Created

### 1. `scripts/install-system-packages.sh`
**Purpose**: Install essential system packages to make the rootfs bootable

**What it does**:
- Mounts the disk image rootfs partition
- Sets up chroot environment with proc, sys, dev mounts
- Installs systemd and init system
- Installs essential packages:
  - SSH server (openssh-server)
  - Network management (NetworkManager, dhcp-client)
  - System utilities (coreutils, util-linux, procps, etc.)
  - Text editors (vim-minimal, nano)
  - Logging (rsyslog)
  - Filesystem tools (e2fsprogs, xfsprogs, dosfstools)
  - Kernel module tools (kmod)
- Enables essential services (sshd, NetworkManager, rsyslog)
- Configures basic networking with DHCP
- Sets up /etc/fstab and hostname
- Properly cleans up mounts on exit

**Execution time**: 10-20 minutes (downloads and installs packages)

### 2. `scripts/reset-root-password.sh`
**Purpose**: Set root password and enable SSH access

**What it does**:
- Mounts the disk image rootfs partition
- Sets root password via chroot (default: "rockylinux")
- Enables root login via SSH
- Enables password authentication in SSH
- Sets up serial console autologin for debugging
- Properly cleans up mounts on exit

**Configuration**:
- Default password: `rockylinux`
- Can be overridden with environment variable: `ROOT_PASSWORD=yourpass`

### 3. `scripts/cleanup-mounts.sh`
**Purpose**: Emergency cleanup utility for leftover mounts and loop devices

**What it does**:
- Unmounts any leftover chroot mounts (dev, sys, proc)
- Unmounts rootfs partition
- Detaches loop devices associated with the disk image
- Detects and cleans orphaned loop devices
- Provides status summary
- Safe to run anytime (won't fail if nothing to clean)

**When to use**:
- After Ctrl+C during package installation
- When build scripts fail with mount errors
- Before retrying failed builds
- To check current mount/loop status

## Modified Files

### 1. `Dockerfile`
**Changes**:
- Added `dnf` package manager to Ubuntu container
- This allows the build system to understand DNF-based package management

**Why**: The rootfs uses DNF (Rocky/Fedora package manager), so we need dnf available in the build container for any host-side package operations.

### 2. `scripts/build-all.sh`
**Changes**:
- Updated from 8 steps to **10 steps**
- Added Step 8: Install System Packages (calls `install-system-packages.sh`)
- Added Step 9: Reset Root Password (calls `reset-root-password.sh`)
- Updated all step counters from [X/8] to [X/10]

**New build flow**:
1. Build OpenSBI Firmware
2. Build U-Boot Bootloader
3. Download Rocky Linux Rootfs
4. Build Linux Kernel
5. Create Bootable Disk Image
6. Install Kernel to Rootfs
7. Configure Boot Files
8. **Install System Packages** ← NEW
9. **Reset Root Password** ← NEW
10. Generate Build Information

### 3. `scripts/run-qemu.sh`
**Changes**:
- Added warning about hardware mismatch
- Added interactive prompt before running
- Improved documentation about QEMU limitations

**Why**: The image is built for HiFive Unmatched hardware, not QEMU's generic virt machine. Running in QEMU will likely fail due to hardware-specific U-Boot configuration.

## All Script Improvements

### Path Resolution
All scripts now handle both Docker and host environments:
```bash
if [ -d "/workspace" ]; then
    WORKSPACE_ROOT="/workspace"
else
    WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi
```

### Error Handling
- All mount operations have trap-based cleanup
- Scripts won't leave orphaned mounts or loop devices
- Graceful fallback on package installation errors

### Safety
- All scripts verify image/partition existence before proceeding
- Proper wait times for partition device creation
- Backup configs before modification (e.g., sshd_config)

## Usage

### Normal Build Process
```bash
# Inside Docker container
cd /workspace
./scripts/build-all.sh
```

This will now:
1. Build all components
2. Create disk image
3. **Install full OS packages** (NEW - takes 10-20 min)
4. **Set root password** (NEW)
5. Generate bootable image

### Emergency Cleanup
```bash
# If build fails with mount errors
./scripts/cleanup-mounts.sh

# Then retry
./scripts/build-all.sh
```

### Custom Root Password
```bash
# Set custom password before building
export ROOT_PASSWORD="your-secure-password"
./scripts/build-all.sh
```

### Run Individual Steps
```bash
# Only install packages (if you already have the image)
./scripts/install-system-packages.sh

# Only reset password
./scripts/reset-root-password.sh
```

## Default Credentials

**Username**: `root`  
**Password**: `rockylinux`  
**SSH**: Enabled on port 22  
**Serial Console**: Auto-login enabled

## What's Installed in the Rootfs

### Init System
- systemd (full init system)
- systemd-udev (device management)

### Network
- NetworkManager
- dhcp-client
- iproute, iputils, net-tools
- openssh-server, openssh-clients

### System Utilities
- bash, coreutils, util-linux
- procps-ng, psmisc
- grep, sed, gawk
- tar, gzip, bzip2, xz
- vim-minimal, nano
- sudo, passwd, shadow-utils

### System Services
- rsyslog (logging)
- cronie (cron jobs)
- logrotate (log management)

### Filesystem Tools
- e2fsprogs (ext2/3/4)
- xfsprogs (XFS)
- dosfstools (FAT/VFAT)
- kmod (kernel modules)

## Known Issues

1. **QEMU Compatibility**: The image is built for HiFive Unmatched hardware and will not boot properly in QEMU without rebuilding U-Boot for QEMU's virt machine.

2. **Network Configuration**: Uses DHCP by default. If you need static IP, modify `/etc/systemd/network/20-wired.network` after booting or before building.

3. **Package Installation Time**: The system package installation step takes 10-20 minutes depending on network speed. This is normal.

4. **UUID in fstab**: The fstab initially has a placeholder UUID. This should be updated with the actual partition UUID during first boot or in a future script enhancement.

## Future Enhancements

- [ ] Update fstab with actual partition UUID
- [ ] Add option to skip package installation for faster rebuilds
- [ ] Support building for both HiFive Unmatched and QEMU targets
- [ ] Add network configuration options (static IP, custom DNS, etc.)
- [ ] Create user account in addition to root
- [ ] Install additional development tools (gcc, git, etc.) as optional step

## Testing

After building, test the image:

1. **On real hardware**:
   ```bash
   sudo dd if=output/rocky-riscv-unmatched.img of=/dev/sdX bs=4M status=progress
   ```

2. **Connect serial console**:
   - Baud rate: 115200
   - Device: ttyS0 (or ttySIF0 on HiFive Unmatched)

3. **First boot**:
   - Should see systemd boot messages
   - Should auto-login to root on serial console
   - SSH should be available on network

4. **Verify services**:
   ```bash
   systemctl status sshd
   systemctl status NetworkManager
   ip addr
   ```
