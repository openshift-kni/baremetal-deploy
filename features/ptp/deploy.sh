#!/usr/bin/env bash
set -uo pipefail
BASEDIR="$(dirname "$0")"

PTP_DEPLOYMENT=${BASEDIR}/deploy

# shellcheck disable=SC1091,SC1090
. "${BASEDIR}/../lib/functions.sh"

[ -f "${BASEDIR}/myvars" ] || die "A 'myvars' file needs to be created, see the README"

# shellcheck disable=SC1091,SC1090
. "${BASEDIR}/myvars"

deploy(){
  pushd "${PTP_DEPLOYMENT}" || die "pushd to ${PTP_DEPLOYMENT} failed"
  oc apply -f 01_namespace.yaml
  oc apply -f 02_operator_group.yaml

  export channel=`oc get packagemanifest ptp-operator -n openshift-marketplace -o jsonpath='{.status.channels[].name}'`

  if [[ ${channel} == "" ]]; then
    die "failed to find ptp-operator channel"
  fi

  envsubst < 03_subscription.yaml | oc apply -f -

  while [[ `oc -n openshift-ptp get csv --no-headers | wc -l` != "1" ]]; do
      sleep 2
  done

  until oc -n openshift-ptp get csv -o yaml | sed "s,image-registry.openshift-image-registry.svc:5000/openshift/ose-ptp-operator@.*,${ptp_operator}:${channel},g" | sed "s,image-registry.openshift-image-registry.svc:5000/openshift/ose-ptp@.*,${ptp_daemon}:${channel},g" | oc apply -f -
  do
    echo "failed to update csv images"
  done

  until oc -n openshift-ptp get deploy -o yaml | sed "s,image-registry.openshift-image-registry.svc:5000/openshift/ose-ptp-operator@.*,${ptp_operator}:${channel},g" | sed "s,image-registry.openshift-image-registry.svc:5000/openshift/ose-ptp@.*,${ptp_daemon}:${channel},g" | oc apply -f -
  do
    echo "failed to update deployment images"
  done

  while [[ `oc -n openshift-ptp get csv --no-headers | grep Succeeded | wc -l` != "1" ]]; do
      sleep 2
  done

  popd || die "popd failed"
}

ocp_sanity_check
deploy
