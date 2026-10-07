# Getting Started

Quick guide to build U-Boot for HiFive Unmatched Rev B with Rocky Linux.

## Prerequisites

- Linux system (Ubuntu, Debian, Fedora, etc.)
- Docker installed
- 25GB+ free disk space
- 8GB+ RAM
- Internet connection

## Step 1: Install Docker

Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install docker.io docker-compose
sudo usermod -aG docker $USER
```

Fedora/RHEL:
```bash
sudo dnf install docker docker-compose
sudo systemctl start docker
sudo usermod -aG docker $USER
```

Log out and back in for group changes to take effect.

## Step 2: Clone or Navigate to Project

```bash
cd /path/to/hifive-unmatched-builder-rocky-linux && chmod +x scripts/*.sh
```

## Step 3: Build Docker Image (First Time Only)

```bash
docker-compose build
```

This takes 10-15 minutes and only needs to be done once.

## Step 4: Build Everything

```bash
# Start container
docker-compose up -d

# Run build
docker-compose exec uboot-builder /scripts/build-all.sh
```

This takes 30-60 minutes. The script will:
1. Build OpenSBI firmware
2. Build U-Boot bootloader
3. Download Rocky Linux rootfs
4. Create bootable disk image
5. Configure boot files

## Step 5: Test in QEMU (Optional)

```bash
docker-compose exec uboot-builder /scripts/run-qemu.sh
```

Press Ctrl+A then X to exit QEMU.

## Step 6: Flash to SD Card

```bash
# Find SD card device
lsblk

# Flash (replace /dev/sdX with your SD card)
sudo dd if=workspace/output/rocky-riscv-unmatched.img of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

## Step 7: Boot on Hardware

1. Set MSEL switches to 1011 (ON-ON-OFF-ON)
2. Insert SD card
3. Connect serial console (115200 baud)
4. Power on
5. Login: root / rockylinux

## Where is Everything?

```
workspace/
|-- build/                    # Build artifacts
|-- output/                   # Final image
|   +-- rocky-riscv-unmatched.img
+-- logs/                     # Build logs
```

## View Logs

```bash
# View latest log
cat workspace/logs/build-all-latest.log

# Or from container
docker-compose exec uboot-builder cat /workspace/logs/build-all-latest.log

# List all logs
ls -lh workspace/logs/
```

## Common Commands

```bash
# Start container
docker-compose up -d

# Stop container
docker-compose down

# Enter container shell
docker-compose exec uboot-builder /bin/bash

# Rebuild everything
docker-compose exec uboot-builder bash -c "cd /workspace && /scripts/build-all.sh"

# Clean build artifacts
rm -rf workspace/build/*

# Remove container and volumes
docker-compose down -v
```

## Need Help?

- Full documentation: README.md
- Build success summary: BUILD-SUCCESS.md
- Hardware setup: docs/HARDWARE-SETUP.md

## Quick Reference

| Task | Command |
|------|---------|
| Build image | `docker-compose build` |
| Start container | `docker-compose up -d` |
| Run build | `docker-compose exec uboot-builder /scripts/build-all.sh` |
| Test QEMU | `docker-compose exec uboot-builder /scripts/run-qemu.sh` |
| View logs | `cat workspace/logs/build-all-latest.log` |
| Flash SD | `sudo dd if=workspace/output/rocky-riscv-unmatched.img of=/dev/sdX bs=4M` |
| Stop container | `docker-compose down` |

