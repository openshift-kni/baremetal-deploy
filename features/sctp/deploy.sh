#!/usr/bin/env bash

set -euo pipefail

source $(dirname "$0")/../hack/common.sh
source ${LIB_DIR}/functions.sh

MCPOOL="${MACHINE_CONFIG_POOL:-worker}"
SCTP_MODULE_MANIFEST="${SCTP_DIR}/sctp_module_mc.yaml"

unblacklist_module() {
    info "unblacklisting module..."
    oc apply -f "${SCTP_MODULE_MANIFEST}" > /dev/null || die "unblacklisting the sctp module"
}

unblacklist_module
info "waiting for updating..."
until oc wait mcp/$MCPOOL --for condition=updating --timeout 600s ; do sleep 1 ; done
info "waiting for updated..."
wait_mcp $MCPOOL
