# HiFive Unmatched U-Boot + Rocky Linux Builder

Build a complete bootable Rocky Linux system for the SiFive HiFive Unmatched Rev B board (RISC-V FU740) with full systemd, SSH, and networking support.

**Note**: This image is built for **real HiFive Unmatched hardware only**. It does NOT work in QEMU due to hardware-specific bootloader configuration.

## Quick Start (Linux + Docker)

**New in this version:** The build now includes full Linux kernel compilation for HiFive Unmatched! See [docs/KERNEL-BUILD.md](docs/KERNEL-BUILD.md) for details.

### Prerequisites

1. **Docker** - Install on your Linux system
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install docker.io docker-compose
   sudo usermod -aG docker $USER
   # Log out and back in for group changes
   
   # Fedora/RHEL
   sudo dnf install docker docker-compose
   sudo systemctl start docker
   sudo usermod -aG docker $USER
   ```

2. **System Requirements**
   - 25GB+ free disk space
   - 8GB+ RAM
   - Good internet connection

### Build Everything

```bash
# 1. Clone or navigate to this repository
cd /path/to/hifive-unmatched-builder-rocky-linux

# 2. Make scripts executable (first time only)
chmod +x scripts/*.sh

# 3. Build the Docker image (first time only)
docker-compose build

# 4. Start the container
docker-compose up -d

# 5. Run the complete build
docker-compose exec uboot-builder /scripts/build-all.sh
```

Build time: 60-120 minutes depending on your hardware (includes kernel compilation and package installation).

The build process will:
1. Build OpenSBI firmware (~5 min)
2. Build U-Boot bootloader (~10 min)
3. Download Rocky Linux rootfs (~5 min)
4. Build Linux kernel (~20 min)
5. Create bootable disk image (~10 min)
6. Install kernel to rootfs (~2 min)
7. Configure boot files (~2 min)
8. **Install system packages (systemd, SSH, NetworkManager) (~15-20 min)**
9. **Set root password (~1 min)**
10. Generate build documentation (~1 min)

### Flash to SD Card

**Important**: This image is for real hardware only. Do not attempt to run in QEMU - it will fail with memory access errors.

After the build completes, flash the image to an SD card and boot on the HiFive Unmatched board.

All build output is logged to timestamped files:

```bash
# View the latest log
cat workspace/logs/build-all-latest.log

# List all build logs
ls -lh workspace/logs/
```

Logs are saved in: `workspace/logs/`

### Extract the Image

The bootable image is in the workspace directory:

```bash
ls -lh workspace/output/rocky-riscv-unmatched.img
```

This image can be flashed to:
- SD card for standard boot
- NVMe SSD for high-performance boot (see "Boot from NVMe SSD" section below)
- Both (bootloader on SD, root filesystem on NVMe for best results)

## Project Structure

```
hifive-unmatched-builder-rocky-linux/
|-- Dockerfile              # Docker build environment
|-- docker-compose.yml      # Docker orchestration
|-- README.md              # This file
|-- .env.example           # Configuration template
|-- scripts/               # Build scripts (mounted to /scripts in container)
|   |-- build-opensbi.sh   # Build OpenSBI firmware
|   |-- build-uboot.sh     # Build U-Boot bootloader
|   |-- download-rootfs.sh # Download Rocky Linux
|   |-- build-kernel.sh    # Build Linux kernel
|   |-- install-kernel.sh  # Install kernel to image
|   |-- create-image.sh    # Create disk image
|   |-- setup-boot.sh      # Configure boot files
|   |-- run-qemu.sh        # Test in QEMU
|   |-- build-all.sh       # Master build script
|   +-- flash-sdcard.sh    # Flash to SD card
|-- configs/               # Configuration files
|-- docs/                  # Documentation
|   |-- HARDWARE-SETUP.md  # Hardware setup guide
|   |-- KERNEL-BUILD.md    # Kernel build guide
|   +-- NVME-BOOT.md       # NVMe SSD boot guide
+-- workspace/             # Working directory (mounted to /workspace in container)
    |-- build/            # Build artifacts (gitignored)
    |-- output/           # Final outputs
    +-- logs/             # Build logs
```

## Flash to SD Card

### Using dd (Linux)

```bash
# Find your SD card device
lsblk

# Flash the image (replace /dev/sdX with your SD card)
sudo dd if=workspace/output/rocky-riscv-unmatched.img of=/dev/sdX bs=4M status=progress conv=fsync

# Sync to ensure all data is written
sync
```

WARNING: Double-check the device name! dd will overwrite any device you specify.

### Using balenaEtcher (GUI)

1. Download: https://etcher.balena.io/
2. Select the .img file
3. Select your SD card
4. Flash

## Boot on HiFive Unmatched

1. **Set MSEL switches** to 1011 (ON-ON-OFF-ON)
   ```
   MSEL0: ON  (1)
   MSEL1: ON  (1)
   MSEL2: OFF (0)
   MSEL3: ON  (1)
   ```

2. **Insert SD card** into HiFive Unmatched

3. **Connect serial console**
   - USB to micro-USB cable
   - 115200 baud, 8N1, no flow control
   - Use screen, minicom, or picocom:
     ```bash
     screen /dev/ttyUSB0 115200
     # or
     minicom -D /dev/ttyUSB0 -b 115200
     ```

4. **Power on** the board

5. **Login**
   - Username: root
   - Password: rockylinux
   - SSH is enabled and DHCP networking is configured

**What's Included:**
- systemd init system
- OpenSSH server
- NetworkManager with DHCP
- Basic system utilities (vim, nano, tar, etc.)
- Logging (rsyslog)
- Filesystem tools

## Boot Sequence

```
ROM (ZSBL) -> U-Boot SPL -> OpenSBI -> U-Boot -> Linux Kernel
```

1. ZSBL: Zero Stage Bootloader (in SoC ROM)
2. U-Boot SPL: First Stage Bootloader (from SD partition 1)
3. OpenSBI: Supervisor Binary Interface (from SD partition 2)
4. U-Boot: Bootloader menu (reads extlinux.conf)
5. Linux: Rocky Linux kernel boots

## Boot from NVMe SSD

The HiFive Unmatched has an M.2 NVMe slot that provides much faster performance than SD cards. You can boot from NVMe SSD while keeping the bootloader on the SD card.

**For complete NVMe setup guide, see [docs/NVME-BOOT.md](docs/NVME-BOOT.md)**

### Hardware Setup

1. **Install NVMe SSD**
   - Power off the board
   - Insert M.2 NVMe SSD (PCIe 3.0 x4, M-key, 2280 size recommended)
   - Secure with the mounting screw
   - Compatible SSDs: Most standard NVMe drives work (Samsung 970/980, WD Black, etc.)

2. **Keep SD card for bootloader**
   - The SD card contains U-Boot SPL and OpenSBI firmware
   - Only bootloader files needed, root filesystem will be on NVMe

### Method 1: Clone SD Card to NVMe (Recommended)

This is the easiest method - boot from SD card, then copy everything to NVMe.

```bash
# 1. Boot from SD card with the built image
# 2. After first boot, login as root

# 3. Check if NVMe is detected
lsblk
# Should show /dev/nvme0n1

# 4. Partition the NVMe drive
fdisk /dev/nvme0n1
# Create a new GPT partition table (g)
# Create a new partition (n)
# Use default values (entire disk)
# Write changes (w)

# 5. Format the NVMe partition
mkfs.ext4 -L rootfs-nvme /dev/nvme0n1p1

# 6. Mount both filesystems
mkdir /mnt/nvme /mnt/sd
mount /dev/nvme0n1p1 /mnt/nvme
mount /dev/mmcblk0p3 /mnt/sd

# 7. Copy root filesystem to NVMe (takes 5-10 minutes)
rsync -axHAWXS --info=progress2 /mnt/sd/ /mnt/nvme/

# 8. Update fstab on NVMe to use NVMe root
sed -i 's/mmcblk0p3/nvme0n1p1/g' /mnt/nvme/etc/fstab

# 9. Update bootloader config on SD card
mount /dev/mmcblk0p3 /mnt/sd
nano /mnt/sd/boot/extlinux/extlinux.conf
# Change: root=/dev/mmcblk0p3
# To:     root=/dev/nvme0n1p1
# Save and exit

# 10. Reboot
sync
reboot
```

After reboot, the system will boot from NVMe! The SD card only provides the bootloader.

### Method 2: Flash Image to NVMe Directly

Flash the disk image directly to the NVMe drive, then adjust the bootloader.

```bash
# 1. Boot HiFive Unmatched from SD card with any Linux
# 2. Enable SSH and find the IP address

# 3. Copy image to the board (from your host)
scp workspace/output/rocky-riscv-unmatched.img root@board-ip:/tmp/

# 4. SSH into the board
ssh root@board-ip

# 5. Flash image to NVMe
dd if=/tmp/rocky-riscv-unmatched.img of=/dev/nvme0n1 bs=4M status=progress conv=fsync
sync

# 6. Expand the root partition to use full NVMe capacity
sgdisk -e /dev/nvme0n1
parted /dev/nvme0n1 resizepart 3 100%
e2fsck -f /dev/nvme0n1p3
resize2fs /dev/nvme0n1p3

# 7. Update the root device in extlinux.conf
mkdir /mnt/nvme
mount /dev/nvme0n1p3 /mnt/nvme
nano /mnt/nvme/boot/extlinux/extlinux.conf
# Change: root=/dev/mmcblk0p3
# To:     root=/dev/nvme0n1p3

# Also update fstab
nano /mnt/nvme/etc/fstab
# Change mmcblk0p3 to nvme0n1p3

umount /mnt/nvme

# 8. Update SD card bootloader config
mkdir /mnt/sd
mount /dev/mmcblk0p3 /mnt/sd
nano /mnt/sd/boot/extlinux/extlinux.conf
# Change root=/dev/mmcblk0p3 to root=/dev/nvme0n1p3
umount /mnt/sd

# 9. Reboot
reboot
```

### Verifying NVMe Boot

After booting, verify you're running from NVMe:

```bash
# Check root filesystem mount
df -h /
# Should show /dev/nvme0n1p1 or nvme0n1p3

# Check NVMe device info
nvme list

# View NVMe performance
hdparm -t /dev/nvme0n1
# Should show 1000+ MB/sec (vs ~50 MB/sec for SD card)

# Check boot time
systemd-analyze
# NVMe boot should be significantly faster
```

### Performance Comparison

| Storage | Sequential Read | Sequential Write | Random IOPS | Boot Time |
|---------|----------------|------------------|-------------|-----------|
| SD Card (Class 10) | ~50 MB/s | ~20 MB/s | ~500 | ~45s |
| NVMe SSD (PCIe 3.0) | ~1500 MB/s | ~1000 MB/s | ~100K | ~15s |

**NVMe provides 20-30x better performance!**

### Hybrid Boot Configuration

The recommended setup:
- **SD Card:** U-Boot SPL + OpenSBI + U-Boot (partitions 1-2, ~5MB total)
- **NVMe SSD:** Root filesystem with kernel and all data (partition 3)

Benefits:
- Fast boot times
- High storage performance
- Easy recovery (swap SD card if needed)
- Full NVMe capacity for root filesystem

### Troubleshooting NVMe Boot

**NVMe not detected:**
```bash
# Check PCIe devices
lspci | grep -i nvme
# Should show: Non-Volatile memory controller

# Check kernel messages
dmesg | grep -i nvme

# Verify NVMe kernel module is loaded
lsmod | grep nvme
```

**Boot fails with "No root device" error:**
- Check extlinux.conf has correct root=/dev/nvme0n1p3 or nvme0n1p1
- Verify NVMe partition exists: `ls -l /dev/nvme0n1*`
- Check fstab uses correct device or LABEL

**Slow NVMe performance:**
```bash
# Check PCIe link speed
lspci -vv | grep -A 10 "Non-Volatile"
# Should show: LnkSta: Speed 8GT/s, Width x4

# If slower, reseat the NVMe drive
```

**Want to switch back to SD card:**
- Just change extlinux.conf back to root=/dev/mmcblk0p3
- No need to modify NVMe

## Disk Image Layout

```
Sector 0-33:     GPT Header (17KB)
Sector 34-2081:  Partition 1 - U-Boot SPL (1MB)
                 GUID: 5b193300-fc78-40cd-8002-e86c45580b47
Sector 2082-10273: Partition 2 - U-Boot ITB (4MB)
                   GUID: 2e54b353-1271-4842-806f-e436d6af6985
Sector 16384-END: Partition 3 - Root Filesystem (ext4)
                  Contains: Rocky Linux + Kernel + Boot files
```

## Individual Build Steps

If you want to run steps individually:

```bash
# Enter the container
docker-compose exec uboot-builder /bin/bash

# Inside container
cd /workspace

# Run individual steps
/scripts/build-opensbi.sh      # Build OpenSBI
/scripts/build-uboot.sh         # Build U-Boot
/scripts/download-rootfs.sh     # Download rootfs
/scripts/build-kernel.sh        # Build Linux kernel
/scripts/create-image.sh        # Create disk image
/scripts/install-kernel.sh      # Install kernel to image
/scripts/setup-boot.sh          # Configure boot
/scripts/run-qemu.sh            # Test in QEMU
```

## Docker Commands Reference

```bash
# Build the Docker image
docker-compose build

# Start container in background
docker-compose up -d

# Enter the container
docker-compose exec uboot-builder /bin/bash

# View container logs
docker-compose logs -f

# Stop the container
docker-compose down

# Remove everything (including volumes)
docker-compose down -v

# Rebuild from scratch
docker-compose build --no-cache
```

## Configuration

Edit `.env.example` and save as `.env` to customize:

```bash
# Toolchain
CROSS_COMPILE=riscv64-buildroot-linux-gnu-

# Versions
OPENSBI_VERSION=v1.3
UBOOT_VERSION=v2026.07

# Image Configuration
IMAGE_SIZE=4G
ROOT_PASSWORD=rockylinux

# QEMU Configuration
QEMU_MEMORY=4G
QEMU_CPUS=4
```

## Troubleshooting

### Docker Permission Denied

```bash
# Add your user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

### Out of Disk Space

```bash
# Clean old Docker images
docker system prune -a

# Remove build artifacts
rm -rf workspace/build/*
```

### Build Fails

```bash
# Check the log
cat workspace/logs/build-all-latest.log

# Test build environment
docker-compose exec uboot-builder /scripts/test-build-env.sh

# Clean and rebuild
rm -rf workspace/build/*
docker-compose exec uboot-builder bash -c "cd /workspace && /scripts/build-all.sh"
```

### Serial Console No Output

- Check USB cable connection
- Verify COM port: `ls /dev/ttyUSB*` or `ls /dev/ttyACM*`
- Check baud rate: 115200
- Try: `sudo screen /dev/ttyUSB0 115200`

### Board Won't Boot

- Verify MSEL switches: 1011 (ON-ON-OFF-ON)
- Check SD card is properly inserted
- Verify image was written correctly
- Check serial console for error messages

## Running Without Docker

If you prefer to build directly on your Linux system, see: [RUN-ON-NATIVE-LINUX.md](RUN-ON-NATIVE-LINUX.md)

You'll need to install:
- RISC-V cross-compilation toolchain
- Build dependencies (gcc, make, device-tree-compiler, etc.)
- QEMU RISC-V emulator

## Technical Details

### Hardware: HiFive Unmatched Rev B
- SoC: SiFive FU740-C000 (RISC-V)
- CPU: 4x U74 cores + 1x S7 monitor core
- RAM: 16GB DDR4
- Storage: MicroSD card slot, NVMe M.2 slot

### Software Stack
- OpenSBI: v1.3 (Supervisor Binary Interface)
- U-Boot: v2026.07 (Bootloader)
- Linux Kernel: v6.6 (built from source)
- Rocky Linux: 10 RISC-V (or Fedora RISC-V fallback)

### Build Environment
- Base: Ubuntu 22.04 LTS
- Toolchain: Bootlin RISC-V GCC (prebuilt)
- Target: riscv64-lp64d
- Emulator: QEMU 8.0+ with RISC-V support

## Resources

- [HiFive Unmatched Documentation](https://www.sifive.com/boards/hifive-unmatched)
- [U-Boot Documentation](https://docs.u-boot.org/)
- [OpenSBI Documentation](https://github.com/riscv/opensbi)
- [Rocky Linux](https://rockylinux.org/)
- [RISC-V](https://riscv.org/)

## License

This build system follows the licenses of its components:
- OpenSBI: BSD-2-Clause
- U-Boot: GPL-2.0
- Rocky Linux: Various open source licenses
