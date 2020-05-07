#!/bin/bash

set -euo pipefail

REPO_DIR="/etc/yum.repos.d"
RT_REPO="${REPO_DIR}/rt-kernel.repo"

# Enable yum repo
if [[ -f $RT_REPO ]]; then
    # The env var might have been changed, so always create new rt repo
    rm $RT_REPO
fi

mkdir -p $REPO_DIR
cat >$RT_REPO <<EOF
[rt]
baseurl=${RT_REPO_URL}
gpgcheck=0
EOF

# update cache
rpm-ostree refresh-md -f

exit_handler() {
    exit_code=$?
    if [[ ${exit_code} -eq 77 ]]; then
        echo "No update available, nothing to do"
        exit 0
    elif [[ ${exit_code} -eq 100 ]]; then
        echo "Initiate reboot, touch /var/reboot"
        touch /var/reboot
        exit 0
    else
        exit ${exit_code}
    fi
}

trap exit_handler EXIT

# Swap to RT kernel
kernel=$(uname -a)
if [[ $kernel =~ "PREEMPT RT" ]]; then
    echo "RT kernel already installed, checking for updates"
    # if no upgrade is available the script will exit with code 77, and we will trap it
    rpm-ostree upgrade --unchanged-exit-77
    echo "RT kernel updated"
    exit 100
else
    echo "Installing RT kernel"
    rpm-ostree override remove kernel{,-core,-modules,-modules-extra} --install kernel-rt-core --install kernel-rt-modules --install kernel-rt-modules-extra
    echo "RT kernel installed"
    exit 100
fi
