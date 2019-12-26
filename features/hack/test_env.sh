#!/usr/bin/env bash

# Performance
export ISOLATED_CPUS=1
export RESERVED_CPUS=0
export NON_ISOLATED_CPUS=0
export HUGEPAGES_NUMBER=1

# PTP
export ptp_operator="quay.io/openshift/origin-ptp-operator"
export ptp_daemon="quay.io/openshift/origin-ptp"
export nic="eno2"
export subscription_source="opsrctest"

NON_MASTER_NODE=$(oc get nodes --no-headers -o name -l '!node-role.kubernetes.io/master' | head -n1)
oc label --overwrite ${NON_MASTER_NODE} node-role.kubernetes.io/worker-rt=""
