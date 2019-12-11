#!/usr/bin/env bash
set -uo pipefail
BASEDIR="$(dirname "$0")"

# shellcheck disable=SC1091,SC1090
. "${BASEDIR}/../lib/functions.sh"

[ -f "${BASEDIR}/myvars" ] || die "A 'myvars' file needs to be created, see the README"

# shellcheck disable=SC1091,SC1090
. "${BASEDIR}/myvars"

# random_master is a function that returns a random master name
# so, we label one of the masters as 'grandmaster' randomly
oc label node "$(random_master)" ptp/grandmaster=''
# Label the other nodes as 'slaves'
for node in $(oc get nodes --selector='!ptp/grandmaster' -o name) ; do
  oc label "$node" ptp/slave=''
done

for filename in ${BASEDIR}/ptpconfig-*.yaml; do
  envsubst < "${filename}" | oc apply -f - > /dev/null || die "Error creating ${1}"
done
