#!/bin/bash

set -euo pipefail

get_reserved_cores() {
    cores=()
    while read part; do
        if [[ $part =~ - ]]; then
            cores+=($(seq ${part/-/ }))
        else
            cores+=($part)
        fi
    done < <( echo $reserved_cpus | tr ',' '\n' )
}

# $1 - 0 for irq balance banned cpus masking , 1 for non isolated cpus masking
get_cpu_mask() {
    if [ "$1" = "1" ]; then
        mask=( 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 )
    else
        mask=( 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 ) 
    fi    
    get_reserved_cores()
    for core in ${cores[*]}; do
        echo $core
        mask[$core]=$1
    done
    cpumaskBinary=`echo ${mask[@]}| rev`
    cpumaskBinary=${cpumaskBinary//[[:space:]]/}
    non_iso_cpumask=`printf '%x\n' "$((2#$cpumaskBinary))"`
}

get_cpu_affinity() {
    cpu_affinity=""
    get_reserved_cores()
    for core in ${cores[*]}; do
        cpu_affinity+=" $core"
    done
}

# TODO: improve check for applied configuration
if grep -q "CPUAffinity" "/etc/systemd/system.conf"; then
    echo "Pre boot tuning configuration already applied"
    echo "Setting kernel rcuo* threads to the housekeeping cpus"
    get_cpu_mask() "0"
    pgrep rcuo* | while read line; do taskset -p non_iso_cpumask $line; done
else
    if sysctl -a | grep -q reserved_cpus; then
        reserved_cpus="$(sysctl -q -e -n reserved_cpus)"
    else
        echo "Could not retrive reserved_cpus from kargs"
        exit 1    
    fi

    mkdir initrd
    cd initrd
    cpio -idumv <../iso_initrd.img

    # Set CPU affinity according to reserved_cpus
    echo "CPUAffinity=$cpu_affinity" >> etc/systemd/system.conf

    # Set IRQ banned cpu according to reserved_cpus
    get_cpu_mask() "0"
    echo "IRQBALANCE_BANNED_CPUS=$non_iso_cpumask" >> etc/sysconfig/irqbalance
    
    find . | cpio -co >../iso_initrd.img
    cd ..
    RHCOS_OSTREE_PATH=$(ls -td /boot/ostree/*/ | head -1)
    cp iso_initrd.img $RHCOS_OSTREE_PATH
    RHCOS_OSTREE_PATH=${RHCOS_OSTREE_PATH#"/boot"}
    sed -i "s^initrd .*\$^& ${RHCOS_OSTREE_PATH}iso_initrd.img^" /boot/loader/entries/ostree-2-rhcos.conf2

    #TODO - once RHCOS image contains the initrd content we can set parameters with rpm-ostree:
    #rpm-ostree initramfs --enable --arg=-I --arg=/etc/systemd/system.conf
    #rpm-ostree initramfs --enable --arg=-I --arg=/etc/sysconfig/irqbalance
    
    systemctl reboot
fi
