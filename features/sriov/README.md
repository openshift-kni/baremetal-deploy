# Validating SRIOV operator

## References

* [SRIOV operator](https://github.com/openshift/sriov-network-operator/blob/master/doc/quickstart.md)
* [OCP4 SRIOV operator official documentation](https://docs.openshift.com/container-platform/4.2/networking/multiple-networks/configuring-sr-iov.html)

## Instructions

* Create a `myvars` file that fits your environment. You can use the [myvars.example](myvars.example) as inspiration.
* Run the `deploy.sh` script

The script:

* deploys the SRIOV operator from the operator hub ([operator namespace](01-sriov-namespace.yaml), [operator group](02-sriov-operatorgroup.yaml) and [subscription](03-sriov-subscription.yaml)).
* patches the `networks.operator.openshift.io/cluster` object to create a dummy dhcp network in order to create a dhcp-daemon
daemonset required for ipam/dhcp to work with multus (only if needed)
* configures the VFs via the [network node policy](11-sriov-networknodepolicy.yaml).
* labels the workers as SRIOV capable (`feature.node.kubernetes.io/network-sriov.capable: "true"`, customizable).
* creates a [`sriovnetwork` object](12-sriov-network.yaml)

Ideally, the SRIOV capable NIC is attached to the 'provisioning' network, where the `metal3-dnsmasq` container is
attached and will provide private IPs to the VFs so they can see each other.

### Udev rules

The operator creates some udev rules to avoid the VFs to request IP addresses from the DHCP pool,
but only for supported NICs (see [the official documentation](https://docs.openshift.com/container-platform/4.2/networking/multiple-networks/configuring-sr-iov.html#supported-devices_configuring-sr-iov)).

As a workaround for unsupported NICs and only as an experiment, a custom daemonset is created to inject the same udev rules for unsupported NICs.

## Testing

The following script creates a [namespace](20-sriov-testing-namespace.yaml) and a [deployment](21-sriov-testing-deployment.yaml) that creates a pod on each worker with a VF attached to it.

```shell
./testing.sh
```

Then, you can `oc rsh` into the pods and see the interfaces attached to it... and see if they reach each other:

* Observe the pods:

```shell
oc get po -n sriov-testing
NAME                          READY   STATUS    RESTARTS   AGE
sriov-test-5bb79d745f-bf98r   1/1     Running   0          49s
sriov-test-5bb79d745f-bhwmp   1/1     Running   0          56s
sriov-test-5bb79d745f-sqtk4   1/1     Running   0          49s
```

* Observe the IPs for the sriov adapters:

```shell
oc get po -n sriov-testing sriov-test-5bb79d745f-bf98r -o jsonpath="{.metadata.annotations}"

map[k8s.v1.cni.cncf.io/networks:sriov-testing/sriov-network k8s.v1.cni.cncf.io/networks-status:[{
    "name": "openshift-sdn",
    "interface": "eth0",
    "ips": [
        "10.131.0.16"
    ],
    "dns": {},
    "default-route": [
        "10.131.0.1"
    ]
},{
    "name": "sriov-net",
    "interface": "net1",
    "ips": [
        "172.22.0.64"
    ],
    "mac": "02:ad:a5:2b:72:af",
    "dns": {}
}]
...
```

```shell
oc get po -n sriov-testing sriov-test-5bb79d745f-bhwmp -o jsonpath="{.metadata.annotations}"

map[k8s.v1.cni.cncf.io/networks:sriov-testing/sriov-network k8s.v1.cni.cncf.io/networks-status:[{
    "name": "openshift-sdn",
    "interface": "eth0",
    "ips": [
        "10.131.0.14"
    ],
    "dns": {},
    "default-route": [
        "10.131.0.1"
    ]
},{
    "name": "sriov-net",
    "interface": "net1",
    "ips": [
        "172.22.0.50"
    ],
    "mac": "52:17:eb:35:37:f7",
    "dns": {}
}]
...
```

* rsh into on of them and curl ip:8080:

```shell
oc rsh -n sriov-testing sriov-test-5bb79d745f-bhwmp

$ curl 172.22.0.64:8080
Hello World!$
```
