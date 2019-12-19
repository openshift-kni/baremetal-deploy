# dpdk testing

## Requisites

* [testpmd](testpmd.dockerfile) and [pktgen](pktgen.dockerfile) container images available

> For the sake of simplicity, the images in the pod defintions included here
> are publicly available.
> Use them at your own risk (quay.io/eminguez/testpmd & quay.io/eminguez/pktgen)

* The NIC to be used requires sriov support
* The sriov operator needs to be deployed and working (see [sriov](../sriov/))
* If using Intel NICs, the `SriovNetworkNodePolicy.spec.deviceType` needs to be `vfio-pci`,
otherwise, use `netdevice`. See [the official documentation for more information](https://docs.openshift.com/container-platform/4.2/networking/multiple-networks/configuring-sr-iov.html#configuring-sr-iov-devices_configuring-sr-iov).
* Huge pages and CPU Manager needs to be enabled

The prefered method to enable huge pages and CPU manager is to deploy the
[performance assets](../performance/), but just in case, this will show how to deploy
both features manually:

1. Label one of the workers:

```shell
oc label node/<node> node-role.kubernetes.io/worker-cpumanager=""
```

2. Create the required assets

```shell
cat <<EOF | oc apply -f -
---
apiVersion: config.openshift.io/v1
kind: FeatureGate
metadata:
  annotations:
    release.openshift.io/create-only: "true"
  name: latency-sensitive
spec:
  featureSet: LatencySensitive
---
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfigPool
metadata:
  name: worker-cpumanager
  labels:
    worker-cpumanager: ""
spec:
  machineConfigSelector:
    matchExpressions:
      - {key: machineconfiguration.openshift.io/role, operator: In, values: [worker,worker-rt,worker-cpumanager]}
  maxUnavailable: null
  nodeSelector:
    matchLabels:
      node-role.kubernetes.io/worker-cpumanager: ""
  paused: false
---
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: cpumanager-enabled
spec:
  machineConfigPoolSelector:
    matchLabels:
      worker-cpumanager: ""
  kubeletConfig:
    cpuManagerPolicy: static
    cpuManagerReconcilePeriod: 5s
    topologyManagerPolicy: single-numa-node
---
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: "worker-cpumanager"
  name: 50-worker-cpumanager-enable-hugepages
spec:
  kernelArguments:
    - 'intel_iommu=on'
    - 'default_hugepagesz=1GB'
    - 'hugepagesz=1G'
    - 'hugepages=16'
EOF
```

The worker will be rebooted to apply the required changes. 

> The `sriovnetwork` or the `net-attach-def` objects would be removed as well
> (known [sriov operator bug](https://bugzilla.redhat.com/show_bug.cgi?id=1770668)).
> If that's the case, simply remove the `sriovnetwork` or the `net-attach-def`
> and create it again. In this example:
>
> ```yaml
> apiVersion: sriovnetwork.openshift.io/v1
> kind: SriovNetwork
> metadata:
>   name: sriov-network
> spec:
>   ipam: |
>     {
>       "type": "dhcp"
>     }
>   networkNamespace: sriov-testing
>   resourceName: sriovnic
>   vlan: 0
> ```

## Procedure

* Create a test project and deploy the example pods:

```shell
oc new-project sriov-testing
oc create -f testpmd-pod.yaml -n sriov-testing
oc create -f pktgen-pod.yaml -n sriov-testing
```

* Connect to both pods (`oc rsh <pod>`) and verify the following data on each pod:

```shell
# PCI device plugged to the pod
echo $PCIDEVICE_OPENSHIFT_IO_SRIOVNIC
# Available cpus (physcpubind)
numactl -s
# numa node used by the VF
cat /sys/bus/pci/devices/${PCIDEVICE_OPENSHIFT_IO_SRIOVNIC}/numa_node
# CPUs in the same numa node used by the VF
lscpu | grep "NUMA node$(cat /sys/bus/pci/devices/${PCIDEVICE_OPENSHIFT_IO_SRIOVNIC}/numa_node)"
```

As an example:

```shell
echo $PCIDEVICE_OPENSHIFT_IO_SRIOVNIC

0000:01:11.0
```

```shell
numactl -s

policy: default
preferred node: current
physcpubind: 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55
cpubind: 0 1
nodebind: 0 1
membind: 0 1
```

```shell
cat /sys/bus/pci/devices/${PCIDEVICE_OPENSHIFT_IO_SRIOVNIC}/numa_node

0
```

```shell
lscpu | grep "NUMA node$(cat /sys/bus/pci/devices/${PCIDEVICE_OPENSHIFT_IO_SRIOVNIC}/numa_node)"

NUMA node0 CPU(s):   0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54
```

### Run the tests

In order to test dpdk, `testpmd` and `pktgen` needs to be executed (use two terminals):

#### testpmd pod

```shell
oc rsh testpmd
testpmd -l <list of cpus from the lscpu output> -w <pci slot> -- -i --portmask=0x1 --nb-cores=2 --forward-mode=macswap --port-topology=loop
```

For example

```shell
testpmd -l 10,11,12,13 -w 0000:01:10.2 -- -i --portmask=0x1 --nb-cores=2 --forward-mode=macswap --port-topology=loop
```

Wait for console to appear, then:

```shell
clear port stats all
show port stats all
start
```

Note the MAC address as it needs to be used in the pktgen pod.

> To exit, use `quit` at the testpmd prompt.

#### pktgen pod

```shell
oc rsh pktgen
pktgen -l <list of cpus> -w <pic slot> --file-prefix pktgen_3 -- -P 0x1 -T -m [<cpu>].0
```

For example:

```shell
pktgen -l 22,24,26,28 -w 0000:01:10.2 --file-prefix pktgen_3 -- -P 0x1 -T -m 26.0
```

Wait for console to appear, then:

```shell
set 0 dst mac <testpmd mac>
start all
```

Pktgen should start sending packets to testpmd.

> To exit, use `quit` at the prompt.

## To do

* [ ] Have better dockerfiles
* [ ] Automate the procedure
