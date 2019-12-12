#!/usr/bin/env bash

set -euo pipefail

TEMPLATE=${1:-}

source $(dirname "$0")/../hack/common.sh

if [[ -z "${TEMPLATE}" ]]; then
    rm -rf ${PERFORMANCE_MANIFESTS_GENERATED_DIR}
    mkdir -p ${PERFORMANCE_MANIFESTS_GENERATED_DIR}
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

    export MICROCODE_URL
    export RT_REPO_URL
    export RT_KERNEL_BASE64="$(base64 -w 0 ${PERFORMANCE_ASSETS_DIR}/rt-kernel-patch.sh)"

    if [[ -n "${TEMPLATE}" ]]; then
        envsubst < ${PERFORMANCE_TEMPLATES_DIR}/${TEMPLATE}.in
    else
        for template in $(ls ${PERFORMANCE_TEMPLATES_DIR}); do
            name="$(basename ${template} .in)"
            envsubst < ${PERFORMANCE_TEMPLATES_DIR}/${template} > ${PERFORMANCE_MANIFESTS_GENERATED_DIR}/${name}
        done
    fi
)
