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
          miimon: '140'
        slaves:
        - ens8
        - ens9
```

## Deployment 

To deploy kubernetes-nmstate use the `./deploy.sh` script in this folder.

## Test

For testing you can use the `./testing.sh` script in this folder.
The test will create a bond interface with the name `bond1` and attach `ens8` and `ens9` as the slave interfaces.

*Note:* You can change the bond name and the slave interface names by editing the `myenv.file` file.