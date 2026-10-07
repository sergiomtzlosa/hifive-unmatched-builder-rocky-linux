# Dockerfile for HiFive Unmatched U-Boot + Rocky Linux Builder
# This container provides a complete build environment for RISC-V development

FROM ubuntu:22.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install build dependencies
RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    autotools-dev \
    bc \
    bison \
    build-essential \
    curl \
    device-tree-compiler \
    flex \
    gawk \
    gdisk \
    git \
    gperf \
    libexpat-dev \
    libgmp-dev \
    libmpc-dev \
    libmpfr-dev \
    libncurses-dev \
    libssl-dev \
    libtool \
    patchutils \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-dev \
    python3-distutils \
    swig \
    texinfo \
    wget \
    zlib1g-dev \
    qemu-system-misc \
    qemu-system-riscv64 \
    dosfstools \
    kpartx \
    parted \
    rsync \
    sudo \
    vim \
    file \
    libfdt-dev \
    kmod \
    cpio \
    dnf \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Install pre-built RISC-V toolchain from Bootlin
RUN mkdir -p /opt/riscv && \
    cd /opt/riscv && \
    wget -q https://toolchains.bootlin.com/downloads/releases/toolchains/riscv64-lp64d/tarballs/riscv64-lp64d--glibc--stable-2024.02-1.tar.bz2 && \
    tar xf riscv64-lp64d--glibc--stable-2024.02-1.tar.bz2 && \
    rm riscv64-lp64d--glibc--stable-2024.02-1.tar.bz2 && \
    ln -s riscv64-lp64d--glibc--stable-2024.02-1 toolchain

# Set environment variables for RISC-V toolchain
ENV PATH="/opt/riscv/toolchain/bin:${PATH}"
ENV CROSS_COMPILE=riscv64-buildroot-linux-gnu-

# Install Python packages needed for U-Boot using system Python
# The RISC-V toolchain python doesn't have pip, so use /usr/bin/python3
RUN /usr/bin/python3 -m pip install --upgrade pip && \
    /usr/bin/python3 -m pip install setuptools wheel && \
    /usr/bin/python3 -m pip install pylibfdt || true

# Make sure system python3 is used (not toolchain's python)
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

# Verify toolchain installation
RUN riscv64-buildroot-linux-gnu-gcc --version

# Create build directory structure
RUN mkdir -p /workspace/build/{opensbi,u-boot,rootfs,image} \
    /workspace/scripts \
    /workspace/configs \
    /workspace/docs \
    /workspace/output

# Set up environment variables
ENV WORKSPACE=/workspace
ENV BUILD_DIR=/workspace/build
ENV OUTPUT_DIR=/workspace/output
ENV OPENSBI_VERSION=v1.3
ENV UBOOT_VERSION=v2024.01

# Set default command
CMD ["/bin/bash"]

# Add a welcome message script
RUN echo '#!/bin/bash' > /usr/local/bin/welcome && \
    echo 'echo "=== HiFive Unmatched U-Boot Builder ==="' >> /usr/local/bin/welcome && \
    echo 'echo ""' >> /usr/local/bin/welcome && \
    echo 'echo "Build environment ready!"' >> /usr/local/bin/welcome && \
    echo 'echo ""' >> /usr/local/bin/welcome && \
    echo 'echo "Available commands:"' >> /usr/local/bin/welcome && \
    echo 'echo "  cd /workspace"' >> /usr/local/bin/welcome && \
    echo 'echo "  ./scripts/test-build-env.sh  - Test build environment"' >> /usr/local/bin/welcome && \
    echo 'echo "  ./scripts/build-all.sh       - Build everything"' >> /usr/local/bin/welcome && \
    echo 'echo "  ./scripts/build-opensbi.sh   - Build OpenSBI only"' >> /usr/local/bin/welcome && \
    echo 'echo "  ./scripts/build-uboot.sh     - Build U-Boot only"' >> /usr/local/bin/welcome && \
    echo 'echo "  ./scripts/run-qemu.sh        - Test in QEMU"' >> /usr/local/bin/welcome && \
    echo 'echo ""' >> /usr/local/bin/welcome && \
    echo 'echo "Toolchain: ${CROSS_COMPILE}gcc"' >> /usr/local/bin/welcome && \
    echo 'echo "OpenSBI: ${OPENSBI_VERSION}"' >> /usr/local/bin/welcome && \
    echo 'echo "U-Boot: ${UBOOT_VERSION}"' >> /usr/local/bin/welcome && \
    echo 'echo ""' >> /usr/local/bin/welcome && \
    chmod +x /usr/local/bin/welcome && \
    echo 'welcome' >> /root/.bashrc

WORKDIR /workspace
