# Bonding using machine-config-operator (MCO)

Project page [machine-config-operator](https://github.com/openshift/machine-config-operator)

This document focusses on using `Machine Config operator (MCO)` for interface bonding and vlan configurations on a node. `MachineConfig` CRD is used to write configuration files onto the node. It expects the file contents to be supplied as encoded data per current ignition specifications, the encoding is done via `base64` in this document. An alternative script based mechanism to generate ignition config is documented [here.](https://github.com/openshift-kni/baremetal-deploy/tree/master/features/bonding#script)

### Sample bond interface file (TYPE=Bond)

```
BONDING_OPTS="miimon=140 mode=balance-rr"
TYPE=Bond
BONDING_MASTER=yes
BOOTPROTO=dhcp
NAME=bond1
DEVICE=bond1
ONBOOT=yes
AUTOCONNECT_SLAVES=yes
```

### Sample vlan bond interface file (TYPE=Vlan, with physdev set to `bond1`)

```
VLAN=yes
TYPE=Vlan
PHYSDEV=bond1
VLAN_ID=20
BOOTPROTO=dhcp
NAME=bond1.20
DEVICE=bond1.20
ONBOOT=yes
```

### Sample slave interface file (TYPE=Ethernet, with master set to `bond1`)

```
TYPE=Ethernet
NAME="enp3s0f2"
DEVICE=enp3s0f2
ONBOOT=yes
PROXY_METHOD=none
BROWSER_ONLY=no
IPV4_FAILURE_FATAL=no
MTU=1500
MASTER=bond1
SLAVE=yes
```

### Encoding using base64

```
cat ifcfg-bond1 | base64
```

### Machine config pool

The machineconfigpool object shows a group of nodes to which a machine config can be applied.

```
$ oc get machineconfigpools
NAME     CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
master   rendered-master-ddc67ca664d7c26305129dd659483226   True      False      False      3              3                   3                     0                      18h
worker   rendered-worker-6c00884cabc50f4d42433e4e3acd603c   True      False      False      1              1                   1                     0                      18h
```

### Machine Config

This configuration creates a MachineConfig to write the `bond1` and `bond1.20` interface configuration files at the path locations `/etc/sysconfig/network-scripts/ifcfg-bond1` and `/etc/sysconfig/network-scripts/ifcfg-bond1.20` on the worker nodes. Multiple files can be specified here to copy ethernet interface files as well.

```
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: bonding-test-config
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,<encoded data>
        filesystem: root
        mode: 0644
        path: /etc/sysconfig/network-scripts/ifcfg-bond1
      - contents:
          source: data:text/plain;charset=utf-8;base64,<encoded data>
        filesystem: root
        mode: 0644
        path: /etc/sysconfig/network-scripts/ifcfg-bond1.20
```

### Node configuration examples

```
10: bond1: <BROADCAST,MULTICAST,MASTER,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether XX:XX:XX:XX:XX:XX brd ff:ff:ff:ff:ff:ff
    inet 192.X.X.100/24 brd 192.X.X.255 scope global noprefixroute bond1
       valid_lft forever preferred_lft forever
11: bond1.20@bond1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether XX:XX:XX:XX:XX:XX brd ff:ff:ff:ff:ff:ff
    inet 192.X.Y.100/24 brd 192.X.Y.255 scope global noprefixroute bond1.20
       valid_lft forever preferred_lft forever
```
