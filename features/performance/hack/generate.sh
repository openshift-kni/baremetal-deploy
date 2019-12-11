#!/usr/bin/env bash

set -euo pipefail

source $(dirname "$0")/common.sh

rm -rf ${MANIFESTS_GENERATED_DIR}
mkdir -p ${MANIFESTS_GENERATED_DIR}

(
    if [[ -z "${ISOLATED_CPUS}" ]]; then
        echo "You should provide ISOLATED_CPUS env variable"
        exit 1
    fi

    if  [[ -z "${RESERVED_CPUS}" ]]; then
        echo "You should provide RESERVED_CPUS env variable"
        exit 1
    fi

    if  [[ -z "${OS_RESERVED_CPUS}" ]]; then
        echo "You should provide OS_RESERVED_CPUS env variable"
        exit 1
    fi

    export RT_KERNEL_BASE64="$(base64 -w 0 ${ASSETS_DIR}/rt-kernel-patch.sh)"
    export PRE_BOOT_BASE64="$(base64 -w 0 ${ASSETS_DIR}/pre-boot-tuning.sh)"

    export MICROCODE_URL=${MICROCODE_URL:-http://file.rdu.redhat.com/~walters/microcode_ctl-20190918-3.rhcos.1.el8.x86_64.rpm}
    export RT_REPO_URL=${RT_REPO_URL:-http://download-node-02.eng.bos.redhat.com/rhel-8/nightly/RHEL-8/latest-RHEL-8.1.1/compose/RT/x86_64/os}
    
    for template in $(ls ${TEMPLATES_DIR}); do
        name="$(basename ${template} .in)"
        envsubst < ${TEMPLATES_DIR}/${template} > ${MANIFESTS_GENERATED_DIR}/${name}
    done
)
