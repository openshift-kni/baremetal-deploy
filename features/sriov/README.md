# Validating SRIOV operator

## References

* [SRIOV operator](https://github.com/openshift/sriov-network-operator/blob/master/doc/quickstart.md)

## TL;DR

* Create a `policy.yaml` and `network.yaml` that fits your environment
* Run the `deploy.sh` script

It will deploy the SRIOV operator and configure your sriov cards (VFS)

In order to avoid wasting IP addresses from the DHCP pool, it is required to apply a machine-config to disable NetworkManager on the VFs.

First, see the VF PCI IDs:

```
oc debug node/<mynode>
chroot /host
lspci -nn | grep "Virtual Function"
...
01:10.0 Ethernet controller [0200]: Intel Corporation X540 Ethernet Controller Virtual Function [8086:1515] (rev 03)
01:10.2 Ethernet controller [0200]: Intel Corporation X540 Ethernet Controller Virtual Function [8086:1515] (rev 03)
01:10.4 Ethernet controller [0200]: Intel Corporation X540 Ethernet Controller Virtual Function [8086:1515] (rev 03)
01:10.6 Ethernet controller [0200]: Intel Corporation X540 Ethernet Controller Virtual Function [8086:1515] (rev 03)
```

The PCI ID is `1515` in this example, so a machineconfig needs to be created as:

```
./apply_mc.sh 1515
```

> NOTE: The machine-config applies to all the workers (`machineconfiguration.openshift.io/role: worker`) and it means they will be rebooted.

## Testing

```
./testing.sh
```
