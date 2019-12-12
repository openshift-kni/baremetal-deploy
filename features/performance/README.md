# Performance Tuning

All manifests should be applied automatically on a new cluster via `make deploy`, in case if you want to test each feature separately, refer to the feature section.

Before you apply any feature, you should:

- add `worker-rt` role to relevant nodes `oc label node <node_name> machineconfiguration.openshift.io/role=worker-rt`
- add `worker-rt` machine config pool `oc apply -f ../mcp/00-mcp-worker-rt.yaml`

## Environment variables

This is a list of environment variables that you should export before running `make generate`.

- `ISOLATED_CPUS` - CPU's that you want to isolate from the system usage.
- `RESERVED_CPUS` - CPU's that you want to reserve for the system and does not use for containers workloads.
- `MICROCODE_URL` - the location of the patched microcode_ctl RPM, as long as it is not part of RHCOS yet.  
  Defaults to a RH internal URL. For deployments outside the RH network provide the RPM on a reachable host and
  update this URL.  
  See the [bug](https://bugzilla.redhat.com/show_bug.cgi?id=1766178) for more information on this.
- `RT_REPO_URL` - the location of a yum repo which provides the RT kernel RPMs as long as they are not part of RHCOS yet.  
  Defaults to a RH internal URL. For deployments outside the RH network provide a yum repo on a reachable host
  and update this URL.  
  To configure your own yum repo check the [link](https://access.redhat.com/solutions/3176811).

## Huge Pages

To verify huge pages feature functionality:

- run `make generate`
- apply huge pages kernel boot parameters config via `oc create -f manifests/generated/12-machine-config-worker-rt-kargs.yaml`
- wait for workers update

```bash
oc -n openshift-machine-config-operator wait machineconfigpools worker-rt --for condition=Updating --timeout=1800s
oc -n openshift-machine-config-operator wait machineconfigpools worker-rt --for condition=Updated --timeout=1800s
```

- create the huge pages pod via `oc create -f examples/hugepages-pod.yaml`
- get pod UID by running `oc get pods -o custom-columns=NAME:.metadata.name,UID:.metadata.uid,HOST_IP:.status.hostIP`
- now you can find the specific cgroup under the host where the pod is running and check hugepages limit `cat /sys/fs/cgroup/hugetlb/kubepods.slice/kubepods-pod<pod_uid>.slice/hugetlb.1GB.limit_in_bytes`
- under the pod you can check the huge pages mount `mount | grep hugepages`

## RT kernel

The realtime kernel will be installed using MachineConfig, which installs a new systemd unit, which runs a script.
The template for the `MachineConfig` placed under `manifests/templates` and the script located in `assets`. The actual manifest is created by running `make generate`,
which will base64 encode the script and put it into the template. The result is stored under `manifests/generated/11-machine-config-worker-rt-kernel.yaml`.

## CPU manager

To enable the [CPU manager](https://docs.openshift.com/container-platform/4.2/scalability_and_performance/using-cpu-manager.html), you should:

- `make generate`
- enable CPU static policy via `KubeletConfiguration`, `oc create -f manifests/generated/12-kubeletconfig-worker-rt`
- wait for workers update

```bash
oc -n openshift-machine-config-operator wait machineconfigpools worker-rt --for condition=Updating --timeout=1800s
oc -n openshift-machine-config-operator wait machineconfigpools worker-rt --for condition=Updated --timeout=1800s
```

## Topology Manager

To enable the topology manager, you should:

- enable the topology manager feature gate `oc apply -f manifests/12-fg-latency-sensetive.yaml`
- wait for workers update

```bash
oc -n openshift-machine-config-operator wait machineconfigpools worker-rt --for condition=Updating --timeout=1800s
oc -n openshift-machine-config-operator wait machineconfigpools worker-rt --for condition=Updated --timeout=1800s
```

- update the kubelet configuration `oc apply -f manifests/12-kubeletconfig-worker-rt.yaml`
- wait for workers update

```bash
oc -n openshift-machine-config-operator wait machineconfigpools worker-rt --for condition=Updating --timeout=1800s
oc -n openshift-machine-config-operator wait machineconfigpools worker-rt --for condition=Updated --timeout=1800s
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
