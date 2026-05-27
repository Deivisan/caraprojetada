#!/bin/bash
# Setup do ambiente de desenvolvimento RK322x para projetor
# Baseado no toolchain do CaraAzul

set -e

echo "============================================="
echo "  CaraProjetada Toolchain - RK322x Setup"
echo "============================================="

ARCH="arm-linux-gnueabihf"
KERNEL_VERSION="6.6.22"

usage() {
    echo "Uso: $0 {deps|kernel|rootfs|full}"
    echo "  deps     - Instala dependencias de build"
    echo "  kernel   - Baixa e prepara kernel RK322x"
    echo "  rootfs   - Prepara rootfs minima para projetor"
    echo "  full     - Executa todos os passos"
    exit 1
}

install_deps() {
    echo "[1/4] Instalando dependencias de build..."
    sudo apt update
    sudo apt install -y \
        gcc-arm-linux-gnueabihf \
        build-essential git bc bison flex \
        libssl-dev libelf-dev python3 \
        qemu-user-static debootstrap
    echo "[OK] Dependencias instaladas."
}

setup_kernel() {
    echo "[2/4] Configurando kernel RK322x ${KERNEL_VERSION}..."
    
    KERNEL_DIR="linux-rockchip"
    if [ ! -d "$KERNEL_DIR" ]; then
        git clone --depth=1 --branch=linux-6.6.y \
            https://github.com/armbian/linux-rockchip.git
    fi
    
    cd "$KERNEL_DIR"
    make ARCH=arm CROSS_COMPILE=${ARCH}- rockchip_defconfig
    echo "[OK] Kernel configurado. Para compilar:"
    echo "    cd ${KERNEL_DIR}"
    echo "    make ARCH=arm CROSS_COMPILE=${ARCH}- zImage dtbs modules -j\$(nproc)"
}

setup_rootfs() {
    echo "[3/4] Preparando rootfs minima para projetor..."
    
    ROOTFS_DIR="rootfs-projetor"
    mkdir -p "$ROOTFS_DIR"
    
    # Pacotes essenciais para o projetor
    PACKAGES="python3,python3-flask,python3-ldap3,xtightvncviewer,chromium,"
    PACKAGES+="x11-utils,xfwm4,lightdm,openssh-server,systemd"
    
    sudo debootstrap --arch=armhf --foreign bullseye "$ROOTFS_DIR"
    sudo cp /usr/bin/qemu-arm-static "$ROOTFS_DIR/usr/bin/"
    sudo chroot "$ROOTFS_DIR" /debootstrap/debootstrap --second-stage
    
    echo "[OK] Rootfs preparada em ${ROOTFS_DIR}/"
    echo "    Tamanho: $(du -sh ${ROOTFS_DIR} | cut -f1)"
}

full_setup() {
    install_deps
    setup_kernel
    setup_rootfs
    echo "============================================="
    echo "  Toolchain completo!"
    echo "============================================="
}

case "${1:-full}" in
    deps)   install_deps ;;
    kernel) setup_kernel ;;
    rootfs) setup_rootfs ;;
    full)   full_setup ;;
    *)      usage ;;
esac
