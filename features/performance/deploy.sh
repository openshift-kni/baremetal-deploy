#!/usr/bin/env bash

set -euo pipefail

source $(dirname "$0")/../hack/common.sh

# pause all machine config pools
mcps=$(oc get machineconfigpool --no-headers -o name)
for mcp in ${mcps}; do
    oc patch --type=merge --patch='{"spec":{"paused":true}}' ${mcp}
done

# apply performance manifests
oc apply -R -f ${PERFORMANCE_MANIFESTS_GENERATED_DIR}

# unpause all machine config pools
for mcp in ${mcps}; do
    oc patch --type=merge --patch='{"spec":{"paused":false}}' ${mcp}
done

# wait for the configuration update
oc -n openshift-machine-config-operator wait machineconfigpools worker-rt --for condition=Updating --timeout=1800s
oc -n openshift-machine-config-operator wait machineconfigpools worker-rt --for condition=Updated --timeout=1800s
