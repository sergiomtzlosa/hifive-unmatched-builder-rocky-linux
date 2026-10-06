#!/bin/bash
# Download Rocky Linux RISC-V rootfs

set -e

echo "===================================="
echo "Downloading Rocky Linux Rootfs"
echo "===================================="

# Get workspace root (../workspace from scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../workspace" && pwd)"

BUILD_DIR=${BUILD_DIR:-${WORKSPACE_ROOT}/build}
ROOTFS_DIR="${BUILD_DIR}/rootfs"
mkdir -p "${ROOTFS_DIR}"

# Try Rocky Linux first
ROCKY_URL="https://dl.rockylinux.org/pub/rocky/10/images/riscv64/"
FEDORA_URL="https://dl.fedoraproject.org/pub/fedora-secondary/releases/38/Container/riscv64/images/"

echo "Checking for Rocky Linux RISC-V images..."

# Try to download Rocky Linux rootfs
ROCKY_AVAILABLE=false
if curl --output /dev/null --silent --head --fail "${ROCKY_URL}"; then
    echo "Rocky Linux RISC-V repository found!"
    # List available images
    echo "Available images:"
    curl -s "${ROCKY_URL}" | grep -o 'href="[^"]*\.tar\.[gx]z"' | sed 's/href="//;s/"$//' || true
    
    # Prefer non-OCI format if available, otherwise use OCI
    # Try regular tar.xz first (non-container image)
    ROCKY_IMAGE=""
    for img in "Rocky-10-Base.latest.riscv64.tar.xz" "Rocky-10-Container-Base.latest.riscv64.tar.xz"; do
        if curl --output /dev/null --silent --head --fail "${ROCKY_URL}${img}"; then
            ROCKY_IMAGE="$img"
            break
        fi
    done
    
    if [ -n "$ROCKY_IMAGE" ]; then
        echo "Downloading: ${ROCKY_IMAGE}"
        if curl -L -o "${ROOTFS_DIR}/rootfs.tar.xz" "${ROCKY_URL}${ROCKY_IMAGE}" 2>/dev/null; then
            ROCKY_AVAILABLE=true
            echo "Rocky Linux rootfs downloaded successfully!"
        fi
    fi
fi

# Fallback to Fedora if Rocky not available
if [ "$ROCKY_AVAILABLE" = false ]; then
    echo "Rocky Linux not available, using Fedora RISC-V as fallback..."
    FEDORA_IMAGE="Fedora-Container-Base-38-1.6.riscv64.tar.xz"
    
    echo "Downloading Fedora RISC-V rootfs..."
    curl -L -o "${ROOTFS_DIR}/rootfs.tar.xz" \
        "${FEDORA_URL}${FEDORA_IMAGE}"
    
    echo "Fedora rootfs downloaded successfully!"
fi

# Extract rootfs
echo "Extracting rootfs..."
cd "${ROOTFS_DIR}"
rm -rf extracted rootfs
mkdir -p extracted
tar xf rootfs.tar.xz -C extracted

# Check if it's OCI format
if [ -f "extracted/oci-layout" ] && [ -d "extracted/blobs" ]; then
    echo "Detected OCI container format, extracting layers..."
    mkdir -p rootfs
    
    # Find and extract all layer blobs (they contain the actual filesystem)
    # OCI blobs are content-addressed, so we need to find layer tarballs
    for blob in extracted/blobs/sha256/*; do
        if [ -f "$blob" ]; then
            # Try to extract as tar - layer blobs are tar archives
            if tar -tzf "$blob" >/dev/null 2>&1; then
                echo "Extracting layer: $(basename $blob)"
                tar xf "$blob" -C rootfs 2>/dev/null || true
            fi
        fi
    done
    
    rm -rf extracted
    echo "OCI container layers extracted to rootfs/"
    
elif [ -f "extracted/manifest.json" ]; then
    echo "Detected Docker container image format, extracting layers..."
    LAYER=$(tar tf rootfs.tar.xz | grep 'layer.tar' | head -1)
    if [ -n "$LAYER" ]; then
        tar xf rootfs.tar.xz "$LAYER" -C extracted
        mkdir -p rootfs
        tar xf "extracted/${LAYER}" -C rootfs
        rm -rf extracted
        echo "Container layers extracted to rootfs/"
    fi
else
    # Plain tarball
    mv extracted rootfs
fi

# Verify essential directories
ROOTFS_PATH="${ROOTFS_DIR}/rootfs"
if [ ! -d "${ROOTFS_PATH}/etc" ] || [ ! -d "${ROOTFS_PATH}/usr" ]; then
    echo "ERROR: Invalid rootfs structure!"
    echo "Contents of ${ROOTFS_PATH}:"
    ls -la "${ROOTFS_PATH}"
    echo ""
    echo "This might be a container image without a full filesystem."
    echo "You may need to build a proper bootable rootfs manually."
    exit 1
fi

echo "Rootfs structure verified:"
ls -la "${ROOTFS_PATH}"

echo "===================================="
echo "Rootfs download complete!"
echo "Location: ${ROOTFS_PATH}"
echo "===================================="
