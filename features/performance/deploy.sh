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
until oc label --overwrite machineconfigpool/worker worker=; do
    sleep 5
done

# pause all machine config pools
until mcps=$(oc get machineconfigpool --no-headers -o name); do
    sleep 5
done

for mcp in ${mcps}; do
    until oc patch --type=merge --patch='{"spec":{"paused":true}}' ${mcp}; do
        sleep 5
    done
done

# apply performance manifests
until oc apply -R -f ${PERFORMANCE_MANIFESTS_GENERATED_DIR}; do
    sleep 5
done

# unpause all machine config pools
for mcp in ${mcps}; do
    until oc patch --type=merge --patch='{"spec":{"paused":false}}' ${mcp}; do
        sleep 5
    done
done

# wait for the configuration update
# NOTE: be sure that you have node with the worker-rt role, otherwise it will stuck for a long time
# NOTE: we are waiting only for worker-rt machineconfigpool,
# but all other machineconfigpools will also run the update, because of the feature gate update
timeout=1800

count=0
until oc wait machineconfigpools worker-rt --for condition=Updating --timeout=60s; do
    count=$((count + 60))
    if [[ ${count} -ge ${timeout} ]]; then
        break
    fi
done


count=0
until oc wait machineconfigpools worker-rt --for condition=Updated --timeout=60s; do
    count=$((count + 60))
    if [[ ${count} -ge ${timeout} ]]; then
        break
    fi
done
