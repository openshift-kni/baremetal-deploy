#!/bin/bash

set -euo pipefail

if [[ ! -f /etc/yum.repos.d/rhel.repo ]]
then
    # Enable yum repo
    mkdir -p /etc/yum.repos.d
    cat > /etc/yum.repos.d/rhel.repo <<EOF
[baseos]
baseurl=${BASEOS_REPO_URL}
gpgcheck=0

[appstream]
baseurl=${APPSTREAM_REPO_URL}
gpgcheck=0

[rt]
baseurl=${RT_REPO_URL}
gpgcheck=0
EOF
fi

# Install patched microcode
# see https://src.osci.redhat.com/rpms/microcode_ctl/pull-request/9
replacedPackages=$(rpm-ostree status --json | jq '.deployments[] | select(.booted == true) | ."layered-commit-meta"."rpmostree.replaced-base-packages"')
if [[ $replacedPackages =~ "microcode_ctl" ]]
then
    echo "microcode_ctl patch already installed"
else
    rpm-ostree override replace ${MICROCODE_URL}
fi

# Swap to RT kernel
kernel=$(uname -a)
if [[ $kernel =~ "PREEMPT RT" ]]
then
    # TODO: check for RT kernel updates
    echo "RT kernel already installed"
else
    rpm-ostree override remove kernel{,-core,-modules,-modules-extra} --install kernel-rt --install kernel-rt-core --install kernel-rt-modules --install kernel-rt-modules-extra
    systemctl reboot
fi
