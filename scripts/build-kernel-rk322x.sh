#!/bin/bash
# Script de build de kernel RK322x para projetor
# Baseado no build-kernel-rk322x.sh do CaraAzul

set -e

ARCH="arm"
CROSS_COMPILE="arm-linux-gnueabihf-"
KERNEL_SRC="linux-rockchip"
JOBS=$(nproc)
DEFCONFIG="rockchip_defconfig"
DTB="rk322x-box.dtb"

usage() {
    echo "Uso: $0 [opcoes]"
    echo "  -v VERSAO     Versao do kernel (default: 6.6.22)"
    echo "  -j JOBS       Numero de jobs (default: nproc)"
    echo "  -c            Apenas configurar"
    echo "  -h            Ajuda"
    exit 1
}

while getopts "v:j:ch" opt; do
    case $opt in
        v) KERNEL_VERSION="$OPTARG" ;;
        j) JOBS="$OPTARG" ;;
        c) CONFIG_ONLY=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

echo "============================================="
echo "  Build Kernel RK322x - v${KERNEL_VERSION}"
echo "  Jobs: ${JOBS}"
echo "============================================="

# Clona se nao existir
if [ ! -d "$KERNEL_SRC" ]; then
    echo "Clonando kernel source..."
    git clone --depth=1 --branch=linux-6.6.y \
        https://github.com/armbian/linux-rockchip.git "$KERNEL_SRC"
fi

cd "$KERNEL_SRC"

echo "Configurando..."
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} ${DEFCONFIG}

if [ -n "$CONFIG_ONLY" ]; then
    echo "Configuracao concluida. Para compilar manualmente:"
    echo "  make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} zImage dtbs modules -j${JOBS}"
    exit 0
fi

echo "Compilando kernel, dtbs e modulos..."
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} zImage dtbs modules -j${JOBS}

echo "============================================="
echo "  Build concluido!"
echo "  Kernel: arch/arm/boot/zImage"
echo "  DTB:    arch/arm/boot/dts/${DTB}"
echo "============================================="
