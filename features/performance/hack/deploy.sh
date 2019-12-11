#!/usr/bin/env bash

set -euo pipefail

source $(dirname "$0")/common.sh

# label worker nodes
workers=$(oc get node --no-headers -l node-role.kubernetes.io/worker -o'custom-columns=name:.metadata.name')
for worker in ${workers}; do
    oc label --overwrite node ${worker} node-role.kubernetes.io/worker-rt=
done

# pause all machine config pools
mcps=$(oc get machineconfigpool --no-headers -o'custom-columns=name:.metadata.name')
for mcp in ${mcps}; do
    oc patch --type=merge --patch='{"spec":{"paused":true}}' machineconfigpool/${mcp}
done

# apply manifests
oc apply -Rf ${MANIFESTS_GENERATED_DIR}

# unpause all machine config pools
for mcp in ${mcps}; do
    oc patch --type=merge --patch='{"spec":{"paused":false}}' machineconfigpool/${mcp}
done

# wait for the configuration update
oc -n openshift-machine-config-operator wait machineconfigpools worker --for condition=Updating --timeout=1800s
oc -n openshift-machine-config-operator wait machineconfigpools worker --for condition=Updated --timeout=1800s
