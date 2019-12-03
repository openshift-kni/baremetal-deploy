#!/bin/bash

set -e

KNMSTATE_VERSION="v0.12.0"
oc create -f https://github.com/nmstate/kubernetes-nmstate/releases/download/${KNMSTATE_VERSION}/namespace.yaml
oc create -f https://github.com/nmstate/kubernetes-nmstate/releases/download/${KNMSTATE_VERSION}/service_account.yaml
oc create -f https://github.com/nmstate/kubernetes-nmstate/releases/download/${KNMSTATE_VERSION}/role.yaml
oc create -f https://github.com/nmstate/kubernetes-nmstate/releases/download/${KNMSTATE_VERSION}/role_binding.yaml
oc create -f https://github.com/nmstate/kubernetes-nmstate/releases/download/${KNMSTATE_VERSION}/nmstate_v1alpha1_nodenetworkstate_crd.yaml
oc create -f https://github.com/nmstate/kubernetes-nmstate/releases/download/${KNMSTATE_VERSION}/nmstate_v1alpha1_nodenetworkconfigurationpolicy_crd.yaml
oc create -f https://github.com/nmstate/kubernetes-nmstate/releases/download/${KNMSTATE_VERSION}/scc.yaml
oc create -f https://github.com/nmstate/kubernetes-nmstate/releases/download/${KNMSTATE_VERSION}/operator.yaml
