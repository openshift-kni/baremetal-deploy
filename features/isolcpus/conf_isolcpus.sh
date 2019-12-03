#!/bin/bash

### This script updates the cluster nodes to configure the kernel isolcpus
### The first part of the script updates the nodes with a custom build hyperkube and
### the cluster with a custom built MCO image.
### The script then creates a node configuration for isolcpus and reservedSystemCPUs

usage(){
	echo "usage::conf_isolcpus -i [isolcpus] -r [reserved_cpus]"
	echo "-i isolcpus: specify the isolcpus kernel option to be set on the nodes"
	echo "-r reserved cpus:  explicitly define the cpu list that will be reserved for system on each node"
	echo "For example: on a 24 CPUs system reserved-cpus=0,1,2,3, then cpu 0,1,2,3 will be reserved for the system"
	echo "and isolcpus=4-23 will be isolated for containers"
}

while getopts i:r:h option
do
case "${option}"
in
i) isolcpus=${OPTARG};;
r) reservedCPU=${OPTARG};;
h) usage; exit 0;;
\?) usage; exit 1;;
esac
done

if ([ -z "$isolcpus" ] || [ -z "$reservedCPU" ]) then
 usage
 exit 1
fi

pathToHyperkube="https://github.com/vladikr/hyperkube/raw/master/hyperkube"
mcoImage=quay.io/vladikr/origin-machine-config-operator:latest


### 1. Update kubelet (hyperkube) on workers
for worker_node in $(oc get node | grep worker | awk '{print $1}');
do
  oc label node $worker_node cpumanager=true
  oc debug node/$worker_node -- <<EOF
  chroot /host
  /bin/curl -L $pathToHyperkube > /tmp/hyperkube
  /bin/chmod +x /tmp/hyperkube
  nohup /bin/sh -c '/bin/systemctl stop kubelet; /bin/mount -o remount,rw /usr; /bin/cp /tmp/hyperkube /usr/bin/hyperkube; /bin/systemctl start kubelet'
EOF
done	


### 2. Update MCO
oc label mcp worker custom-kubelet=cpumanager-enabled
oc project openshift-machine-config-operator
oc scale --replicas=0 deploy/machine-config-operator
oc scale --replicas=0 deploy/cluster-version-operator -n openshift-cluster-version
# Patch the images.json
tmpf=$(mktemp)
oc get -o json configmap/machine-config-operator-images > ${tmpf}
outf=$(mktemp)
python3 > ${outf} <<EOF
import sys,json
cm=json.load(open("${tmpf}"))
images = json.loads(cm['data']['images.json'])
for k in images:
  if k.startswith('machineConfig'):
    images[k] = "${mcoImage}"
cm['data']['images.json'] = json.dumps(images)
json.dump(cm, sys.stdout)
EOF
oc replace -f ${outf}
rm ${tmpf} ${outf}

for x in operator controller server daemon; do
patch=$(mktemp)
cat >${patch} <<EOF
spec:
  template:
     spec:
       containers:
         - name: machine-config-${x}
           image: ${mcoImage}
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
rm ${patch}
echo "Patched ${target}"
done
oc scale --replicas=1 deploy/machine-config-operator


### 3. Create mc with isolcpu
cat <<EOF | oc create -f -
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 02-worker-isolcpus
spec:
  config:
    ignition:
       version: 2.2.0
  kernelArguments:
  - isolcpus=$isolcpus
EOF


### 4. Create KubeConfig with cpumanager
cat <<EOF | oc create -f -
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: cpumanager-enabled
spec:
  machineConfigPoolSelector:
    matchLabels:
      custom-kubelet: cpumanager-enabled
  kubeletConfig:
     reservedSystemCPUs: $reservedCPU
     cpuManagerPolicy: static
     cpuManagerReconcilePeriod: 5s
EOF

