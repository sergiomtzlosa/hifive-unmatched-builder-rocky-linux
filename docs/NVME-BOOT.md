# NVMe Boot Guide for HiFive Unmatched

Complete guide for setting up and booting Rocky Linux from NVMe SSD on the SiFive HiFive Unmatched board.

## Table of Contents

- [Why Use NVMe?](#why-use-nvme)
- [Hardware Requirements](#hardware-requirements)
- [Installation Methods](#installation-methods)
- [Advanced Configurations](#advanced-configurations)
- [Performance Optimization](#performance-optimization)
- [Troubleshooting](#troubleshooting)

## Why Use NVMe?

### Performance Benefits

| Metric | SD Card | NVMe SSD | Improvement |
|--------|---------|----------|-------------|
| Sequential Read | 50 MB/s | 1500 MB/s | **30x faster** |
| Sequential Write | 20 MB/s | 1000 MB/s | **50x faster** |
| Random Read IOPS | 500 | 100,000 | **200x faster** |
| Random Write IOPS | 200 | 80,000 | **400x faster** |
| Boot Time | 45 seconds | 15 seconds | **3x faster** |
| Database Performance | Baseline | 50-100x | **Dramatically faster** |

### Use Cases Where NVMe Excels

- **Development:** Fast compilation, quick file operations
- **Databases:** PostgreSQL, MySQL, MongoDB
- **Container workloads:** Docker, Podman with many layers
- **Build systems:** Large codebases, CI/CD runners
- **File serving:** High-throughput NAS/file server
- **General computing:** Snappier overall system responsiveness

## Hardware Requirements

### Compatible NVMe Drives

**Tested and Working:**
- Samsung 970 EVO/PRO (250GB-2TB)
- Samsung 980/980 PRO
- WD Black SN750/SN850
- Crucial P5/P5 Plus
- Kingston KC2500/KC3000
- Sabrent Rocket NVMe

**Form Factors:**
- **M.2 2280** (Recommended - most common)
- **M.2 2260** (Works, less common)
- **M.2 2242** (Works, limited capacity)

**Interface:**
- **M-key** (Required)
- **PCIe 3.0 x4** (Full speed)
- PCIe 4.0 drives work but run at PCIe 3.0 speeds

**Capacity:**
- Minimum: 128GB
- Recommended: 256GB or larger
- Maximum: 2TB (tested), larger should work

### Installation

1. **Power off completely** - unplug power cable
2. **Ground yourself** - touch metal case
3. **Locate M.2 slot** - between CPU heatsink and PCIe x16 slot
4. **Insert NVMe at 30 degree angle**
5. **Press down gently until flat**
6. **Secure with mounting screw**
7. **Connect power**

**Important:** The thermal pad on some heatsinks may interfere. Remove if needed.

## Installation Methods

### Method 1: Live Migration (Easiest)

Boot from SD card, copy to NVMe while running.

**Step-by-step:**

1. **Boot from SD card** with your built image
2. **Login as root** (password: rockylinux)
3. **Verify NVMe detection:**
   ```bash
   lsblk
   # Should show nvme0n1
   
   dmesg | grep -i nvme
   # Should show detection messages
   ```

4. **Partition NVMe:**
   ```bash
   # Using fdisk (simpler)
   fdisk /dev/nvme0n1
   g              # Create GPT partition table
   n              # New partition
   [Enter]        # Partition 1
   [Enter]        # Default start
   [Enter]        # Use full disk
   w              # Write and exit
   
   # OR using parted (more control)
   parted /dev/nvme0n1
   mklabel gpt
   mkpart primary ext4 1MiB 100%
   quit
   ```

5. **Format partition:**
   ```bash
   mkfs.ext4 -L rootfs-nvme -O ^64bit /dev/nvme0n1p1
   # -L sets label
   # -O ^64bit for broader compatibility
   
   # Verify
   blkid /dev/nvme0n1p1
   ```

6. **Mount filesystems:**
   ```bash
   mkdir -p /mnt/{nvme,sd}
   mount /dev/nvme0n1p1 /mnt/nvme
   mount /dev/mmcblk0p3 /mnt/sd
   
   # Verify mounts
   df -h
   ```

7. **Copy filesystem (this takes time):**
   ```bash
   # Option A: Using rsync (recommended, shows progress)
   rsync -axHAWXS --numeric-ids --info=progress2 /mnt/sd/ /mnt/nvme/
   
   # Option B: Using tar (faster, no progress)
   tar -C /mnt/sd -cf - . | tar -C /mnt/nvme -xf -
   
   # Time: ~5-10 minutes for 4GB rootfs
   ```

8. **Update NVMe fstab:**
   ```bash
   # Edit fstab to use NVMe root
   nano /mnt/nvme/etc/fstab
   
   # Change:
   # LABEL=rootfs  /  ext4  defaults,noatime  0  1
   # To:
   LABEL=rootfs-nvme  /  ext4  defaults,noatime  0  1
   # OR use device path:
   /dev/nvme0n1p1  /  ext4  defaults,noatime  0  1
   
   # Save and exit (Ctrl+O, Enter, Ctrl+X)
   ```

9. **Update SD card bootloader config:**
   ```bash
   nano /mnt/sd/boot/extlinux/extlinux.conf
   
   # Find the "append" line and change:
   # root=/dev/mmcblk0p3
   # To:
   root=/dev/nvme0n1p1
   
   # Full line should look like:
   append earlyprintk rw root=/dev/nvme0n1p1 rootfstype=ext4 rootwait console=ttySIF0,115200
   
   # Save and exit
   ```

10. **Unmount and reboot:**
    ```bash
    sync
    umount /mnt/nvme
    umount /mnt/sd
    reboot
    ```

11. **Verify NVMe boot:**
    ```bash
    # After reboot
    df -h /
    # Should show /dev/nvme0n1p1
    
    cat /proc/cmdline
    # Should show root=/dev/nvme0n1p1
    ```

**Done!** System is now running from NVMe with SD card providing only the bootloader.

### Method 2: Direct Flash to NVMe

Write the image directly to NVMe, expanding to use full capacity.

**Prerequisites:**
- HiFive Unmatched booted from any Linux system (SD card or USB)
- Image file available on the board

**Steps:**

1. **Transfer image to board:**
   ```bash
   # From your host machine
   scp workspace/output/rocky-riscv-unmatched.img root@board-ip:/tmp/
   # Or use USB drive, network share, etc.
   ```

2. **Verify NVMe is detected:**
   ```bash
   lsblk
   ls -l /dev/nvme0n1
   ```

3. **Flash image to NVMe:**
   ```bash
   dd if=/tmp/rocky-riscv-unmatched.img of=/dev/nvme0n1 bs=4M status=progress conv=fsync
   sync
   
   # Time: ~2-3 minutes for 4GB image on NVMe
   ```

4. **Expand partition to use full disk:**
   ```bash
   # First, fix GPT backup header
   sgdisk -e /dev/nvme0n1
   
   # Verify partition layout
   parted /dev/nvme0n1 print
   
   # Note the partition 3 number and expand it
   parted /dev/nvme0n1 resizepart 3 100%
   
   # Verify expansion
   parted /dev/nvme0n1 print
   ```

5. **Expand filesystem:**
   ```bash
   # Check filesystem first
   e2fsck -f /dev/nvme0n1p3
   
   # Resize to fill partition
   resize2fs /dev/nvme0n1p3
   
   # Verify
   df -h /dev/nvme0n1p3
   # Should show full NVMe capacity
   ```

6. **Update boot configuration:**
   ```bash
   # Mount NVMe root partition
   mkdir /mnt/nvme
   mount /dev/nvme0n1p3 /mnt/nvme
   
   # Update extlinux.conf
   nano /mnt/nvme/boot/extlinux/extlinux.conf
   # Change: root=/dev/mmcblk0p3
   # To:     root=/dev/nvme0n1p3
   
   # Update fstab
   nano /mnt/nvme/etc/fstab
   # Change: LABEL=rootfs or /dev/mmcblk0p3
   # To:     /dev/nvme0n1p3
   
   # Unmount
   umount /mnt/nvme
   ```

7. **Update SD card bootloader:**
   ```bash
   mkdir /mnt/sd
   mount /dev/mmcblk0p3 /mnt/sd
   nano /mnt/sd/boot/extlinux/extlinux.conf
   # Change: root=/dev/mmcblk0p3
   # To:     root=/dev/nvme0n1p3
   umount /mnt/sd
   ```

8. **Reboot:**
   ```bash
   sync
   reboot
   ```

### Method 3: Bootloader-Only SD Card

Create a minimal SD card with only bootloader, all data on NVMe.

**Benefits:**
- Use very small SD card (1GB is enough)
- Minimal SD card wear
- Can remove SD card after boot (not recommended)
- Clean separation of bootloader and OS

**Steps:**

1. **Prepare small SD card:**
   ```bash
   # On your Linux host
   # Flash only bootloader partitions (first ~5MB)
   sudo dd if=workspace/output/rocky-riscv-unmatched.img \
      of=/dev/sdX bs=512 count=10273 status=progress
   # This copies only SPL and U-Boot partitions
   ```

2. **Create minimal partition 3:**
   ```bash
   sudo fdisk /dev/sdX
   n              # New partition
   3              # Partition number 3
   16384          # Start at same sector as full image
   +100M          # Small size, just for extlinux.conf
   w              # Write
   
   sudo mkfs.ext4 /dev/sdX3
   ```

3. **Create boot configuration:**
   ```bash
   sudo mkdir /mnt/sdcard
   sudo mount /dev/sdX3 /mnt/sdcard
   sudo mkdir -p /mnt/sdcard/boot/extlinux
   
   # Create extlinux.conf pointing to NVMe
   cat << 'EOF' | sudo tee /mnt/sdcard/boot/extlinux/extlinux.conf
   menu title Rocky Linux (NVMe Boot)
   timeout 50
   default rocky
   
   label rocky
       menu label Rocky Linux on NVMe
       kernel /boot/vmlinuz-6.6.x
       fdt /boot/dtbs/6.6.x/sifive/hifive-unmatched-a00.dtb
       initrd /boot/initramfs-6.6.x.img
       append earlyprintk rw root=/dev/nvme0n1p3 rootfstype=ext4 rootwait console=ttySIF0,115200 earlycon
   EOF
   
   sudo umount /mnt/sdcard
   ```

4. **Flash full image to NVMe** (see Method 2)

5. **Boot with bootloader-only SD card**

**Result:** SD card is only ~100MB, all system files on NVMe.

## Advanced Configurations

### RAID 1 with Multiple NVMe Drives

If you have a PCIe adapter with multiple NVMe slots:

```bash
# Install mdadm
dnf install mdadm

# Create RAID 1
mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/nvme0n1p1 /dev/nvme1n1p1

# Format
mkfs.ext4 -L rootfs-raid /dev/md0

# Update fstab and extlinux.conf to use /dev/md0
```

### LVM on NVMe

For flexible partition management:

```bash
# Create physical volume
pvcreate /dev/nvme0n1p1

# Create volume group
vgcreate vg_root /dev/nvme0n1p1

# Create logical volumes
lvcreate -L 50G -n lv_root vg_root
lvcreate -L 8G -n lv_swap vg_root
lvcreate -l 100%FREE -n lv_home vg_root

# Format
mkfs.ext4 /dev/vg_root/lv_root
mkswap /dev/vg_root/lv_swap
mkfs.ext4 /dev/vg_root/lv_home

# Update extlinux.conf:
# root=/dev/mapper/vg_root-lv_root
```

### Encrypted NVMe Root

Full disk encryption for security:

```bash
# Install cryptsetup
dnf install cryptsetup

# Encrypt NVMe partition
cryptsetup luksFormat /dev/nvme0n1p1
cryptsetup open /dev/nvme0n1p1 cryptroot

# Format encrypted device
mkfs.ext4 /dev/mapper/cryptroot

# Update extlinux.conf:
# root=/dev/mapper/cryptroot

# Update initramfs to include cryptsetup
dracut --add crypt --force
```

**Note:** You'll need to enter password at boot via serial console.

## Performance Optimization

### Filesystem Tuning

**For NVMe SSD, use these mount options:**

```bash
# Edit /etc/fstab
/dev/nvme0n1p1  /  ext4  defaults,noatime,nodiratime,discard  0  1
```

**Options explained:**
- `noatime` - Don't update access time (faster)
- `nodiratime` - Don't update directory access time
- `discard` - Enable TRIM support for SSD longevity

### I/O Scheduler

NVMe performs best with `none` scheduler:

```bash
# Check current scheduler
cat /sys/block/nvme0n1/queue/scheduler

# Set to none (recommended for NVMe)
echo none > /sys/block/nvme0n1/queue/scheduler

# Make permanent
echo 'ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"' \
  > /etc/udev/rules.d/60-nvme-scheduler.rules
```

### Swap on NVMe

Add swap space for systems with limited RAM:

```bash
# Create swap file (8GB example)
dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Add to fstab
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Verify
free -h
```

### Benchmark Your NVMe

```bash
# Install tools
dnf install hdparm fio nvme-cli

# Quick sequential test
hdparm -t /dev/nvme0n1

# Detailed NVMe info
nvme id-ctrl /dev/nvme0n1
nvme smart-log /dev/nvme0n1

# Comprehensive benchmark with fio
fio --name=random-read --ioengine=libaio --rw=randread \
  --bs=4k --direct=1 --size=1G --numjobs=4 --runtime=60 \
  --group_reporting --filename=/dev/nvme0n1p1

# Results to expect:
# Sequential read: 1200-1500 MB/s
# Sequential write: 800-1200 MB/s
# Random read IOPS: 80K-120K
# Random write IOPS: 60K-100K
```

## Troubleshooting

### NVMe Not Detected

**Check PCIe:**
```bash
lspci -vv | grep -i nvme
# Should show: Non-Volatile memory controller
```

**Check kernel module:**
```bash
lsmod | grep nvme
# Should show: nvme, nvme_core

# If not loaded
modprobe nvme
```

**Check kernel messages:**
```bash
dmesg | grep -i nvme
# Look for detection messages or errors
```

**Common issues:**
- Drive not fully seated - power off and reseat
- Incompatible drive - try different brand
- Bad thermal contact - remove thermal pad if present
- PCIe slot issue - clean contacts

### Boot Hangs at "Waiting for root device"

**Check extlinux.conf:**
```bash
# From SD card boot:
mount /dev/mmcblk0p3 /mnt
cat /mnt/boot/extlinux/extlinux.conf
# Verify root= points to correct NVMe partition
```

**Check NVMe partition:**
```bash
ls -l /dev/nvme0n1*
# Should show partitions

blkid /dev/nvme0n1p3
# Verify filesystem type
```

**Try UUID instead of device path:**
```bash
# Get UUID
blkid /dev/nvme0n1p3
# UUID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Use in extlinux.conf:
root=UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### Slow Performance

**Check PCIe link speed:**
```bash
lspci -vv | grep -A 10 "Non-Volatile"
# Look for: LnkSta: Speed 8GT/s, Width x4
```

**If running at slower speed:**
- Power off and reseat NVMe
- Check for PCIe bifurcation issues if using adapter
- Verify drive supports PCIe 3.0 x4

**Check I/O scheduler:**
```bash
cat /sys/block/nvme0n1/queue/scheduler
# Should show: [none] for NVMe
```

**Check mount options:**
```bash
mount | grep nvme
# Should include: noatime,discard
```

### Filesystem Errors

**Check and repair:**
```bash
# Boot from SD card first
umount /dev/nvme0n1p3
e2fsck -f /dev/nvme0n1p3
```

**Bad blocks:**
```bash
# Scan for bad blocks (takes hours)
badblocks -v /dev/nvme0n1

# NVMe should have 0 bad blocks (has internal remapping)
```

### TRIM Not Working

**Verify TRIM support:**
```bash
# Check if drive supports TRIM
hdparm -I /dev/nvme0n1 | grep TRIM
# Should show: Data Set Management TRIM supported

# Test TRIM
fstrim -v /

# Enable periodic TRIM
systemctl enable fstrim.timer
systemctl start fstrim.timer
```

## Additional Resources

- [HiFive Unmatched Documentation](https://www.sifive.com/boards/hifive-unmatched)
- [NVMe Specification](https://nvmexpress.org/)
- [Linux NVMe Wiki](https://nvmexpress.org/resources/linux/)
- [Kernel NVMe Documentation](https://www.kernel.org/doc/html/latest/driver-api/nvmem.html)

## Summary

NVMe boot on HiFive Unmatched provides:
- **30x faster** sequential I/O vs SD card
- **200x faster** random I/O
- **3x faster** boot times
- Better responsiveness for development, databases, containers

Recommended configuration:
- Bootloader on SD card (easy recovery)
- Root filesystem on NVMe (best performance)
- Regular backups (NVMe is faster but SD card is removable)
