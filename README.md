## JetSki
JetSki inherits roles from [upstream](https://github.com/openshift-kni/baremetal-deploy) and [midstream](https://github.com/dustinblack/baremetal-deploy/tree/rh_scale_shared_labs), and aims to provide a consistent, seamless OpenShift installation experience in Red Hat's Shared Labs.

_**Table of contents**_

<!-- TOC -->

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Features of JetSki](#features-of-jetski)
- [Deployment Architecture](#deployment-architecture)
- [Tour of the Ansible Playbook](#tour-of-the-ansible-playbook)
- [Running the Ansible Playbook](#running-the-ansible-playbook)
- [Versions Tested](#versions-tested)
- [Limitations](#limitations)
- [Additional Material/Advanced Usage](#additional-materialadvanced-usage)
<!-- /TOC -->

## Introduction

This Ansible  playbook and set of Ansible roles are aimed at providing a cluster of Red Hat OpenShift 4 (`IPI`) in the Red Hat shared labs with as little user input and intervention as possible.


## Prerequisites

The playbook is intended to be run from outside the cluster of machines you wish to deploy on, from a host we will refer to as `jumphost` for the purposes of this discussion. It could even be a user's laptop or some Virtual Machine. The host from which the the playbook is run from (`jumphost`) must satisfy the following requirements

* Ansible >= 2.9
* Python 3.6+ 
* Fedora/CentOS/RHEL
* Passwordless sudo for user running the playbook on the ansible control node (host where the playbooks are being run from), since certain package installs are done

Passwordless sudo can be setup as below:
```
echo "username ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/username
chmod 0440 /etc/sudoers.d/username
```
The `username` should be the user with which the playbook is run as.

The playbook has been most extensively tested running from a Fedora 30 `jumphost`.

The servers used for the OpenShift deployment itself are recommended to satisfy the following requirements. 

- Best Practice Minimum Setup: 6 Physical servers (1 provision node, 3 master and 2 worker nodes)
- Minimum Setup: 4 Physical servers (1 provision node, 3 master nodes)
- Each server needs a minimum 2 backend NICs (most hardware in the shared labs has atleast 3 backedn NICs)
- Each server should have a RAID-1 configured and initialized (should already be done in the shared labs)
- Each server must have IPMI configured (should already be done in the shared labs)

##  Features of JetSki
* Dynamic generation of inventory for a seamless deployment experience 
* Minimum variables needed for deployment, meaning more heavy lifting done by  the automation, resulting in lower margin of error and lesser time spent by user populating the inventory
* Low barrier of entry, no need for user to even simply copy keys for ansible to run against provisioner host, everything is done by the playbook
* *Consistent user experience with everything being orchestrated through one playbook
* Can be run from outside the cluster, from a user's laptop or any `jumphost`
* Automatic detection of python interpreter on provisioner node
* Re-Images Provisioner node as needed through Foreman
* Prepares the the provisioner node for subsequent run of the installer
* Tightly integrated with lab automation, uses some metadata provided by the Lab Wiki along with automated network discovery for dynamic inventory generation
* Modular architecture, inherits roles from [upstream](https://github.com/openshift-kni/baremetal-deploy) and [midstream](https://github.com/dustinblack/baremetal-deploy/tree/rh_scale_shared_labs) without changing them, only adding roles that run before them, to setup the inventory and required parameters for the success of those roles

##  Deployment Architecture
For end-to-end automation and easy deployment, JetSki makes certain assumptions. The first node in your lab allocation is deployed as the provisioner host and the next 3 nodes are deployed as masters. The rest of the nodes are deployed asworkers depending on how many workers were requested by user (by default all remaining nodes are deployed as workers unless otherwise specified by `worker_count` variable in `ansible-ipi-install/group_vars/all.yml`). `dnsmasq` is also setup on the provisioner to provide `DNS` and `DHCP` for the baremetal interfaces of the OpenShift nodes.

## Tour of the Ansible Playbook

The `ansible-ipi-install`  directory consists of three main sub-directories in addition to the main playbook `playbook.yml` that is used to kick off the installation. They are:

- `group_vars` - Contains the `all.yml` which holds the bare minimum variables needed for install
- `inventory` - contains the file `hosts.sample` that has advanced variables for customized installation
- `roles` - contains eight roles: `bootstrap`, `prepare-kni`, `add-provisioner`, `network-discovery`, `set-deployment-facts`, `shared-labs-prep`,`node-prep` and `installer`. `node-prep` handles all the prerequisites that the provisioner node requires prior to running the installer. The `installer` role handles extracting the installer, setting up the manifests, and running the Red Hat OpenShift installation.

The purpose served by each role can be summarized as follows:
* `bootstrap`- This role does a **lot** of heavy lifting for seamless deployment in the shared labs. On a high level, this role is responsible for installing needed packages on the `jumphost`, obtaining the list of nodes in your lab allocation dynamically, setting some variables required in inventory as ansible facts (like list of master nodes, worker nodes, mgmt interfaces), copying keys of the `jumphost` to the provisioner, rebuilding the provisioner if needed and finally adding the master and worker nodes to the in-memory dynamic inventory of ansible. This role runs on the `jumphost` aka `localhost`.
* `prepare-kni`-  Prepares the `kni` user and related artifacts on the provisioner node. This role runs on the provisioner host.
* `add-provisioner`- Adds provsioner host to the dynamic in-memory inventory. This role runs on the `jumphost` aka `localhost`.
* `network-discovery`- Set several important variables for the inventory including the NICs and MACs to be used for the provisioning and baremetal networks. Some of the MAC details are obtained from an inventory automatically generated on the Lab Wiki which the network-discovery role uses to further set all variables needed for proper networking. This role runs on the provisioner host.
* `set-deployment-facts`- This role is used to set some of the facts registered on the jumphost on to the provisioner host for use in future roles. This role runs on the provisioner host.
* `shared-labs-prep`- Creates the BM bridge, powers on nodes, sets boot order etc. This role runs on the provisioner host.
* `node-prep`- Prepares the provisioner node for the OpenShift Installer by installing needed packages, creating necessary directories etc. This role runs on the provisioner host.
* `installer`- Actually drives the OpenShift Installer. This role runs on the provisioner host.

The tree structure is shown below:

```sh
├── ansible.cfg
├── group_vars
│   └── all.yml
├── inventory
│   └── hosts.sample
├── playbook.yml
└── roles
    ├── add-provisioner
    │   └── tasks
    │       └── main.yml
    ├── bootstrap
    │   ├── tasks
    │   │   ├── 01_install_packages.yml
    │   │   ├── 05_ssh_keys.yml
    │   │   ├── 10_load_inv.yml
    │   │   ├── 20_reprovision_nodes.yml
    │   │   ├── 25_copykeys.yml
    │   │   ├── 30_get_interpreter.yml
    │   │   ├── 40_prepare_provisioning.yml
    │   │   ├── 50_add_ocp_inventory.yml
    │   │   ├── 55_add_ocp_masters.yml
    │   │   ├── 60_add_ocp_workers.yml
    │   │   └── main.yml
    │   └── vars
    │       └── main.yml
    ├── installer
    │   ├── defaults
    │   │   └── main.yml
    │   ├── files
    │   │   ├── customize_filesystem
    │   │   │   ├── master
    │   │   │   │   └── etc
    │   │   │   │       └── sysconfig
    │   │   │   │           └── network-scripts
    │   │   │   │               └── ifcfg-enp3s0f0
    │   │   │   └── worker -> master
    │   │   ├── filetranspile-1.1.1.py
    │   │   └── manifests
    │   ├── handlers
    │   │   └── main.yml
    │   ├── library
    │   │   └── podman_container.py
    │   ├── meta
    │   │   └── main.yml
    │   ├── tasks
    │   │   ├── 10_get_oc.yml
    │   │   ├── 15_disconnected_registry_create.yml
    │   │   ├── 15_disconnected_registry_existing.yml
    │   │   ├── 20_extract_installer.yml
    │   │   ├── 23_rhcos_image_paths.yml
    │   │   ├── 24_rhcos_image_cache.yml
    │   │   ├── 25_create-install-config.yml
    │   │   ├── 30_create_metal3.yml
    │   │   ├── 40_create_manifest.yml
    │   │   ├── 50_extramanifests.yml
    │   │   ├── 55_customize_filesystem.yml
    │   │   ├── 59_cleanup_bootstrap.yml
    │   │   ├── 60_deploy_ocp.yml
    │   │   ├── 70_cleanup_sub_man_registeration.yml
    │   │   └── main.yml
    │   ├── templates
    │   │   ├── 99-etc-chrony.conf.j2
    │   │   ├── chrony.conf.j2
    │   │   ├── install-config-appends.j2
    │   │   ├── install-config.j2
    │   │   └── metal3-config.j2
    │   ├── tests
    │   │   ├── inventory
    │   │   └── test.yml
    │   └── vars
    │       └── main.yml
    ├── network-discovery
    │   └── tasks
    │       └── main.yml
    ├── node-prep
    │   ├── defaults
    │   │   └── main.yml
    │   ├── handlers
    │   │   └── main.yml
    │   ├── library
    │   │   └── nmcli.py
    │   ├── meta
    │   │   └── main.yml
    │   ├── tasks
    │   │   ├── 100_power_off_cluster_servers.yml
    │   │   ├── 10_validation.yml
    │   │   ├── 15_validation_disconnected_registry.yml
    │   │   ├── 20_sub_man_register.yml
    │   │   ├── 30_req_packages.yml
    │   │   ├── 40_bridge.yml
    │   │   ├── 50_modify_sudo_user.yml
    │   │   ├── 60_enabled_services.yml
    │   │   ├── 70_enabled_fw_services.yml
    │   │   ├── 80_libvirt_pool.yml
    │   │   ├── 90_create_config_install_dirs.yml
    │   │   └── main.yml
    │   ├── templates
    │   │   └── dir.xml.j2
    │   ├── tests
    │   │   ├── inventory
    │   │   └── test.yml
    │   └── vars
    │       └── main.yml
    ├── prepare-kni
    │   └── tasks
    │       └── main.yml
    ├── set-deployment-facts
    │   └── tasks
    │       └── main.yml
    └── shared-labs-prep
        ├── defaults
        │   └── main.yml
        ├── library
        │   └── nmcli.py -> ../../node-prep/library/nmcli.py
        ├── tasks
        │   └── main.yml
        ├── templates
        │   ├── ocp4-lab.dnsmasq.conf.j2
        │   └── ocp4-lab.ifcfg-template.j2
        ├── tests
        │   ├── inventory
        │   └── test.yml
        └── vars
            └── main.yml

```

## Running the Ansible Playbook

The TL;DR version is 

```sh
$ ansible-playbook -i inventory/hosts playbook.yml
```

However, for the playbook to successfully execute certain variables have to be set at a minimum in `ansible-ipi-install/group_vars/all.yml`.

The following are the detailed steps to successfully run the Ansible playbook.

### The `ansible.cfg` file

While the `ansible.cfg` may vary upon your environment a sample is provided in the repository. The default `ansible.cfg` supplied in this repository should work in the shared labs. This is purely infromational, **modifications are not necessary.**

```ini
[defaults]
inventory=./inventory
remote_user=kni
callback_whitelist = profile_tasks

[privilege_escalation]
become_method=sudo
```
### Modifying the `ansible-ipi-install/group_vars/all.yml` file

This is the most important file to modify for a successful install of OpenShift in the Red Hat Shared Labs. Some variables can be left default, but the most important ones to be filled out are
* `cloud_name`
* `lab_name`
* `ansible_ssh_password`
* `version`
* `build`
* `pullsecret`
* `hammer_host` (Optional, if you manually provisioned a clean RHEL 8.1 install on the first node   in your lab allocation, because this variable is to rebuild the provisioning host using foreman)

Here's a sample
```yml
# This is the location where the list of hosts your lab allocation will be 
# downloaded to in json format. Leave default, for most cases
ocpinv_file: "{{ playbook_dir }}/ocpinv.json"
# Your allocation name/number in the shared labs
cloud_name: cloud10
# Lab name, typically can be alias or scale
lab_name: scale
# Default lab password to your nodes so that keys can be added automatically for ansible to run
ansible_ssh_pass: password
# Location of the private key of the user running the ansible playbook, leave default
ansible_ssh_key: "{{ ansible_user_dir }}/.ssh/id_rsa"
# The version of the openshift-installer, undefined or empty results in the playbook failing with error message.
# Values accepted: 'latest-4.3', 'latest-4.4', explicit version i.e. 4.3.0-0.nightly-2019-12-09-035405
# For reference, https://openshift-release.svc.ci.openshift.org/
version: "4.3.5"
# Enter whether the build should use 'dev' (nightly builds) or 'ga' for Generally Available version of OpenShift
# Empty value results in playbook failing with error message.
build: "ga"
# Your pull secret, https://cloud.redhat.com/openshift/install
pullsecret: ''
# This variable serves two purposes, one: If the host being used as provisioner (automatically, the first host in your lab assignment) is not pre-installed with RHEL 8.1
# the playbook logs into this host to make hammer cli calls to mark the host for a build with RHEL 8.1. Two: If you are redeploying on an allocation with a previously installed
# OpenShift cluster, it might be better to start with a clean provisioning host, in that case also, the hammer_host variable is used to reprovision the system based on 
# `rebuild_provisioner` variable below. If you do not have access to this type of host for reprovisioning/making hammer cli calls, it is recommended that you start with a RHEL 8.1
# clean provisioning host (manually install RHEL 8.1 on the first host in your lab allocation), so that `hammer_host` is never needed
hammer_host: hwstore.example.com
# The automation automatically rebuilds provisioner node to rhel 8.1 if not already rhel 8.1 (see nammer_host variable)
# However you can also force a reprovsioning of the provisioner node for redeployment scenarios
rebuild_provisioner: false
# Number of workers desired, by default all hosts in your allocation except 1 provisioner and 3 masters are used workers
# However that behaviour can be overrided by explicitly settign the desired number of workers here. For a masters only deploy,
# set worker_count to 0
worker_count: 0
alias:
#lab specific vars, leave default
  lab_url: "http://quads.alias.bos.scalelab.redhat.com"
scale:
# lab specific vars, leave default
  lab_url: "http://quads.rdu2.scalelab.redhat.com"

```
 
### Modifying the `inventory/hosts` file

The bare minimum variables to get a successful install are listed in `ansible-ipi-install/group_vars/all.yml`. Typically, correctly filing `ansible-ipi-install/group_vars/all.yml` should suffice for the shared labs use case, but in cases where some advanced configuration is needed and to fully utilize the options supported by the installer and the [`upstream playbooks`]([https://github.com/openshift-kni/baremetal-deploy](https://github.com/openshift-kni/baremetal-deploy)), the `inventory/hosts` can be edited by the user. For example, the `SDN` for OpenShift can be set ising the `network_type` variable in the inventory. Some of the variables are explicitly left empty and **require** user input for the playbook to run.
Below is a sample of the `ansible-ipi-install/inventory/hosts` file

```ini
[all:vars]

###############################################################################
# Required configuration variables for IPI on Baremetal Installations         #
###############################################################################

# (Optional) Activation-key for proper setup of subscription-manager, empty value skips registration
#activation_key=""

# (Optional) Activation-key org_id for proper setup of subscription-manager, empty value skips registration
#org_id=""

# The directory used to store the cluster configuration files (install-config.yaml, pull-secret.txt, metal3-config.yaml)
dir="{{ ansible_user_dir }}/clusterconfigs"

# Provisioning IP address (default value)
prov_ip=172.22.0.3

# (Optional) Enable playbook to pre-download RHCOS images prior to cluster deployment and use them as a local
# cache. Default is false.
#cache_enabled=True

# (Optional) The port exposed on the caching webserver. Default is port 8080.
#webserver_caching_port=8080

# (Optional) Enable IPv6 addressing instead of IPv4 addressing on both provisioning and baremetal network
#ipv6_enabled=True

# (Optional) When ipv6_enabled is set to True, but want IPv4 addressing on provisioning network
# Default is false.
#ipv4_provisioning=True

# (Optional) When ipv6_enabled is set to True, but want IPv4 addressing on baremetal network
#ipv4_baremetal=True

# (Optional) A list of clock servers to be used in chrony by the masters and workers
#clock_servers=["pool.ntp.org","clock.redhat.com"]

# (Optional) Provide HTTP proxy settings
#http_proxy=http://USERNAME:PASSWORD@proxy.example.com:8080

# (Optional) Provide HTTPS proxy settings
#https_proxy=https://USERNAME:PASSWORD@proxy.example.com:8080

# (Optional) comma-separated list of hosts, IP Addresses, or IP ranges in CIDR format
# excluded from proxying
# NOTE: OpenShift does not accept '*' as a wildcard attached to a domain suffix
# i.e. *.example.com
# Use '.' as the wildcard for a domain suffix as shown in the example below.
# i.e. .example.com
#no_proxy_list="172.22.0.0/24,.example.com"

# The default installer timeouts for the bootstrap and install processes may be too short for some baremetal
# deployments. The variables below can be used to extend those timeouts.

# (Optional) Increase bootstrap process timeout by N iterations.
#increase_bootstrap_timeout=2

# (Optional) Increase install process timeout by N iterations.
#increase_install_timeout=2

######################################
# Vars regarding install-config.yaml #
######################################

# Base domain, i.e. example.com
domain="myocp4.com"
# Name of the cluster, i.e. openshift
cluster="test"
# Note: Under some conditions, it may be useful to randomize the cluster name. For instance,
# when redeploying an existing environment this can help avoid VRID conflicts. You can
# set the cluster_random boolean below to true to append a random number to you cluster name.
cluster_random=true
# The public CIDR address, i.e. 10.1.1.0/21
extcidrnet="192.168.222.0/24"

# NOTE: For the RH shared labs, the VIPs below are automated w/ variables
#       based on the extcidrnet above.

# An IP reserved on the baremetal network. 
dnsvip="{{ extcidrnet | next_nth_usable(2) }}"
# An IP reserved on the baremetal network for the API endpoint. 
# (Optional) If not set, a DNS lookup verifies that api.<clustername>.<domain> provides an IP
apivip="{{ extcidrnet | next_nth_usable(3) }}"
# An IP reserved on the baremetal network for the Ingress endpoint.
# (Optional) If not set, a DNS lookup verifies that *.apps.<clustername>.<domain> provides an IP
ingressvip="{{ extcidrnet | next_nth_usable(4) }}"
# The master hosts provisioning nic
# (Optional) If not set, the prov_nic will be used
#masters_prov_nic=""
# Network Type (OpenShiftSDN or OVNKubernetes). Playbook defaults to OVNKubernetes.
# Uncomment below for OpenShiftSDN
network_type="OpenShiftSDN"
# (Optional) A URL to override the default operating system image for the bootstrap node.
# The URL must contain a sha256 hash of the image.
# See https://github.com/openshift/installer/blob/master/docs/user/metal/customization_ipi.md
#   Example https://mirror.example.com/images/qemu.qcow2.gz?sha256=a07bd...
#bootstraposimage=""
# (Optional) A URL to override the default operating system image for the cluster nodes.
# The URL must contain a sha256 hash of the image.
# See https://github.com/openshift/installer/blob/master/docs/user/metal/customization_ipi.md
# Example https://mirror.example.com/images/metal.qcow2.gz?sha256=3b5a8...
#clusterosimage=""
#
# Registry Host
#   Define a host here to create or use a local copy of the installation registry
#   Used for disconnected installation
# [registry_host]
# disconnected.example.com

# [registry_host:vars]
# The following cert_* variables are needed to create the certificates
#   when creating a disconnected registry. They are not needed to use
#   an existing disconnected registry.
# cert_country=US  # two letters country
# cert_state=MyState
# cert_locality=MyCity
# cert_organization=MyCompany
# cert_organizational_unit=MyDepartment

# The port exposed on the disconnected registry host can be changed from
# the default 5000 to something else by changing the following variable.
# registry_port=5000

# The directory the mirrored registry files are written to can be modified from teh default /opt/registry by changing the following variable.
# registry_dir="/opt/registry"

# The following two variables must be set to use an existing disconnected registry.
#
# Specify a file that contains extra auth tokens to include in the
#   pull-secret if they are not already there.
# disconnected_registry_auths_file=/home/kni/mirror_auth.json

# Specify a file that contains the addition trust bundle and image
#   content sources for the local registry. The contents of this file
#   will be appended to the install-config.yml file.
# disconnected_registry_mirrors_file=/home/kni/ic-appends.yml
```

### The Ansible `playbook.yml`

The Ansible playbook connects to your provision host and runs through the `node-prep` role and the `installer` role. No modification of these roles  is necessary. All modifications of variables may be done within the `ansible-ipi-install/group_vars/all.yml` and `ansible-ipi-install/inventory/hosts` files. Please note that if the same variable is defined in `ansible-ipi-install/group_vars/all.yml` and `ansible-ipi-install/inventory/hosts`, the value in `ansible-ipi-install/group_vars/all.yml` will take precedence. A sample file for inventory is located at `ansible-ipi-install/inventory/hosts.sample`

Sample `playbook.yml`:

```yml
---
- name: IPI on Baremetal Installation Playbook -- Red Hat Shared Labs Edition
  hosts: localhost
  roles:
    - { role: bootstrap }

- hosts: provisioner
  roles:
    - { role: prepare-kni, ssh_path: /root/.ssh}

- hosts: localhost
  roles:
    - { role: add-provisioner }

- hosts: provisioner
  roles:
    - { role: network-discovery }
    - { role: set-deployment-facts }
    - { role: shared-labs-prep }
    - { role: node-prep }
    - { role: installer }
  environment:
    http_proxy: "{{ http_proxy }}"
    https_proxy: "{{ https_proxy }}"
    no_proxy: "{{ no_proxy_list }}"
```


### Running the `playbook.yml`

With the `playbook.yml` set and in-place, run the `playbook.yml`

```sh
$ ansible-playbook -i inventory/hosts playbook.yml
```

## Verifying Installation

Once the playbook has successfully completed, verify that your environment is up and running.

1. Log into the provisioner node (typically the first node in you lab assignment)

```sh
ssh kni@provisioner.example.com
```

2. Export the `kubeconfig` file located in the `~/clusterconfigs/auth` directory

```sh
export KUBECONFIG=~/clusterconfigs/auth/kubeconfig
```

3. Verify the nodes in the OpenShift cluster

```sh
[kni@provioner~]$ oc get nodes
NAME                                         STATUS   ROLES           AGE   VERSION
master-0.openshift.example.com               Ready    master          19h   v1.16.2
master-1.openshift.example.com               Ready    master          19h   v1.16.2
master-2.openshift.example.com               Ready    master          19h   v1.16.2
worker-0.openshift.example.com               Ready    worker          19h   v1.16.2
worker-1.openshift.example.com               Ready    worker          19h   v1.16.2
```
## Versions Tested
Deployment of OCP 4.3 and 4.4 has been tested with the playbook.

## Limitations
* Currently only tested in Scale Lab (adding support for ALIAS will require further minimal work)
* Tested only on Dell Servers (adding support for Supermicros will require further minimal work)
* Homogeneous hardware expected for masters and workers

## Additional Material/Advanced Usage
For additional reading material and advanced usage of all the options provided by `ansible-ipi-install/inventory/hosts.sample` please refer to [https://github.com/openshift-kni/baremetal-deploy/tree/master/ansible-ipi-install](https://github.com/openshift-kni/baremetal-deploy/tree/master/ansible-ipi-install) and [upstream docs]([https://openshift-kni.github.io/baremetal-deploy/](https://openshift-kni.github.io/baremetal-deploy/)). The playbook provided in this repo contantly aims to support everything supported [upstream](https://github.com/openshift-kni/baremetal-deploy/tree/master/ansible-ipi-install) which is made possible by the modular architecture of using upstream roles as is without change and only having extra roles that run before the upstream roles.
