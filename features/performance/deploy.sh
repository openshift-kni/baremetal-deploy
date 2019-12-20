#!/usr/bin/env bash

set -euo pipefail

source $(dirname "$0")/../hack/common.sh

# Check if there is at least one worker-rt node
RTNODES=$(oc get node --selector=node-role.kubernetes.io/worker-rt="")
if [ "${RTNODES}" == "" ] ; then
    echo "No node with worker-rt label found"
    exit 1
fi

# W/A for https://bugzilla.redhat.com/show_bug.cgi?id=1777150
# Apply 'worker=""' label only if not set already.
MCPWORKER=$(oc get mcp --selector=worker="" --no-headers)
if [ "${MCPWORKER}" == "" ] ; then
    oc label machineconfigpool/worker worker=
else
    echo "MCP/worker already has label 'worker='"
fi

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
# NOTE: be sure that you have node with the worker-rt role, otherwise it will stuck for a long time
# NOTE: we are waiting only for worker-rt machineconfigpool,
# but all other machineconfigpools will also run the update, because of the feature gate update
oc wait machineconfigpools worker-rt --for condition=Updating --timeout=1800s
oc wait machineconfigpools worker-rt --for condition=Updated --timeout=1800s
