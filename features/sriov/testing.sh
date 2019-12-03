#!/bin/bash
for node in $(oc get nodes --selector='!node-role.kubernetes.io/master' -o name); do
  oc label "$node" feature.node.kubernetes.io/network-sriov.capable="true"
done

numworkers=$(oc get nodes --selector='!node-role.kubernetes.io/master' --no-headers | wc -l)

export numworkers
export targetnamespace="${targetnamespace:-sriov-testing}"
export nic="${nic:-eno1}"

envsubst < project.yaml | oc create -f - 
envsubst < deployment.yaml | oc create -f - -n "${targetnamespace}"