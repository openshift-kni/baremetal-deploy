# kubernetes-nmstate

Node-networking configuration driven by Kubernetes and executed by
[nmstate](https://nmstate.github.io/).

Project page [kubernetes-nmstate](https://github.com/nmstate/kubernetes-nmstate)

### Node Network State

`NodeNetworkState` objects are created per each node in the cluster and can be
used to report available interfaces and network configuration. These objects
are created by kubernetes-nmstate and must not be touched by a user.

Example of `NodeNetworkState` listing network configuration of node01, the full
object can be found at [Node Network State tutorial](https://github.com/nmstate/kubernetes-nmstate/blob/master/docs/user-guide-state-reporting.md):

```yaml
apiVersion: nmstate.io/v1alpha1
kind: NodeNetworkState
metadata:
  name: node01
status:
  currentState:
    interfaces:
    - name: eth0
      type: ethernet
      state: up
      mac-address: 52:55:00:D1:55:01
      mtu: 1500
      ipv4:
        address:
        - ip: 192.168.66.101
          prefix-length: 24
        dhcp: true
        enabled: true
    ...
```

### Node Network Configuration Policy

`NodeNetworkConfigurationPolicy` objects can be used to specify desired
networking state per node or set of nodes. It uses API similar to
`NodeNetworkState`.

Example of a `NodeNetworkConfigurationPolicy` creating Linux bond `bond1` using
`ens8` and `ens9` as slaves in all the nodes in the cluster:

```yaml
apiVersion: nmstate.io/v1alpha1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: bond1
spec:
  desiredState:
    interfaces:
      - name: bond1
        type: bond
        ipv4:
          auto-dns: false
          auto-gateway: false
          auto-routes: false
          dhcp: true
          enabled: true
        state: up
        link-aggregation:
          mode: balance-rr
          options:
            miimon: "140"
          slaves:
            - ens8
            - ens9
```

## Deployment

To deploy kubernetes-nmstate use the `./deploy.sh` script in this folder.

## Test

For testing you can use the `./testing.sh` script in this folder.
The test will create a bond interface with the name `bond1` and attach `ens8` and `ens9` as the slave interfaces.

_Note:_ You can change the bond name and the slave interface names by editing the `myenv.file` file.

## Node configuration examples

### IP configuration

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

### Bond configuration

```
Ethernet Channel Bonding Driver: v3.7.1 (April 27, 2011)

Bonding Mode: load balancing (round-robin)
MII Status: up
MII Polling Interval (ms): 140
Up Delay (ms): 0
Down Delay (ms):

Slave Interface: enp3s0f2
MII Status: up
Speed: 1000 Mbps
Duplex: full
Link Failure Count: 0
Permanent HW addr: XX:XX:XX:XX:XX:XX
Slave queue ID: 0

Slave Interface: enp3s0f3
MII Status: up
Speed: 1000 Mbps
Duplex: full
Link Failure Count: 0
Permanent HW addr: XX:XX:XX:XX:XX:XX
Slave queue ID: 0
```
