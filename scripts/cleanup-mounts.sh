#!/bin/bash
# Cleanup any leftover mounts and loop devices from failed builds

set +e  # Don't exit on error - we want to try all cleanup steps

echo "===================================="
echo "Cleanup Mounts and Loop Devices"
echo "===================================="

# Get workspace root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to find workspace root - in Docker it's /workspace, otherwise relative path
if [ -d "/workspace" ]; then
    WORKSPACE_ROOT="/workspace"
else
    WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

MOUNT_POINT="${WORKSPACE_ROOT}/build/mnt"

echo ""
echo "Checking for leftover mounts..."
echo ""

# Show current mounts related to the mount point
if mountpoint -q "${MOUNT_POINT}" 2>/dev/null; then
    echo "Found mounts at ${MOUNT_POINT}"
    mount | grep "${MOUNT_POINT}"
    echo ""
else
    echo "No mounts found at ${MOUNT_POINT}"
fi

# Unmount all nested mounts first (dev, sys, proc)
echo "Unmounting nested filesystems..."
if [ -d "${MOUNT_POINT}" ]; then
    # Unmount recursively bound devices
    umount -R "${MOUNT_POINT}/dev" 2>/dev/null && echo "  ✓ Unmounted ${MOUNT_POINT}/dev" || echo "  - No dev mount"
    
    # Unmount proc and sys
    umount "${MOUNT_POINT}/proc" 2>/dev/null && echo "  ✓ Unmounted ${MOUNT_POINT}/proc" || echo "  - No proc mount"
    umount "${MOUNT_POINT}/sys" 2>/dev/null && echo "  ✓ Unmounted ${MOUNT_POINT}/sys" || echo "  - No sys mount"
    
    # Force unmount any remaining mounts at the mount point
    if mountpoint -q "${MOUNT_POINT}" 2>/dev/null; then
        umount -f "${MOUNT_POINT}" 2>/dev/null && echo "  ✓ Force unmounted ${MOUNT_POINT}" || umount -l "${MOUNT_POINT}" 2>/dev/null && echo "  ✓ Lazy unmounted ${MOUNT_POINT}"
    else
        echo "  - No main mount"
    fi
fi

echo ""
echo "Checking for loop devices..."
echo ""

# List all loop devices associated with our image
OUTPUT_DIR=${OUTPUT_DIR:-${WORKSPACE_ROOT}/output}
IMAGE_NAME=${IMAGE_NAME:-rocky-riscv-unmatched.img}
IMAGE_PATH="${OUTPUT_DIR}/${IMAGE_NAME}"

# Find loop devices using our image
LOOP_DEVICES=$(losetup -j "${IMAGE_PATH}" 2>/dev/null | cut -d: -f1)

if [ -n "$LOOP_DEVICES" ]; then
    echo "Found loop devices associated with ${IMAGE_NAME}:"
    losetup -j "${IMAGE_PATH}"
    echo ""
    
    echo "Detaching loop devices..."
    for loop in $LOOP_DEVICES; do
        echo "  Detaching $loop..."
        losetup -d "$loop" 2>/dev/null && echo "    ✓ Detached $loop" || echo "    ✗ Failed to detach $loop"
    done
else
    echo "No loop devices found for ${IMAGE_NAME}"
fi

# Also check for any orphaned loop devices from the workspace
echo ""
echo "Checking for orphaned loop devices from workspace..."
WORKSPACE_LOOPS=$(losetup -a | grep "${WORKSPACE_ROOT}" | cut -d: -f1)
if [ -n "$WORKSPACE_LOOPS" ]; then
    echo "Found orphaned loop devices:"
    losetup -a | grep "${WORKSPACE_ROOT}"
    echo ""
    for loop in $WORKSPACE_LOOPS; do
        echo "  Detaching $loop..."
        losetup -d "$loop" 2>/dev/null && echo "    ✓ Detached $loop" || echo "    ✗ Failed to detach $loop"
    done
else
    echo "No orphaned loop devices found"
fi

echo ""
echo "===================================="
echo "Cleanup Summary"
echo "===================================="
echo ""

# Final status check
if mountpoint -q "${MOUNT_POINT}" 2>/dev/null; then
    echo "⚠️  WARNING: ${MOUNT_POINT} is still mounted!"
    echo "Remaining mounts:"
    mount | grep "${MOUNT_POINT}"
else
    echo "✓ All mounts cleaned up"
fi

REMAINING_LOOPS=$(losetup -j "${IMAGE_PATH}" 2>/dev/null)
if [ -n "$REMAINING_LOOPS" ]; then
    echo "⚠️  WARNING: Loop devices still attached!"
    echo "$REMAINING_LOOPS"
else
    echo "✓ All loop devices detached"
fi

echo ""
echo "Current loop device status:"
losetup -l | head -20

echo ""
echo "Cleanup complete!"
