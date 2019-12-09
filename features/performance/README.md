# Performance Tuning

All manifests should be applied automatically on a new cluster, in case if you want to test each feature separately, refer to the feature section.

## Huge Pages

To verify huge pages feature functionality:

- label your worker nodes with `oc label node <node_name> machineconfiguration.openshift.io/role=worker-rt`
- apply huge pages kernel boot parameters config via `oc create -f manifests/05-mc-kargs-worker-rt.yaml`
- wait for workers update

```bash
oc -n openshift-machine-config-operator wait machineconfigpools worker --for condition=Updating --timeout=1800s
oc -n openshift-machine-config-operator wait machineconfigpools worker --for condition=Updated --timeout=1800s
```

- create the huge pages pod via `oc create -f examples/hugepages-pod.yaml`
- get pod UID by running `oc get pods -o custom-columns=NAME:.metadata.name,UID:.metadata.uid,HOST_IP:.status.hostIP`
- now you can find the specific cgroup under the host where the pod is running and check hugepages limit `cat /sys/fs/cgroup/hugetlb/kubepods.slice/kubepods-pod<pod_uid>.slice/hugetlb.1GB.limit_in_bytes`
- under the pod you can check the huge pages mount `mount | grep hugepages`

## Topology Manager

To enable the topology manager, you should:

- enable the topology manager feature gate `oc apply -f manifests/05-fg-latency-sensetive.yaml`
- wait for workers update

```bash
oc -n openshift-machine-config-operator wait machineconfigpools worker --for condition=Updating --timeout=1800s
oc -n openshift-machine-config-operator wait machineconfigpools worker --for condition=Updated --timeout=1800s
```

- update the kubelet configuration `oc apply -f manifests/05-kubeletconfig-worker-rt.yaml`
- wait for workers update

```bash
oc -n openshift-machine-config-operator wait machineconfigpools worker --for condition=Updating --timeout=1800s
oc -n openshift-machine-config-operator wait machineconfigpools worker --for condition=Updated --timeout=1800s
```

- verify that kubelet configuration on the `worker-rt` updated with relevant parameters

```bash
cat /etc/kubernetes/kubelet.conf
{
    "kind":"KubeletConfiguration",
    ...
    "topologyManagerPolicy":"best-effort",
    "featureGates": {
        ...
        "TopologyManager":true,
        ...
    },
}
```
