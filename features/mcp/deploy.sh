#!/usr/bin/env bash

set -euo pipefail

source $(dirname "$0")/../hack/common.sh

oc apply -f ${MCP_DIR}/00-mcp-worker-rt.yaml
