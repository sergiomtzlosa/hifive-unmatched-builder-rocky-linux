# Linux Kernel Build Guide for HiFive Unmatched

This guide explains how to build and install a Linux kernel for the HiFive Unmatched RISC-V board.

## Overview

The kernel build process has been integrated into the main build system. You can now:

1. Build the complete system including kernel with `build-all.sh`
2. Build only the kernel with `build-kernel.sh`
3. Install a pre-built kernel into an existing image with `install-kernel.sh`

## Automated Build (Recommended)

The easiest way is to use the master build script which now includes kernel building:

```bash
# Inside Docker container
docker-compose exec uboot-builder /scripts/build-all.sh
```

This will:
1. Build OpenSBI firmware
2. Build U-Boot bootloader
3. Download Rocky Linux rootfs
4. **Build Linux kernel** (new step)
5. Create bootable disk image
6. **Install kernel to rootfs** (new step)
7. Configure boot files
8. Generate build documentation

## Manual Kernel Build

If you want to build only the kernel:

```bash
docker-compose exec uboot-builder /scripts/build-kernel.sh
```

This will:
- Clone the Linux kernel source (v6.6 by default)
- Configure for RISC-V with HiFive Unmatched specific options
- Compile kernel, modules, and device trees
- Create initramfs
- Package everything in `/workspace/output/kernel/`

### Kernel Build Output

The kernel build creates:

```
/workspace/output/kernel/
|-- vmlinuz-6.6.x               # Kernel image
|-- initramfs-6.6.x.img         # Initial ramdisk
|-- modules-6.6.x.tar.gz        # Kernel modules archive
+-- dtbs/6.6.x/                 # Device tree blobs
    +-- sifive/
        +-- hifive-unmatched-a00.dtb  # HiFive Unmatched DTB
```

## Installing Kernel to Existing Image

If you already have a disk image and want to add/update the kernel:

```bash
# Make sure you have:
# 1. Built the kernel (build-kernel.sh)
# 2. Created the disk image (create-image.sh)

docker-compose exec uboot-builder /scripts/install-kernel.sh
```

This will:
- Mount the disk image
- Copy kernel, initramfs, and device trees to `/boot`
- Install kernel modules
- Unmount and cleanup

**Note:** After installing the kernel, you should run `setup-boot.sh` to update the boot configuration with the correct kernel version.

## Kernel Configuration

### Default Configuration

The build uses RISC-V `defconfig` with additional HiFive Unmatched specific features:

- SiFive SoC support
- Serial console (ttySIF0)
- SPI, PWM, GPIO drivers
- MMC/SD card support
- PCIe support
- USB XHCI support
- EXT4 filesystem
- Device tree support

### Customizing Kernel Configuration

To customize the kernel config:

1. Build the kernel once to clone the source
2. Enter the kernel build directory:
   ```bash
   docker-compose exec uboot-builder /bin/bash
   cd /workspace/build/linux
   ```

3. Configure with menuconfig:
   ```bash
   make ARCH=riscv CROSS_COMPILE=riscv64-buildroot-linux-gnu- menuconfig
   ```

4. Save your configuration

5. Rebuild:
   ```bash
   /scripts/build-kernel.sh
   ```

### Changing Kernel Version

Edit the kernel version in `build-kernel.sh`:

```bash
KERNEL_VERSION=v6.6  # Change to desired version (e.g., v6.10, v6.12)
```

Or set it as an environment variable:

```bash
docker-compose exec -e KERNEL_VERSION=v6.10 uboot-builder /scripts/build-kernel.sh
```

## Boot Configuration

After kernel installation, the `setup-boot.sh` script automatically detects the installed kernel and creates the appropriate extlinux.conf bootloader configuration.

The boot menu will show:
- Rocky Linux (kernel 6.6.x) - Normal boot
- Rocky Linux (recovery mode) - Single user mode

## Troubleshooting

### Kernel Build Fails

```bash
# Check you have the toolchain
riscv64-buildroot-linux-gnu-gcc --version

# Check build log
cat /workspace/logs/build-all-latest.log | grep -A 20 "Building Linux Kernel"

# Clean and rebuild
rm -rf /workspace/build/linux
/scripts/build-kernel.sh
```

### Kernel Not Found in Boot

```bash
# Check if kernel is installed
docker-compose exec uboot-builder /bin/bash
losetup -f --show /workspace/output/rocky-riscv-unmatched.img
mount /dev/loop0p3 /mnt
ls -la /mnt/boot/
umount /mnt
losetup -d /dev/loop0

# Reinstall kernel
/scripts/install-kernel.sh
/scripts/setup-boot.sh
```

### Module Loading Issues

If kernel modules don't load:

1. Verify modules were installed:
   ```bash
   tar tzf /workspace/output/kernel/modules-*.tar.gz | head
   ```

2. Check they're in the rootfs:
   ```bash
   # Mount and check
   ls -la /mnt/lib/modules/
   ```

3. Ensure kernel version matches:
   ```bash
   cat /workspace/output/KERNEL_VERSION
   ```

## Build Times

Approximate build times on modern hardware:

- Kernel compilation: 15-30 minutes (first time)
- Kernel compilation: 2-5 minutes (incremental)
- Kernel installation: 1-2 minutes

Total build time with kernel: 45-90 minutes (first time)

## Advanced Usage

### Build Kernel Only (No Modules)

```bash
cd /workspace/build/linux
make ARCH=riscv CROSS_COMPILE=riscv64-buildroot-linux-gnu- -j$(nproc) Image
```

### Extract Kernel Config from Running System

If you boot the system and want to extract the config:

```bash
# On the running HiFive Unmatched
zcat /proc/config.gz > kernel.config

# Or from initramfs
cat /boot/config-$(uname -r)
```

### Using External Kernel Source

If you have a custom kernel source:

```bash
# Copy your kernel to build directory
cp -r /path/to/linux /workspace/build/linux

# Skip the git clone step in build-kernel.sh
# Comment out the git clone lines

# Build
/scripts/build-kernel.sh
```

## Integration with Complete Build

The complete build process now has 8 steps:

1. Build OpenSBI (5 min)
2. Build U-Boot (10 min)
3. Download rootfs (5 min)
4. **Build kernel (20 min)** <- New
5. Create disk image (10 min)
6. **Install kernel (2 min)** <- New
7. Configure boot (2 min)
8. Generate docs (1 min)

Total: 55+ minutes

## Next Steps

After building with kernel support:

1. Test in QEMU (if supported for your kernel version)
2. Flash to SD card
3. Boot on HiFive Unmatched
4. Login and verify kernel version:
   ```bash
   uname -a
   ```

## References

- [Linux Kernel RISC-V](https://www.kernel.org/doc/html/latest/riscv/index.html)
- [HiFive Unmatched Documentation](https://www.sifive.com/boards/hifive-unmatched)
- [Device Tree Documentation](https://www.kernel.org/doc/Documentation/devicetree/)
