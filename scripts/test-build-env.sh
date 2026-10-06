#!/bin/bash
# Test the build environment and verify all dependencies

set -e

echo "===================================="
echo "Build Environment Test"
echo "===================================="
echo ""

# Get workspace root (../workspace from scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../workspace" && pwd)"

echo "Workspace: ${WORKSPACE_ROOT}"
echo ""

ERRORS=0

# Function to check command
check_command() {
    if command -v $1 &> /dev/null; then
        echo "[OK] $1: $(command -v $1)"
        if [ -n "$2" ]; then
            VERSION=$($1 $2 2>&1 | head -1)
            echo "   Version: $VERSION"
        fi
    else
        echo "[ERROR] $1: NOT FOUND"
        ERRORS=$((ERRORS + 1))
    fi
}

# Function to check environment variable
check_env() {
    if [ -n "${!1}" ]; then
        echo "[OK] $1=${!1}"
    else
        echo "[WARN]  $1: Not set"
    fi
}

echo "=== Required Commands ==="
echo ""

# Set CROSS_COMPILE if not already set
if [ -z "$CROSS_COMPILE" ]; then
    export CROSS_COMPILE=riscv64-buildroot-linux-gnu-
    echo "[WARN]  CROSS_COMPILE was not set, defaulting to: ${CROSS_COMPILE}"
    echo ""
fi

check_command make "--version"
check_command git "--version"
check_command gcc "--version"
check_command ${CROSS_COMPILE}gcc "--version"
check_command dtc "-v"
check_command sgdisk "--version"
check_command qemu-system-riscv64 "--version"

echo ""
echo "=== Optional Commands ==="
echo ""
check_command wget "--version"
check_command curl "--version"
check_command rsync "--version"
check_command sudo "-V"

echo ""
echo "=== Environment Variables ==="
echo ""
check_env CROSS_COMPILE
check_env PATH
check_env WORKSPACE
check_env BUILD_DIR
check_env OUTPUT_DIR

echo ""
echo "=== Toolchain Test ==="
echo ""

# Create a simple test program
TEST_DIR="/tmp/toolchain-test-$$"
mkdir -p "${TEST_DIR}"
cd "${TEST_DIR}"

cat > test.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello, RISC-V!\n");
    return 0;
}
EOF

echo "Compiling test program..."
if ${CROSS_COMPILE}gcc -o test test.c 2>/dev/null; then
    echo "[OK] Toolchain compilation successful"
    
    # Check if it's really a RISC-V binary
    if file test | grep -q "RISC-V"; then
        echo "[OK] Binary is RISC-V architecture"
    else
        echo "[ERROR] Binary is not RISC-V!"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "[ERROR] Toolchain compilation failed!"
    ERRORS=$((ERRORS + 1))
fi

# Cleanup
cd - > /dev/null
rm -rf "${TEST_DIR}"

echo ""
echo "=== Disk Space ==="
echo ""
df -h /workspace 2>/dev/null || df -h .

echo ""
echo "=== Summary ==="
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "[OK] All checks passed! Build environment is ready."
    echo ""
    echo "You can now run:"
    echo "  ./scripts/build-all.sh"
    exit 0
else
    echo "[ERROR] Found $ERRORS error(s). Please fix them before building."
    exit 1
fi
