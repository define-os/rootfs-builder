#!/bin/sh
base_packages=()
packages=()
SCRIPT_DIR=$(pwd)/$(dirname $0)
CURR_PATH=$(pwd)

cd $SCRIPT_DIR

. ./config.sh

prepare_dirs() {
    [ -d "rootfs" ] && sudo rm -rf rootfs
    mkdir rootfs
}

download_ports() {
    [ -d "$ports_extracted_dir" ] && return
    wget $ports_url -O ports.tar.gz
    tar xf ports.tar.gz
    rm ports.tar.gz
}

install_base_packages() {
    for pkg in ${base_packages[@]}; do
        [ -d "$ports_extracted_dir/$pkg" ] || err 1 "Package $pkg not found"
        cd $ports_extracted_dir/$pkg
        PATH="$PATH:${SCRIPT_DIR}/rootfs/usr/local/bin:${SCRIPT_DIR}/rootfs/usr/local/sbin" INSTALL_PATH=${SCRIPT_DIR}/rootfs ./package.sh || err 2 "Package $pkg failed build with code $?"
        cd $SCRIPT_DIR
    done
}
chroot_prepare() {
    sudo mount -t proc proc         ${SCRIPT_DIR}/rootfs/proc
    sudo mount -t devtmpfs devtmpfs ${SCRIPT_DIR}/rootfs/dev
    sudo mount -t sysfs sysfs       ${SCRIPT_DIR}/rootfs/sys
    sudo mount -t tmpfs tmpfs       ${SCRIPT_DIR}/rootfs/run
    sudo mount -t tmpfs tmpfs       ${SCRIPT_DIR}/rootfs/tmp
    sudo rm -rf                     ${SCRIPT_DIR}/rootfs/usr/ports/packages.db
}
chroot_cleanup() {
    for dir in proc dev sys run tmp; do
        sudo umount ${SCRIPT_DIR}/rootfs/$dir
    done
    sudo rm -rf ${SCRIPT_DIR}/rootfs/build.sh
    sudo rm -rf ${SCRIPT_DIR}/rootfs/ports
}
install_packages() {
    cp -r $ports_extracted_dir ${SCRIPT_DIR}/rootfs/ports
    port_base_dir="${SCRIPT_DIR}/rootfs/ports"
    for pkg in ${packages[@]}; do
        [ -d "${port_base_dir}/$pkg" ] || err 1 "Package $pkg not found"
        echo "cd /ports/$pkg" > rootfs/build.sh
        echo "exec ./package.sh" >> rootfs/build.sh
        sudo chroot "${SCRIPT_DIR}/rootfs" /bin/env PATH="/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin" /usr/bin/sh ./build.sh || err 2 "Package $pkg failed build with code $?"
    done
}
create_rootfs() {
    sudo chown -R root:root rootfs
    mksquashfs rootfs rootfs.sqfs
}
cleanup() {
    sudo rm -rf "rootfs"
    sudo rm -rf "$ports_extracted_dir"
}

err() {
    echo "[ERROR] $2"
    cd $CURR_PATH
    chroot_cleanup
    exit $1
}

log() {
    echo "[LOG] $1" 
}

log "building rootfs, please wait..."
prepare_dirs
download_ports
install_base_packages
chroot_prepare
install_packages
chroot_cleanup
create_rootfs
cleanup
cd $CURR_PATH
