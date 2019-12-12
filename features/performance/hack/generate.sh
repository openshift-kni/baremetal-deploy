#!/usr/bin/env bash

set -euo pipefail

TEMPLATE=${1:-}

source $(dirname "$0")/common.sh

if [[ -z "${TEMPLATE}" ]]; then
    rm -rf ${MANIFESTS_GENERATED_DIR}
    mkdir -p ${MANIFESTS_GENERATED_DIR}
fi

(
    if [[ -z "${ISOLATED_CPUS}" ]]; then
        echo "You should provide ISOLATED_CPUS env variable"
        exit 1
    fi

    if  [[ -z "${RESERVED_CPUS}" ]]; then
        echo "You should provide RESERVED_CPUS env variable"
        exit 1
    fi

    export RT_KERNEL_BASE64="$(base64 -w 0 ${ASSETS_DIR}/rt-kernel-patch.sh)"
    export MICROCODE_URL=${MICROCODE_URL:-http://file.rdu.redhat.com/~walters/microcode_ctl-20190918-3.rhcos.1.el8.x86_64.rpm}
    export RT_REPO_URL=${RT_REPO_URL:-http://download-node-02.eng.bos.redhat.com/rhel-8/nightly/RHEL-8/latest-RHEL-8.1.1/compose/RT/x86_64/os}

    if [[ -n "${TEMPLATE}" ]]; then
        envsubst < ${TEMPLATES_DIR}/${TEMPLATE}.in
    else
        for template in $(ls ${TEMPLATES_DIR}); do
            name="$(basename ${template} .in)"
            envsubst < ${TEMPLATES_DIR}/${template} > ${MANIFESTS_GENERATED_DIR}/${name}
        done
    fi
)
