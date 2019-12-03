#!/bin/bash

set -euo pipefail

# TODO: improve check for applied configuration
if grep -q "CPUAffinity" "/etc/systemd/system.conf"; then
    echo "Pre boot tuning configuration already applied"
    # Move kernel rcuo* threads to the housekeeping cpus
else
    echo "[Manager]" >> /etc/systemd/system.conf
    echo "CPUAffinity=0 2" >> /etc/systemd/system.conf
    echo "IRQBALANCE_BANNED_CPUS=FFFFFFFA" >> /etc/sysconfig/irqbalance

    rpm-ostree initramfs --enable --arg=-I --arg=/etc/systemd/system.conf
    rpm-ostree initramfs --enable --arg=-I --arg=/etc/sysconfig/irqbalance
    
    systemctl reboot
fi
