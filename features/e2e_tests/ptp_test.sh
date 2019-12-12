#!/bin/bash

function local_env() {
    BASEDIR="$(dirname "$0")"
    source "${BASEDIR}/../lib/functions.sh"
}

CHECKS=( 
    "PTP_CRDS:$(oc get crd | grep -c ptp.openshift.io)"
    "PTP_OPERATOR_INSTANCE:$(oc get ptpoperatorconfigs.ptp.openshift.io --no-headers --all-namespaces 2>/dev/null | wc -l)"
    "PTP_DEPLOYMENT:$(oc get deployment.apps/ptp-operator -n openshift-ptp -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null | grep -c True)"
    "PTP_DS:$(oc get ds linuxptp-daemon -n openshift-ptp --no-headers 2>/dev/null | grep -c linuxptp-daemon)"
    "PTP_NODE_SLAVE_LABELED:$(oc get nodes -l ptp/slave --no-headers 2>/dev/null | wc -l)"
)

declare -a test_results test_ok test_nok test_failed
local_env
validate_function
resume "PTP"
