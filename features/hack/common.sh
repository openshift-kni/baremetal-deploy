#!/usr/bin/env bash

FEATURES_DIR="$(
    cd "$(dirname "$BASH_SOURCE[0]")/../"
    echo "$(pwd)"
)"

MCP_DIR="${FEATURES_DIR}/mcp"
LIB_DIR="${FEATURES_DIR}/lib"

PERFORMANCE_DIR="${FEATURES_DIR}/performance"
PERFORMANCE_ASSETS_DIR="${PERFORMANCE_DIR}/assets"
PERFORMANCE_MANIFESTS_DIR="${PERFORMANCE_DIR}/manifests"
PERFORMANCE_MANIFESTS_GENERATED_DIR="${PERFORMANCE_MANIFESTS_DIR}/generated"
PERFORMANCE_TEMPLATES_DIR="${PERFORMANCE_MANIFESTS_DIR}/templates"

SCTP_DIR="${FEATURES_DIR}/sctp"

# CPU configuration parameters
ISOLATED_CPUS=${ISOLATED_CPUS:-}
RESERVED_CPUS=${RESERVED_CPUS:-}

# RT kernel parameters
MICROCODE_URL=${MICROCODE_URL:-http://file.rdu.redhat.com/~walters/microcode_ctl-20190918-3.rhcos.1.el8.x86_64.rpm}
RT_REPO_URL=${RT_REPO_URL:-http://download-node-02.eng.bos.redhat.com/rhel-8/nightly/RHEL-8/latest-RHEL-8.1.1/compose/RT/x86_64/os}
