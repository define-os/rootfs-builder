#!/bin/sh
base_packages=()
packages=()
SCRIPT_DIR=$(pwd)/$(dirname $0)
CURR_PATH=$(pwd)

cd $SCRIPT_DIR

. ./config.sh

prepare_dirs() {
    [ -d "rootfs" ] && rm -rf rootfs
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
        INSTALL_PATH=${SCRIPT_DIR}/rootfs ./package.sh || err 2 "Package $pkg failed build with code $?"
    done
    cd $SCRIPT_DIR
}
install_packages() {
    cp -r $ports_extracted_dir ${SCRIPT_DIR}/rootfs/ports
    port_base_dir="${SCRIPT_DIR}/rootfs/ports"
    for pkg in ${packages[@]}; do
        [ -d "${port_base_dir}/$pkg" ] || err 1 "Package $pkg not found"
        echo "cd /ports/$pkg" > rootfs/build.sh
        echo "./package.sh" >> rootfs/build.sh
        sudo chroot "${SCRIPT_DIR}/rootfs" /bin/env PATH="/bin:/sbin" /bin/sh ./build.sh || err 2 "Package $pkg failed build with code $?"
    done
}

err() {
    echo "[ERROR] $2"
    cd $CURR_PATH
    exit $1
}

log() {
    echo "[LOG] $1" 
}

log "building rootfs, please wait..."
prepare_dirs
download_ports
install_base_packages
install_packages
# create_rootfs
cd $CURR_PATH
