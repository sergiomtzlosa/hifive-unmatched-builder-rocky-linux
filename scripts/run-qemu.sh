#!/bin/bash
# QEMU Test Script - NOT SUPPORTED FOR THIS IMAGE
#
# WARNING: THIS IMAGE DOES NOT WORK IN QEMU!
#
# This image is built specifically for SiFive HiFive Unmatched hardware.
# U-Boot is configured for real hardware and WILL FAIL in QEMU with
# memory access faults.
#
# DO NOT USE THIS SCRIPT - Test on real HiFive Unmatched hardware instead!

echo "============================================"
echo "  QEMU NOT SUPPORTED"
echo "============================================"
echo ""
echo "This image is built for SiFive HiFive Unmatched hardware ONLY."
echo ""
echo "The bootloader (U-Boot) is configured for real hardware and"
echo "will crash in QEMU with Store/AMO access faults."
echo ""
echo "============================================"
echo "To test this image on REAL HARDWARE:"
echo "============================================"
echo ""
echo "1. Flash to SD card:"
echo "   sudo dd if=output/rocky-riscv-unmatched.img of=/dev/sdX bs=4M status=progress"
echo "   sudo sync"
echo ""
echo "2. Insert SD card into HiFive Unmatched board"
echo ""
echo "3. Connect serial console:"
echo "   - Baud rate: 115200"
echo "   - Device: ttyUSB0 (or similar)"
echo ""
echo "4. Power on the board"
echo ""
echo "5. Login credentials:"
echo "   Username: root"
echo "   Password: rockylinux"
echo ""
echo "============================================"
echo ""

exit 1
