#!/bin/bash

function local_env() {
    BASEDIR="$(dirname "$0")"
    source "${BASEDIR}/../lib/functions.sh"
}

function validate_function_by_worker() {
    WORKERS=("$(oc get node -l node-role.kubernetes.io/worker -o jsonpath="{range .items[*]}{.metadata.name} ")")
    if [ -z "${WORKERS}" ];then
        die "===> No workers detected, exiting..."
    fi

    for worker in "${WORKERS[@]}"
    do
        CHECKS=( 
            "SCTP_KERNEL_MOD:$(oc debug node/${worker} -- chroot /host grep sctp /etc/modules-load.d/sctp-load.conf 2>/dev/null | wc -l)"
            # This sctp word must not be there, because of that I call reverse function.
            "SCTP_BLACKLIST_DISABLED:$(oc debug node/${worker} -- chroot /host grep -c sctp /etc/modules-load.d/sctp-blacklist.conf 2>/dev/null | reverse $?)"
        )

        validate_function
    done
}

CHECKS=( 
    # Check https://github.com/openshift-kni/baremetal-deploy/blob/master/features/sctp/sctp_module_mc.yaml if test fails
    "SCTP_MC:$(oc get mc --no-headers load-sctp-module 2>/dev/null | wc -l)"
)

declare -a test_results test_ok test_nok test_failed
local_env
validate_function
validate_function_by_worker
resume "SCTP"
