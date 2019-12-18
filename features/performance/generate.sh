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
        echo "You need to provide ISOLATED_CPUS as an env variable"
        exit 1
    fi

    if  [[ -z "${RESERVED_CPUS}" ]]; then
        echo "You need to provide RESERVED_CPUS as an env variable"
        exit 1
    fi

    if  [[ -z "${NON_ISOLATED_CPUS}" ]]; then
        echo "You need to provide NON_ISOLATED_CPUS as an env variable"
        exit 1
    fi

    if  [[ -z "${HUGEPAGES_NUMBER}" ]]; then
        echo "You need to provide HUGEPAGES_NUMBER as an env variable"
        exit 1
    fi

    export RT_REPO_URL
    export RT_KERNEL_BASE64="$(base64 -w 0 ${PERFORMANCE_ASSETS_DIR}/rt-kernel-patch.sh)"
    export PRE_BOOT_BASE64="$(base64 -w 0 ${PERFORMANCE_ASSETS_DIR}/pre-boot-tuning.sh)"

    if [[ -n "${TEMPLATE}" ]]; then
        envsubst < ${PERFORMANCE_TEMPLATES_DIR}/${TEMPLATE}.in
    else
        for template in $(ls ${PERFORMANCE_TEMPLATES_DIR}); do
            name="$(basename ${template} .in)"
            envsubst < ${PERFORMANCE_TEMPLATES_DIR}/${template} > ${PERFORMANCE_MANIFESTS_GENERATED_DIR}/${name}
        done
    fi
)
