#!/usr/bin/env bash
set -uo pipefail
BASEDIR="$(dirname "$0")"

REPO_PATH=${HOME}/git/
SRIOV_OPERATOR_DIR=${REPO_PATH}/sriov-network-operator

# shellcheck disable=SC1091,SC1090
. "${BASEDIR}/../lib/functions.sh"

prereq(){
  for command in git jq skopeo make; do
    if [ ! -x "$(command -v ${command})" ]; then
      die "Could not find the executable ${command} in the current PATH"
    fi
  done
}

deploy(){
  pushd "${SRIOV_OPERATOR_DIR}" || die "pushd to ${SRIOV_OPERATOR_DIR} failed"
  make deploy-setup
  popd || die "popd failed"
}

# This is needed for multus to create a dhcp-daemon daemonset in order for ipam/dhcp to work
add_dummy_dhcp(){
  oc patch networks.operator.openshift.io cluster --type='merge' \
    -p='{"spec":{"additionalNetworks":[{"name":"dummy-dhcp-network","simpleMacvlanConfig":{"ipamConfig":{"type":"dhcp"},"master":"eth0","mode":"bridge","mtu":1500},"type":"SimpleMacvlan"}]}}' \
    || die "patch failed"
}

configure(){
  export nic="${nic:-eno1}"
  export numvfs="${numvfs:-5}"
  export pciid="${pciid:-0000:01:00.0}"
  export operatornamespace="${operatornamespace:-openshift-sriov-network-operator}"
  export targetnamespace="${targetnamespace:-sriov-testing}"
  envsubst < policy.yml  | oc create -f - > /dev/null || die "deploying policy"
  envsubst < network.yml | oc create -f - > /dev/null || die "deploying network"
}

ocp_sanity_check
prereq
sync_repo_and_patch sriov-network-operator https://github.com/openshift/sriov-network-operator
deploy
add_dummy_dhcp
configure
