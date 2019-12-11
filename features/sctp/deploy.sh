#!/usr/bin/env bash

set -uo pipefail

BASEDIR="$(dirname "$0")"
MCPOOL="${MACHINE_CONFIG_POOL:-worker}"
SCTP_MODULE_MANIFEST="${BASEDIR}/sctp_module_mc.yaml"


. "${BASEDIR}/../lib/functions.sh"

unblacklist_module() {
    info "unblacklisting module..."
    oc create -f "${SCTP_MODULE_MANIFEST}" > /dev/null || die "unblacklisting the sctp module"
}

unblacklist_module
info "waiting for updating..."
until oc wait mcp/$MCPOOL --for condition=updating --timeout 600s ; do sleep 1 ; done
info "waiting for updated..."
wait_mcp $MCPOOL
