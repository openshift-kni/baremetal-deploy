#!/usr/bin/env bash
set -uo pipefail
BASEDIR="$(dirname "$0")"

REPO_PATH=${HOME}/git/
PTP_OPERATOR_DIR=${REPO_PATH}/ptp-operator

# shellcheck disable=SC1091,SC1090
. "${BASEDIR}/../lib/functions.sh"

prereq(){
  for command in git jq skopeo make; do
    if [ ! -x "$(command -v ${command})" ]; then
      die "Could not find the executable ${command} in the current PATH"
    fi
  done
}

deploy(){
  pushd "${PTP_OPERATOR_DIR}" || die "pushd to ${PTP_OPERATOR_DIR} failed"
  make deploy-setup
  popd || die "popd failed"
  oc apply -f "${BASEDIR}"/ptpconfig-grandmaster.yaml
  oc apply -f "${BASEDIR}"/ptpconfig-slave.yaml
}

label_nodes(){
  # random_master is a function that returns a random master name
  # so, we label one of the masters as 'grandmaster' randomly
  oc label node "$(random_master)" ptp/grandmaster=''
  # Label the other nodes as 'slaves'
  for node in $(oc get nodes --selector='!ptp/grandmaster' -o name) ; do 
    oc label "$node" ptp/slave=''
  done
}

ocp_sanity_check
prereq
sync_repo_and_patch ptp-operator https://github.com/openshift/ptp-operator.git asdf 19
label_nodes
deploy
