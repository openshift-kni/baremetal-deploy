#!/usr/bin/env bash

set -uo pipefail

BASEDIR="$(dirname "$0")"
MCPOOL="${MACHINE_CONFIG_POOL:-worker}"
KUBELET_CONFIG_MANIFEST="${BASEDIR}/cpumanager-kubeletconfig.yml"
DEPLOYMENT_WITH_REQUESTS="${BASEDIR}/pause-with-requests-deployment.yml"
export CPUMANAGER_NAMESPACE="${MY_CPUMANAGER_NAMESPACE:-cpumanager-test}"

# shellcheck disable=SC1091,SC1090
. "${BASEDIR}/../lib/functions.sh"

label_mcpool() {
    mcpools=$(oc get machineconfigpool -A --no-headers -l custom-kubelet=cpumanager-enabled 2>/dev/null | wc -l)

    if [ "${mcpools}" -eq 0 ]; then
        info "applying label cpumanager=true to ${node}..."
        oc label machineconfigpool "${MCPOOL}" custom-kubelet=cpumanager-enabled > /dev/null || die "labelling the machineconfigpool ${MCPOOL}"
    else
        warn "MachineConfigPool ${MCPOOL} is already labelled, skipping"
    fi
}

label_nodes() {
    for node in $(oc get nodes --selector='!node-role.kubernetes.io/master' -o name); do
      info "applying label cpumanager=true to ${node}..."
      oc label "${node}" cpumanager=true > /dev/null
    done
}

apply_custom_kubeletconfig() {
    info "applying the custom kubelet configuration..."
    oc create -f "${KUBELET_CONFIG_MANIFEST}" > /dev/null || die "applying the custom kubelet configuration"
}

deploy_workload() {
    info "deploying workload..."
    oc create ns "${CPUMANAGER_NAMESPACE}" > /dev/null 2>&1 || true
    envsubst < "${DEPLOYMENT_WITH_REQUESTS}" | oc create -f - > /dev/null || die "deploying workload"
    while ! oc get pods -n "${CPUMANAGER_NAMESPACE}" -l app=cpumanager-test > /dev/null 2>&1; do
        sleep 5s
    done
    info "waiting for the workload to be ready ..."
    oc wait pods --for condition=ready -l app=cpumanager-test -n "${CPUMANAGER_NAMESPACE}" --timeout=1200s > /dev/null || die "waiting for the workload"
    info "workload has been deployed to ${CPUMANAGER_NAMESPACE}..."
}


sanity_check() {
    worker_nodes=$( oc get nodes --selector='!node-role.kubernetes.io/master' -o name 2>/dev/null | wc -l)
    if [ "${worker_nodes}" -eq 0 ]; then
        die "could not find any worker node to be labelled"
    fi

    if [ ! -f "${KUBELET_CONFIG_MANIFEST}" ]; then
        die "could not find ${KUBELET_CONFIG_MANIFEST}"
    fi

    if [ ! -f "${DEPLOYMENT_WITH_REQUESTS}" ]; then
        die "could not find ${DEPLOYMENT_WITH_REQUESTS}"
    fi
}

ocp_sanity_check
sanity_check
label_nodes
label_mcpool
wait_mcp $MCPOOL
