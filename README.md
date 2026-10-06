# HiFive Unmatched U-Boot + Rocky Linux Builder

Build a complete bootable system for the SiFive HiFive Unmatched Rev B board (RISC-V FU740) that boots Rocky Linux, with full QEMU emulation support for testing (failing as expected, I do not own a HiFive Unmatched U-Boot board).

## Quick Start (Linux + Docker)

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

Build time: 30-60 minutes depending on your hardware.

The build process will:
1. Build OpenSBI firmware (~5 min)
2. Build U-Boot bootloader (~10 min)
3. Download Rocky Linux rootfs (~5 min)
4. Create bootable disk image (~10 min)
5. Configure boot files (~2 min)

### Test in QEMU

After the build completes:

```bash
docker-compose exec uboot-builder /scripts/run-qemu.sh
```

Watch the boot process:
- U-Boot bootloader starts
- Extlinux menu appears
- Rocky Linux kernel loads
- Login prompt appears

To exit QEMU: Press Ctrl+A, then X

### View Build Logs

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

## Project Structure

```
hifive-unmatched-builder-rocky-linux/
├── Dockerfile              # Docker build environment
├── docker-compose.yml      # Docker orchestration
├── README.md              # This file
├── .env.example           # Configuration template
├── scripts/               # Build scripts (mounted to /scripts in container)
│   ├── build-opensbi.sh   # Build OpenSBI firmware
│   ├── build-uboot.sh     # Build U-Boot bootloader
│   ├── download-rootfs.sh # Download Rocky Linux
│   ├── create-image.sh    # Create disk image
│   ├── setup-boot.sh      # Configure boot files
│   ├── run-qemu.sh        # Test in QEMU
│   ├── build-all.sh       # Master build script
│   └── flash-sdcard.sh    # Flash to SD card
├── configs/               # Configuration files
├── docs/                  # Documentation
└── workspace/             # Working directory (mounted to /workspace in container)
    ├── build/            # Build artifacts (gitignored)
    ├── output/           # Final outputs
    └── logs/             # Build logs
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

## Boot Sequence

```
ROM (ZSBL) -> U-Boot SPL -> OpenSBI -> U-Boot -> Linux Kernel
```

1. ZSBL: Zero Stage Bootloader (in SoC ROM)
2. U-Boot SPL: First Stage Bootloader (from SD partition 1)
3. OpenSBI: Supervisor Binary Interface (from SD partition 2)
4. U-Boot: Bootloader menu (reads extlinux.conf)
5. Linux: Rocky Linux kernel boots

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
/scripts/create-image.sh        # Create disk image
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
UBOOT_VERSION=v2024.01

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
- U-Boot: v2024.01 (Bootloader)
- Rocky Linux: 10 RISC-V (or Fedora RISC-V fallback)
- Kernel: Provided by rootfs

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
