#!/usr/bin/env bash

# Performance
export ISOLATED_CPUS=1
export RESERVED_CPUS=0
export NON_ISOLATED_CPUS=0

WORKER_NODE=$(oc get nodes --no-headers -o name -l node-role.kubernetes.io/worker="" | head -n1)
oc label $WORKER_NODE node-role.kubernetes.io/worker-rt=""
