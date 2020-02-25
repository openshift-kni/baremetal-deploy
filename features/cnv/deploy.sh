#!/usr/bin/env bash
set -uo pipefail
BASEDIR="$(dirname "$0")"

# shellcheck disable=SC1091,SC1090
. "${BASEDIR}/../lib/functions.sh"

[ -f "${BASEDIR}/myvars" ] || die "A 'myvars' file needs to be created, see the README"

# shellcheck disable=SC1091,SC1090
. "${BASEDIR}/myvars"

# Seconds to wait until the operator is deployed with oc wait
TIMEOUT=300

apply_manifest(){
  FILE=$(eval "echo ${BASEDIR}/*-cnv-${1}.yaml")
  info "Applying ${FILE}"
  envsubst < "${FILE}" | oc apply -f - > /dev/null || die "Error creating ${1}"
}

deploy(){
  for object in namespace operatorgroup subscription; do
    apply_manifest ${object}
  done
}

hcocr(){
  apply_manifest hcocr
}

wait_for_hcoready(){
  info "Waiting for the CNV operator to be ready..."
  while ! oc wait --for condition=Ready pods -l name=hyperconverged-cluster-operator  -n "${operatornamespace}"  --timeout="${TIMEOUT}"s; do sleep 10 ; done
}


ocp_sanity_check
deploy
wait_for_hcoready
hcocr
wait_for_hcoready
