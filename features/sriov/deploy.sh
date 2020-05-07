#!/usr/bin/env bash
set -uo pipefail
BASEDIR="$(dirname "$0")"

# shellcheck disable=SC1091,SC1090
. "${BASEDIR}/../lib/functions.sh"

[ -f "${BASEDIR}/myvars" ] || die "A 'myvars' file needs to be created, see the README"

# shellcheck disable=SC1091,SC1090
. "${BASEDIR}/myvars"

# Seconds to wait until the operator is deployed with oc wait
TIMEOUT=300

# shellcheck disable=SC2154
# This is needed to split the label=value into label: value required for yaml files...
export NODESELECTOR="${label%=*}: \"${label##*=}\""

apply_manifest() {
    FILE=$(eval "echo ${BASEDIR}/*-sriov-${1}.yaml")
    info "Applying ${FILE}"
    envsubst <"${FILE}" | oc apply -f - >/dev/null || die "Error creating ${1}"
}

deploy() {
    for object in namespace operatorgroup subscription; do
        apply_manifest ${object}
    done
}

# This is needed for multus to create a dhcp-daemon daemonset in order for ipam/dhcp to work
add_dummy_dhcp() {
    # First verify if it is there just in case
    if oc get networks.operator.openshift.io/cluster -o jsonpath="{.spec.additionalNetworks[*].name}" | grep -q "dummy-dhcp-network"; then
        info "dummy-dhcp-network already created"
    else
        # If not, patch the cluster network to deploy the dhcp ds
        info "Patching the cluster network to deploy a dhcp daemonset required for ipam/dhcp"
        oc patch networks.operator.openshift.io cluster --type='merge' \
            -p='{"spec":{"additionalNetworks":[{"name":"dummy-dhcp-network","simpleMacvlanConfig":{"ipamConfig":{"type":"dhcp"},"master":"eth0","mode":"bridge","mtu":1500},"type":"SimpleMacvlan"}]}}' ||
            die "patch failed"
    fi
}

# Label the nodes with the sriov capable label
label_nodes() {
    for node in $(oc get nodes --selector='!node-role.kubernetes.io/master' -o name); do
        # shellcheck disable=SC2154
        oc label "${node}" "${label}" --overwrite=true
    done
}

# The daemonset will create some udev rules to prevent unneeded dhcp in the VFs when no attached to pods
daemonset() {
    # shellcheck disable=SC1083,SC2016
    # We only need those two variables
    envsubst '\${nic} \${NODESELECTOR}' <./10-sriov-daemonset.yaml | oc apply -f - >/dev/null || die "Error creating ds"
}

wait_for_ready() {
    # This is to prevent creating the policy before the operator has been deployed like:
    # error: unable to recognize “STDIN”: no matches for kind "SriovNetworkNodePolicy" in version "sriovnetwork.openshift.io/v1"
    info "Waiting for the operator to be ready..."
    # shellcheck disable=SC2154
    while ! oc wait --for condition=ready pods -l name=sriov-network-operator -n "${operatornamespace}" --timeout="${TIMEOUT}"s; do sleep 10; done
}

configure() {
    for object in networknodepolicy network; do
        apply_manifest ${object}
    done
}

ocp_sanity_check
deploy
add_dummy_dhcp
label_nodes
daemonset
wait_for_ready
configure
