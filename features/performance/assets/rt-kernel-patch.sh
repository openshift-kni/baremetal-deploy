#!/bin/bash

set -euo pipefail

REPO_DIR="/etc/yum.repos.d"
RT_REPO="${REPO_DIR}/rt-kernel.repo"

# Enable yum repo
if [[ -f $RT_REPO ]]
then
  # The env var might have been changed, so always create new rt repo
  rm $RT_REPO
fi

mkdir -p $REPO_DIR
cat > $RT_REPO <<EOF
[rt]
baseurl=${RT_REPO_URL}
gpgcheck=0
EOF

# update cache
rpm-ostree refresh-md -f

# Install patched microcode
# see https://src.osci.redhat.com/rpms/microcode_ctl/pull-request/9
replacedPackages=$(rpm-ostree status --json | jq '.deployments[] | select(.booted == true) | ."layered-commit-meta"."rpmostree.replaced-base-packages"')
if [[ $replacedPackages =~ "microcode_ctl" ]]
then
    echo "microcode_ctl patch already installed"
else
    echo "Installing microcode_ctl patch"
    rpm-ostree override replace ${MICROCODE_URL}
fi

# Swap to RT kernel
kernel=$(uname -a)
if [[ $kernel =~ "PREEMPT RT" ]]
then
    echo "RT kernel already installed, checking for updates"
    rpm-ostree upgrade --unchanged-exit-77
    if [[ $? -eq 77 ]]
    then
      echo "No update available, nothing to do"
    else
      echo "RT kernel updated, rebooting"
      systemctl reboot
    fi
else
    echo "Installing RT kernel"
    rpm-ostree override remove kernel{,-core,-modules,-modules-extra} --install kernel-rt-core --install kernel-rt-modules --install kernel-rt-modules-extra
    echo "Rebooting"
    systemctl reboot
fi
