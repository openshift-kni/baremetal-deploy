When using [baremetal_repo](https://github.com/openshift-kni/baremetal-deploy) repository to deploy a cluster you can pass the `networkConfig` settings using YAML files per role: master and worker, such YAML files could optionally include jinja format, and in combination of variables from the respective nodes in the inventory it is possible to render settings per node as desired. The steps to prepare are the following:

1) Set `master_network_config_template` and `worker_network_config_template` variables pointing to a path to your desired configuration:

include the following ansible extra-variables in your deployment. The files need to be located in the Ansible controller server:

```yaml
master_network_config_template: "/path/to/your/master_nmstate_file.yaml"
worker_network_config_template: "/path/to/your/worker_nmstate_file.yaml"
```

2) Include NMstate settings in YAML format for each role of nodes: master and workers, in the files of step 1. For example:

Content example of file `master_network_config_template`:
```yaml
interfaces:
- ipv4:
    auto-dns: true
    dhcp: true
    enabled: true
  ipv6:
    dhcp: false
    enabled: false
  link-aggregation:
    mode: 802.3ad
    options:
      miimon: 100
      mode: 802.3ad
    port:
    - ens1f0
    - ens1f1
  mtu: 9000
  name: bond0
  state: up
  type: bond
```

Content example of file `worker_network_config_template`:
```yaml
interfaces:
- ipv4:
    auto-dns: true
    dhcp: true
    enabled: true
  ipv6:
    dhcp: false
    enabled: false
  link-aggregation:
    mode: 802.3ad
    options:
      miimon: 100
      mode: 802.3ad
    port:
    - ens1f0
    - ens1f1
  mtu: 9000
  name: bond0
  state: up
  type: bond
- ipv4:
    auto-gateway: false
    auto-routes: false
    dhcp: true
    enabled: true
  ipv6:
    auto-gateway: false
    dhcp: false
    enabled: false
  mtu: 9000
  name: bond0.100
  state: up
  type: vlan
  vlan:
    base-iface: bond0
    id: 100
```

The same settings will be used for all nodes of the same role (masters and workers), then it is possible to use jinja format in the content of those files to customize settings per node. This is an example:

Content example of file `master_network_config_template` with jinja expressions:
```yaml
interfaces:
- name: eno2
  type: ethernet
  state: up
  ipv4:
    address:
    - ip: {{ static_ip.split('/')[0] }}
      prefix-length: {{ static_ip.split('/')[1] }}
    enabled: true
dns-resolver:
  config:
    server:
    - 192.168.0.2
routes:
  config:
  - destination: 0.0.0.0/0
    next-hop-address: 192.168.0.1
    next-hop-interface: eno2
```

Content example of file `worker_network_config_template` with jinja expressions:
```yaml
interfaces:
- name: eno2
  type: ethernet
  state: up
  ipv4:
    address:
    - ip: {{ static_ip.split('/')[0] }}
      prefix-length: {{ static_ip.split('/')[1] }}
    enabled: true
- name: eno3
  type: ethernet
  state: up
  ipv4:
    enabled: true
    auto-dns: true
    dhcp: true
dns-resolver:
  config:
    server:
    - 192.168.0.2
routes:
  config:
  - destination: 0.0.0.0/0
    next-hop-address: 192.168.0.1
    next-hop-interface: eno2
```


Finally in your inventory you can add variables per node, and they will be rendered from the templates provided. In this example `static_ip` variable will be rendered per node of each role, but you can include more variables if desired.
```
[masters]
master-0 name=master-0 role=master ipmi_user=admin ipmi_password=password ipmi_address=192.168.1.1 ipmi_port=623 provision_mac=ec:f4:bb:da:0c:58 static_ip="192.168.0.11/24"
master-1 name=master-1 role=master ipmi_user=admin ipmi_password=password ipmi_address=192.168.1.2 ipmi_port=623 provision_mac=ec:f4:bb:da:32:88 static_ip="192.168.0.12/24"
master-2 name=master-2 role=master ipmi_user=admin ipmi_password=password ipmi_address=192.168.1.3 ipmi_port=623 provision_mac=ec:f4:bb:da:0d:98 static_ip="192.168.0.13/24"

# Worker nodes
[workers]
worker-0 name=worker-0 role=worker ipmi_user=admin ipmi_password=password ipmi_address=192.168.1.4 ipmi_port=623 provision_mac=ec:f4:bb:da:0c:18 static_ip="192.168.0.14/24"
worker-1 name=worker-1 role=worker ipmi_user=admin ipmi_password=password ipmi_address=192.168.1.5 ipmi_port=623 provision_mac=ec:f4:bb:da:32:28 static_ip="192.168.0.15/24"
```
