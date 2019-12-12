#!/bin/bash

function local_env() {
    BASEDIR="$(dirname "$0")"
    source "${BASEDIR}/../lib/functions.sh"
}


function validate_function_by_worker() {
    WORKERS=("$(oc get node -l node-role.kubernetes.io/worker -o jsonpath="{range .items[*]}{.metadata.name} ")")
    if [ -z "${WORKERS}" ];then
        die "No workers detected, exiting..."
    fi

    for worker in "${WORKERS[@]}"
    do
        CHECKS=( 
            "CPU_MAN_FEATUREGATE:$(oc debug node/${worker} -- chroot /host cat /etc/kubernetes/kubelet.conf 2>/dev/null | grep -i cpumanager | wc -l)"
            "CPU_MAN_LABEL:$(oc get nodes/${worker} -o jsonpath='{.metadata.labels}' 2>/dev/null | grep -c cpumanager)"
        )

        validate_function
    done
}

CHECKS=( 
    "CPU_MAN_MCP_LABEL:$(oc get machineconfigpool worker-rt -o jsonpath='{.metadata.labels.custom-kubelet}' 2>/dev/null | grep cpumanager-enabled | wc -l)"
    "CPU_MAN_TEST_PODS:$(oc get pods -l app=cpumanager-test -n cpumanager-test --no-headers 2>/dev/null | wc -l)"
)


declare -a test_results test_ok test_nok test_failed
local_env
validate_function
validate_function_by_worker
resume "CPU-Manager"
