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

    for template in $(ls ${TEMPLATES_DIR}); do
        name="$(basename ${template} .in)"
        envsubst < ${TEMPLATES_DIR}/${template} > ${MANIFESTS_GENERATED_DIR}/${name}
    done
)
