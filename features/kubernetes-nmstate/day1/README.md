When using [baremetal_repo](https://github.com/openshift-kni/baremetal-deploy) repository to deploy a cluster you can pass the `networkConfig` settings using two forms:

a) If you wish to use your own NMState YAML file as created above, you can set `master_network_config_file` and `worker_network_config_file` variables pointing to a path to your desired configuration:

As YAML as extra-variables in your deployment:

```yaml
master_network_config_file: "/path/to/your/master_nmstate_file.yaml"
worker_network_config_file: "/path/to/your/worker_nmstate_file.yaml"
```

As JSON in your inventory file:

```
master_network_config_file="/path/to/your/master_nmstate_file.yaml"
worker_network_config_file="/path/to/your/worker_nmstate_file.yaml"
```

b) If you wish to provide the `networkConfig` settings in a raw YAML variable, you can use the `master_network_config_raw` and `worker_network_config_raw` variables and pass them as extra-variables in your deployment.

```yaml
master_network_config_raw:
  interfaces:
  - name: <nic1_name>
    type: ethernet
    state: up
    ipv4:
      address:
      - ip: <ip_address>
        prefix-length: 24
      enabled: true
  dns-resolver:
    config:
      server:
      - <dns_ip_address>
  routes:
    config:
    - destination: 0.0.0.0/0
      next-hop-address: <next_hop_ip_address>
      next-hop-interface: <next_hop_nic1_name>

worker_network_config_raw:
  interfaces:
  - name: <nic1_name>
    type: ethernet
    state: up
    ipv4:
      address:
      - ip: <ip_address>
        prefix-length: 24
      enabled: true
  dns-resolver:
    config:
      server:
      - <dns_ip_address>
  routes:
    config:
    - destination: 0.0.0.0/0
      next-hop-address: <next_hop_ip_address>
      next-hop-interface: <next_hop_nic1_name>
----
