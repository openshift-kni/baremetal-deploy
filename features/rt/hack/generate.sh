#!/bin/bash

set -euo pipefail

assetsDir=$(dirname "$0")/../assets
manifestsDir=$(dirname "$0")/../manifests

# Generate RT kernel MC
echo "generating 06-mc-rtkernel-worker-rt.yaml"
SCRIPT64="$(base64 -w 0 ${assetsDir}/rt-kernel-patch.sh)"
sed "s/_SCRIPT_/$SCRIPT64/" ${assetsDir}/mc-rtkernel-worker-rt.yaml.in > ${manifestsDir}/06-mc-rtkernel-worker-rt.yaml