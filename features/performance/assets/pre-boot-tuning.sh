#!/bin/bash

set -euo pipefail

non_iso_cpumask=""
cpu_affinity=""

get_reserved_cores() {
    cores=()
    while read part; do
        if [[ $part =~ - ]]; then
            cores+=($(seq ${part/-/ }))
        elif [[ $part =~ , ]]; then
            continue 
        else
            cores+=($part)
        fi
    done < <( echo ${NON_ISOLATED_CPUS} | tr ',' '\n' )
}

# $1 - 0 for irq balance banned cpus masking , 1 for non isolated cpus masking
get_cpu_mask() {
    if [ "$1" = "1" ]; then
        mask=( 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 )
    else
        mask=( 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 ) 
    fi    
    get_reserved_cores
    for core in ${cores[*]}; do
        mask[$core]=$1
    done
    cpumaskBinary=`echo ${mask[@]}| rev`
    cpumaskBinary=${cpumaskBinary//[[:space:]]/}
    non_iso_cpumask=`printf '%08x\n' "$((2#$cpumaskBinary))"`
}

get_cpu_affinity() {
    cpu_affinity=""
    get_reserved_cores
    for core in ${cores[*]}; do
        cpu_affinity+=" $core"
    done
    echo "CPU Affinity set to $cpu_affinity"
}

# TODO - find a more robust approach than keeping the last timestamp
RHCOS_OSTREE_PATH=$(ls -td /boot/ostree/*/ | head -1)
RHCOS_OSTREE_BOOTLOADER_PATH=${RHCOS_OSTREE_PATH#"/boot"}
INITRD_GENERATION_DIR="/root/initrd"
INITRD_NEW_IMAGE="${RHCOS_OSTREE_PATH}/iso_initrd.img"

# TODO: improve check for applied configuration
if [ -f ${INITRD_NEW_IMAGE} ] && grep -qsR "iso_initrd.img" "/boot/loader/entries/"; then
    echo "Pre boot tuning configuration already applied"
    echo "Setting kernel rcuo* threads to the housekeeping cpus"
    get_cpu_mask 1
    pgrep rcuo* | while read line; do taskset -p $non_iso_cpumask $line || true; done
else
    # Clean up
    rm -rf ${INITRD_GENERATION_DIR}
    
    # Create initrd image
    mkdir ${INITRD_GENERATION_DIR}
    mkdir -p ${INITRD_GENERATION_DIR}/usr/lib/dracut/hooks/pre-udev/
    mkdir -p ${INITRD_GENERATION_DIR}/etc/systemd/
    mkdir -p ${INITRD_GENERATION_DIR}/etc/sysconfig/
    touch ${INITRD_GENERATION_DIR}/etc/systemd/system.conf
    touch ${INITRD_GENERATION_DIR}/etc/sysconfig/irqbalance
    touch ${INITRD_GENERATION_DIR}/usr/lib/dracut/hooks/pre-udev/00-tuned-pre-udev.sh
    chmod +x ${INITRD_GENERATION_DIR}/usr/lib/dracut/hooks/pre-udev/00-tuned-pre-udev.sh

    get_cpu_mask 1
    echo '#!/bin/sh

    type getargs >/dev/null 2>&1 || . /lib/dracut-lib.sh

    #cpumask="$(getargs non_iso_cpumask)"
    cpumask='$non_iso_cpumask'

    log()
    {
    echo "tuned: $@" >> /dev/kmsg
    }

    if [ -n "$cpumask" ]; then
    for file in /sys/devices/virtual/workqueue/cpumask /sys/bus/workqueue/devices/writeback/cpumask; do
        log "setting $file CPU mask to $cpumask"
        if ! echo $cpumask > $file 2>/dev/null; then
        log "ERROR: could not write CPU mask for $file"
        fi
    done
    fi' > ${INITRD_GENERATION_DIR}/usr/lib/dracut/hooks/pre-udev/00-tuned-pre-udev.sh

    # Set CPU affinity according to NON_ISOLATED_CPUS
    get_cpu_affinity
    echo "[Manager]" >> ${INITRD_GENERATION_DIR}/etc/systemd/system.conf
    echo "CPUAffinity=$cpu_affinity" >> ${INITRD_GENERATION_DIR}/etc/systemd/system.conf

    # Set IRQ banned cpu according to NON_ISOLATED_CPUS
    get_cpu_mask 0
    echo "IRQBALANCE_BANNED_CPUS=$non_iso_cpumask" >> ${INITRD_GENERATION_DIR}/etc/sysconfig/irqbalance
    
    find ${INITRD_GENERATION_DIR} | cpio -co >${INITRD_NEW_IMAGE}

    # Get current ostree config file according to the latest version
    current_ver=1
    entry_file=$(ls -td /boot/loader/entries/* | head -1)
    while read -r line ; do
        ver=`awk '/version/ {print $2}' $line`
        if [ "$ver" -gt "$current_ver" ]; then
           current_ver=$ver
           entry_file=$line
        fi
    done <<<$(egrep $(uname -r) -lr /boot/loader/entries/)

    sed -i "s^initrd .*\$^& ${RHCOS_OSTREE_BOOTLOADER_PATH}iso_initrd.img^" $entry_file

    #TODO - once RHCOS image contains the initrd content we can set parameters with rpm-ostree:
    #rpm-ostree initramfs --enable --arg=-I --arg=/etc/systemd/system.conf
    #rpm-ostree initramfs --enable --arg=-I --arg=/etc/sysconfig/irqbalance
    
    systemctl reboot
fi