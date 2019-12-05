#!/usr/bin/env bash
set -uo pipefail
BASEDIR="$(dirname "$0")"

# shellcheck disable=SC1091,SC1090
. "${BASEDIR}/../lib/functions.sh"

[ -f "${BASEDIR}/myvars" ] || die "A 'myvars' file needs to be created, see the README"

# shellcheck disable=SC1091,SC1090
. "${BASEDIR}/myvars"

# Get the number of 'non workers' (workers, workers-rt, etc.)
numworkers=$(oc get nodes --selector='!node-role.kubernetes.io/master' --no-headers | wc -l)
export numworkers

for object in testing-namespace testing-deployment; do
  FILE=$(eval "echo ${BASEDIR}/*-sriov-${object}.yaml")
  info "Applying ${FILE}"
  # This will deploy a pod on each node
  envsubst < "${FILE}" | oc apply -f - > /dev/null || die "Error creating ${object}"
done
