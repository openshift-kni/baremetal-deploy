#!/usr/bin/env bash

set -xeuo pipefail
export reserved_cpus="${reserved_cpus:-1,2}"
IN_CLUSTER_NAME=quay.io/vladikr/origin-machine-config-operator:latest
HYPERKUBE="http://people.redhat.com/~kboumedh/hyperkube"

for ip in $(oc get nodes --selector='!node-role.kubernetes.io/master' -o custom-columns=IP:.status.addresses[0].address --no-headers); do
    ssh -o StrictHostKeyChecking=no core@$ip "curl -L $HYPERKUBE > hyperkube; sudo systemctl stop kubelet ; sudo mount -o remount,rw /usr ; sudo cp hyperkube /usr/bin ; sudo chmod 700 /usr/bin/hyperkube ; sudo mount -o remount,ro /usr ; sudo systemctl start kubelet"
done

oc project openshift-machine-config-operator

# Scale down the operator now to avoid it racing with our update.
oc -n openshift-cluster-version scale --replicas=0 deploy/cluster-version-operator
oc scale --replicas=0 deploy/machine-config-operator

# Patch the images.json
oc get cm -o yaml machine-config-operator-images | sed 's@machineConfigOperator.*@machineConfigOperator": "quay.io/vladikr/origin-machine-config-operator:latest",@' | oc replace -f - -n openshift-machine-config-operator

for x in operator controller server daemon; do
patch=$(mktemp)
cat >${patch} <<EOF
spec:
  template:
     spec:
       containers:
         - name: machine-config-${x}
           image: ${IN_CLUSTER_NAME}
EOF

# And for speed, patch the deployment directly rather
# than waiting for the operator to start up and do leader
# election.
case $x in
    controller|operator)
        target=deploy/machine-config-${x}
        ;;
    daemon|server)
        target=daemonset/machine-config-${x}
        ;;
    *) echo "Unhandled $x" && exit 1
esac

oc patch "${target}" -p "$(cat ${patch})"
rm -f ${patch}
echo "Patched ${target}"
done
oc scale --replicas=1 deploy/machine-config-operator

envsubst < cpumanager-kubeletconfig.yml | oc create -f -
envsubst < mc_isolcpus.yml | oc create -f -
