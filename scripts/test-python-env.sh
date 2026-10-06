#!/bin/bash
# Test Python environment for U-Boot build

echo "===================================="
echo "Python Environment Test"
echo "===================================="

echo ""
echo "1. PATH variable:"
echo "${PATH}"
echo ""

echo "2. Which python3:"
which python3
echo ""

echo "3. Python3 version:"
python3 --version
echo ""

echo "4. System Python (/usr/bin/python3):"
/usr/bin/python3 --version
echo ""

echo "5. Toolchain Python (if exists):"
if [ -f "/opt/riscv/toolchain/bin/python3" ]; then
    /opt/riscv/toolchain/bin/python3 --version
else
    echo "Not found (this is OK)"
fi
echo ""

echo "6. Check setuptools with system Python:"
/usr/bin/python3 -c "import setuptools; print('setuptools version:', setuptools.__version__)" 2>&1
echo ""

echo "7. Check setuptools with 'python3' command:"
python3 -c "import setuptools; print('setuptools version:', setuptools.__version__)" 2>&1
echo ""

echo "8. Check pylibfdt with system Python:"
/usr/bin/python3 -c "import libfdt; print('pylibfdt OK')" 2>&1 || echo "pylibfdt not available (may build from source)"
echo ""

echo "9. PYTHON environment variables:"
echo "PYTHON=${PYTHON}"
echo "PYTHON3=${PYTHON3}"
echo ""

echo "===================================="
echo "Environment test complete"
echo "===================================="
