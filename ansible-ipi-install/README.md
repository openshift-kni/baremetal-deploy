Table of contents
=================

<!--ts-->
   * [Introduction](#introduction)
   * [Prerequisites](#prerequisites)
   * [Tour of the Ansible Playbook](#tour-of-the-ansible-playbook)
   * [Running the Ansible Playbook](#running-the-ansible-playbook)
      * [The `ansible.cfg` file](#the-ansiblecfg-file)
      * [Copy local ssh key to provision node](#copy-local-ssh-key-to-provision-node)
      * [Modifying the `inventory/hosts` file](#modifying-the-inventoryhosts-file)
      * [The Ansible `playbook.yml`](#the-ansible-playbookyml)
      * [Adding Extra Configurations to the OpenShift Installer](#adding-extra-configurations-to-the-openshift-installer)
   * [Verifying Installation](#verifying-installation)
   * [Troubleshooting](#troubleshooting)
      * [Unreachable Host](#unreachable-host)
      * [Permission Denied Trying To Connect To Host](#permission-denied-trying-to-connect-to-host)
      * [Dig lookup requires the python 'dnspython' library and it is not installed](#dig-lookup-requires-the-python-dnspython-library-and-it-is-not-installed)
   * [Gotchas](#gotchas)
<!--te-->

# Introduction

This write-up will guide you through the process of using the Ansible playbooks
to deploy a Baremetal Installer Provisioned Infrastructure (IPI) of Red Hat
OpenShift 4.

For the manual details, visit our [Installation Guide](https://github.com/openshift-kni/baremetal-deploy/blob/master/install-steps.md)

# Prerequisites

* Best Practice Minimum Setup: 6 Physical servers (1 provision node, 3 master 
and 2 worker nodes)
* Minimum Setup: 4 Physical servers (1 provision node, 3 master nodes)
* Each server needs 2 NICs pre-configured. NIC1 for the private network and 
NIC2 for the external network. NIC interface names must be identical across all nodes. 
See [issue](https://github.com/openshift/installer/issues/2762)
* Each server should have a RAID-1 configured and initialized
* Each server must have IPMI configured
* Each server must have DHCP setup for external NICs
* Each server must have DNS setup for the API, wildcard applications
* A DNS VIP is IP on the `baremetal` network is required for reservation. 
Reservation is done via our DHCP server (though not required).  
* Optional - Include DNS entries for the external hostnames for each of the 
servers
* Download a copy of your [Pull secret](https://cloud.redhat.com/openshift/install/metal/user-provisioned)
* Append to the `pull-secret.txt` the [Pull secret](https://docs.google.com/document/d/1pWRtk7IbnfPo6cSDsopUMrxS22t3VJ2PuN39MJp9tHM/edit) 
with access to `registry.svc.ci.openshift.org` and `registry.redhat.io`


Due to the complexities of properly configuring an environment, it is 
recommended to review the following steps prior to running the Ansible playbook
as without proper setup, the Ansible playbook won't work.

The sections to review and ensure proper configuration are as follows:
* [Networking Requirements](https://github.com/openshift-kni/baremetal-deploy/blob/master/install-steps.md#networking-requirements)
* [Configuring Servers](https://github.com/openshift-kni/baremetal-deploy/blob/master/install-steps.md#configuring-servers)
* [Reserve IPs for the VIPs and Nodes](https://github.com/openshift-kni/baremetal-deploy/blob/master/install-steps.md#reserve-ips-for-the-vips-and-nodes)
* One of the Create DNS records sections
  * [Create DNS records on a DNS server (Option 1)](https://github.com/openshift-kni/baremetal-deploy/blob/master/install-steps.md#create-dns-records-on-a-dns-server-option-1)
  * [Create DNS records using dnsmasq (Option 2)](https://github.com/openshift-kni/baremetal-deploy/blob/master/install-steps.md#create-dns-records-using-dnsmasq-option-2)
* One of the Create DHCP reservation sections
  * [Create DHCP reservations (Option 1)](https://github.com/openshift-kni/baremetal-deploy/blob/master/install-steps.md#create-dhcp-reservations-option-1)
  * [Create DHCP reservations using dnsmasq (Option 2)](https://github.com/openshift-kni/baremetal-deploy/blob/master/install-steps.md#create-dhcp-reservations-using-dnsmasq-option-2)


Once the above is complete, the final step is to install Red Hat Enterprise Linux
(RHEL) 8.x on your provision node and create a user (i.e. `kni`) to deploy as
non-root and provide that user `sudo` privileges.

For simplicity, the steps to create the user named `kni` is as follows:
1. Login into the provision node via `ssh`
2. Create a user (i.e `kni`) to deploy as non-root and provide that user `sudo` privileges
    ~~~sh
    useradd kni
    passwd kni
    echo "kni ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/kni
    chmod 0440 /etc/sudoers.d/kni
    ~~~

# Tour of the Ansible Playbook

The `ansible-ipi` playbook consists of 2 main directories:

* `inventory` - contains the file `hosts.sample` that:
  * contains all the modifiable variables, their default values, and their definition. Some variables are empty ensuring user's give an explicit value.
  * the setting up of your provision node, master nodes, and worker nodes. Each section will require additional details (i.e. Management credentials).
* `roles` - contains two roles: `node-prep` and `installer`. `node-prep` handles
all the prerequisites that the provisioner node requires prior to running the 
installer. The `installer` role handles extracting the installer, setting up
the manifests, and running the Red Hat OpenShift installation. 

The tree structure is shown below:

~~~sh
├── ansible.cfg
├── inventory
│   └── hosts.sample
├── playbook.yml
└── roles
    ├── installer
    │   ├── defaults
    │   │   └── main.yml
    │   ├── files
    │   ├── handlers
    │   │   └── main.yml
    │   ├── meta
    │   │   └── main.yml
    │   ├── tasks
    │   │   ├── 10_get_oc.yml
    │   │   ├── 20_extract_installer.yml
    │   │   ├── 23_rhcos_image_paths.yml
    │   │   ├── 24_rhcos_image_cache.yml
    │   │   ├── 30_create_metal3.yml
    │   │   ├── 40_create_manifest.yml
    │   │   ├── 50_extramanifests.yml
    │   │   ├── 59_cleanup_bootstrap.yml
    │   │   ├── 60_deploy_ocp.yml
    │   │   ├── 70_cleanup_sub_man_registeration.yml
    │   │   └── main.yml
    │   ├── templates
    │   │   └── metal3-config.j2
    │   │   └── rhcos-image-md5sum.j2
    │   ├── tests
    │   │   ├── inventory
    │   │   └── test.yml
    │   └── vars
    │       └── main.yml
    └── node-prep
        ├── defaults
        │   └── main.yml
        ├── handlers
        │   └── main.yml
        ├── library
        │   └── nmcli.py
        ├── meta
        │   └── main.yml
        ├── tasks
        │   ├── 100_create-install-config.yml
        |   ├── 10_validation.yml
        │   ├── 110_power_off_cluster_servers.yml
        │   ├── 20_sub_man_register.yml
        │   ├── 30_req_packages.yml
        │   ├── 40_bridge.yml
        │   ├── 50_modify_sudo_user.yml
        │   ├── 60_enabled_services.yml
        │   ├── 70_enabled_fw_services.yml
        │   ├── 80_libvirt_pool.yml
        │   ├── 90_create_config_install_dirs.yml
        │   └── main.yml
        ├── templates
        │   ├── dir.xml.j2
        │   ├── install-config.j2
        │   └── pub_nic.j2
        ├── tests
        │   ├── inventory
        │   └── test.yml
        └── vars
            └── main.yml
~~~


# Running the Ansible Playbook

The following are the steps to successfully run the Ansible playbook. 

## The `ansible.cfg` file

While the `ansible.cfg` may vary upon your environment a sample is provided 
in the repository. 

~~~sh
$ cat ansible.cfg 
[defaults]
inventory=./inventory
remote_user=kni
callback_whitelist = profile_tasks

[privilege_escalation]
become_method=sudo
~~~

NOTE: Ensure to change the `remote_user` as deemed
appropriate for your environment. The `remote_user` is the user previously
created on the provision node. 

## Ansible version 

Ensure that your environment is using Ansible 2.9 or greater. The following
command can be used to verify.

~~~sh
ansible --version
ansible 2.9.1
  config file = /path/to/baremetal-deploy/ansible-ipi-install/ansible.cfg
  configured module search path = ['/home/rlopez/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3.7/site-packages/ansible
  executable location = /usr/bin/ansible
  python version = 3.7.2 (default, Jan 16 2019, 19:49:22) [GCC 8.2.1 20181215 (Red Hat 8.2.1-6)]
~~~

NOTE: The config file section should point to the path of your `ansible.cfg`

## Copy local ssh key to provision node

With the `ansible.cfg` file in place, the next step is to ensure to copy your
public `ssh` key to your provision node using `ssh-copy-id`.

~~~sh
$ ssh-copy-id <user>@provisioner.example.com
~~~

NOTE: <user> should be the user previously created on the provision node
(i.e. `kni`)

## Modifying the `inventory/hosts` file

The hosts file provides all the definable variables and provides a description
of each variable. Some of the variables are explicitly left empty and **require**
user input for the playbook to run. 

The hosts file also ensure to set up all your nodes that will be used to deploy
IPI on baremetal. There are 3 groups: `masters`, `workers`, and `provisioner`. 
The `masters` and `workers` group collects information about the host such as
its name, role, user management (i.e. iDRAC) user, user management (i.e. iDRAC)
password, ipmi_address to access the server and the provision mac address (NIC1)
that resides on the provisioning network. 

Below is a sample of the inventory/hosts file

~~~sh
[all:vars]

###############################################################################
# Required configuration variables for IPI on Baremetal Installations         #
###############################################################################

# The provisioning NIC (NIC1) used on all baremetal nodes
prov_nic=eno1

# The public NIC (NIC2) used on all baremetal nodes
pub_nic=eno2

# (Optional) Activation-key for proper setup of subscription-manager, empty value skips registration
#activation_key=""

# (Optional) Activation-key org_id for proper setup of subscription-manager, empty value skips registration
#org_id=""

# The directory used to store the cluster configuration files (install-config.yaml, pull-secret.txt, metal3-config.yaml)
dir="{{ ansible_user_dir }}/clusterconfigs"

# The version of the openshift-installer, undefined or empty results in the playbook failing with error message.
# Values accepted: 'latest-4.3', 'latest-4.4', explicit version i.e. 4.3.0-0.nightly-2019-12-09-035405
version=""

# Enter whether the build should use 'dev' (nightly builds) or 'ga' for Generally Available version of OpenShift
# Empty value results in playbook failing with error message.
build=""

# Provisioning IP address (default value)
prov_ip=172.22.0.3

######################################
# Vars regarding install-config.yaml #
######################################

# Base domain, i.e. example.com
domain=""
# Name of the cluster, i.e. openshift
cluster=""
# The public CIDR address, i.e. 10.1.1.0/21
extcidrnet=""
# An IP reserved on the baremetal network. 
dnsvip=""
# An IP reserved on the baremetal network for the API endpoint. 
# (Optional) If not set, a DNS lookup verifies that api.<clustername>.<domain> provides an IP
#apivip=""
# An IP reserved on the baremetal network for the Ingress endpoint.
# (Optional) If not set, a DNS lookup verifies that *.apps.<clustername>.<domain> provides an IP
#ingressvip=""
# Network Type (OpenShiftSDN or OVNKubernetes). Playbook defaults to OVNKubernetes.
# Uncomment below for OpenShiftSDN
#network_type="OpenShiftSDN"
# (Optional) An URL to override the default operating system image for the bootstrap node.
# The URL must contain a sha256 hash of the image.
# See https://github.com/openshift/installer/blob/master/docs/user/metal/customization_ipi.md
#   Example https://mirror.example.com/images/qemu.qcow2.gz?sha256=a07bd...
#bootstraposimage=""
# A copy of your pullsecret from https://cloud.redhat.com/openshift/install/metal/user-provisioned
pullsecret=""

# Master nodes
# The hardware_profile is used by the baremetal operator to match the hardware discovered on the host
# See https://github.com/metal3-io/baremetal-operator/blob/master/docs/api.md#baremetalhost-status
[masters]
master-0 name=master-0 role=master ipmi_user=admin ipmi_password=password ipmi_address=192.168.1.1 provision_mac=ec:f4:bb:da:0c:58 hardware_profile=default
master-1 name=master-1 role=master ipmi_user=admin ipmi_password=password ipmi_address=192.168.1.2 provision_mac=ec:f4:bb:da:32:88 hardware_profile=default
master-2 name=master-2 role=master ipmi_user=admin ipmi_password=password ipmi_address=192.168.1.3 provision_mac=ec:f4:bb:da:0d:98 hardware_profile=default

# Worker nodes
[workers]
worker-0 name=worker-0 role=worker ipmi_user=admin ipmi_password=password ipmi_address=192.168.1.4 provision_mac=ec:f4:bb:da:0c:18 hardware_profile=unknown
worker-1 name=worker-1 role=worker ipmi_user=admin ipmi_password=password ipmi_address=192.168.1.5 provision_mac=ec:f4:bb:da:32:28 hardware_profile=unknown

# Provision Host
[provisioner]
provisioner.example.com
~~~

NOTE: The `ipmi_address` can take a fully qualified name assuming it is 
resolvable.

NOTE: A detailed description of the vars under the section 
`Vars regarding install-config.yaml` 
may be reviewed within  
[Configure the install-config and metal3-config](https://github.com/openshift-kni/baremetal-deploy/blob/master/install-steps.md#configure-the-install-config-and-metal3-config)
if unsure how to populate. 

WARNING: If no `workers` are included, do not remove the workers group 
(`[workers]`) as it is required to properly build the `install-config.yaml` file.

## The Ansible `playbook.yml`

The Ansible playbook connects to your provision host and runs through the
`node-prep` role and the `installer` role. No modification is necessary. All
modifications of variables may be done within the `inventory/hosts` file. A
sample file is located in this repository under `inventory/hosts.sample`. 

Sample playbook.yml
~~~sh
---
- name: IPI on Baremetal Installation Playbook
  hosts: provisioner
  roles:
  - node-prep
  - installer
~~~

## Customizing the Node Filesystems
If you need to modify files on the node filesystems, you can augment the "fake"
roots for the masters and workers under the 
`roles/installer/files/customize_filesystem/{master,worker}` directories. 
Any files added here will be included in the ignition config files for each
of the machine types, leading to permanent changes to the node filesystem.

NOTE: Do not place any files directly in the "fake" root -- only in subdirectories.
Files in the root will cause the ignition process to fail. (There is a task in the 
playbook to cleanup the `.gitkeep` file in the root, if it is left in place.)

This will utilize the Ignition 
[filetranspiler tool](https://github.com/ashcrow/filetranspiler/blob/master/filetranspile), 
which you can read about for more information on how to use the "fake" root directories.

An example of using this customization is to disable a network interface that
you need to not receive a DHCP assignment that is outside of the cluster
configuration. To do this for the `eno1` interface on the master nodes, create
the appropriate `etc/sysconfig/network-scripts/ifcfg-eno1` file in the "fake" root:

~~~sh
IFCFG_DIR="roles/installer/files/customize_filesystem/master/etc/sysconfig/network-scripts"
IFNAME="eno1"
mkdir -p $IFCFG_DIR
cat << EOF > $IFCFG_DIR/ifcfg-${IFNAME}
DEVICE=${IFNAME}
BOOTPROTO=none
ONBOOT=no
EOF
~~~

NOTE: By default these directories are empty, and the `worker` subdirectory is a
symbolic link to the `master` subdirectory so that changes are universal.

## Adding Extra Configurations to the OpenShift Installer
Prior to the installation of Red Hat OpenShift, you may want to include
additional configuration files to be included during the installation. The
`installer` role handles this. 

In order to include the extraconfigs, ensure to place your `yaml` files within
the `roles/installer/files/manifests` directory. All the files provided here will be
included when the OpenShift manifests are created. 

NOTE: By default this directory is empty. 

## Pre-caching RHCOS Images
If you wish to set up a local cache of RHCOS images on your provisioning host,
set the `cache_enabled` variable to `True` in your hosts file (make sure you use
`True` and not `true`).  When requested, the playbook will pre-download RHCOS 
images prior to actual cluster deployment.  It places these images in an Apache 
web server container on the provisioning host and modifies `install-config.yaml` 
to instruct the bootstrap to download the images from that web server during 
deployment.  

NOTE: If you set the `clusterOSImage` and `bootstrapOSImage` variables, then
`cache_enabled` will automatically be set to `False`, since the combined  
presence of these values indicates that your RHCOS images are already available
elsewhere.

## Running the `playbook.yml`

With the `playbook.yml` set and in-place, run the `playbook.yml`

~~~sh
$ ansible-playbook -i inventory/hosts playbook.yml
~~~

# Verifying Installation
Once the playbook has successfully completed, verify that your environment is
up and running.

1. Log into the provision node 
~~~sh
ssh kni@provisioner.example.com
~~~
NOTE: `kni` user is my privileged user. 
2. Export the `kubeconfig` file located in the `~/clusterconfigs/auth` directory
~~~sh
export KUBECONFIG=~/clusterconfigs/auth/kubeconfig
~~~
3. Verify the nodes in the OpenShift cluster
~~~sh
[kni@worker-0 ~]$ oc get nodes
NAME                                         STATUS   ROLES           AGE   VERSION
master-0.openshift.example.com               Ready    master          19h   v1.16.2
master-1.openshift.example.com               Ready    master          19h   v1.16.2
master-2.openshift.example.com               Ready    master          19h   v1.16.2
worker-0.openshift.example.com               Ready    worker          19h   v1.16.2
worker-1.openshift.example.com               Ready    worker          19h   v1.16.2
~~~


# Troubleshooting

The following section troubleshoots common errors that may arise when running
the Ansible playbook. 


## Unreachable Host

One of the most common errors is not being able to reach the provisioner host
and seeing an error similar to

~~~sh
$ ansible-playbook -i inventory/hosts playbook.yml 

PLAY [IPI on Baremetal Installation Playbook] **********************************

TASK [Gathering Facts] *********************************************************
fatal: [provisioner.example.com]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh: ssh: Could not resolve hostname provisioner.example.com: Name or service not known", "unreachable": true}

PLAY RECAP *********************************************************************
provisioner.example.com    : ok=0    changed=0    unreachable=1    failed=0    skipped=0    rescued=0    ignored=0   
~~~

In order to solve this issue, ensure your provisioner hostname is pingable. 

1. The system you are currently on can `ping` the provisioner.example.com
~~~sh
ping provisioner.example.com
~~~
2. Once pingable, ensure that you have copied your public ssh key from
your local system to the privileged user via the `ssh-copy-id` command.
~~~sh
ssh-copy-id kni@provisioner.example.com
~~~
NOTE: When prompted, enter the password of your privileged user (i.e. `kni`).
3. Verify connectivity using the `ping` module in Ansible
~~~sh
ansible -i inventory/hosts provisioner -m ping
provisioner.example.com | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
}
~~~
4. Re-run the Ansible playbook
~~~sh
$ ansible-playbook -i inventory/hosts playbook.yml 
~~~

## Permission Denied Trying To Connect To Host

Another very common error is getting a permission denied error similar to:

~~~sh
$ ansible-playbook -i inventory/hosts playbook.yml 

PLAY [IPI on Baremetal Installation Playbook] *****************************************************************************************************

TASK [Gathering Facts] ****************************************************************************************************************************
fatal: [provisioner.example.com]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh: rlopez@provisioner.example.com: Permission denied (publickey,gssapi-keyex,gssapi-with-mic,password).", "unreachable": true}

PLAY RECAP ****************************************************************************************************************************************
provisioner.example.com : ok=0    changed=0    unreachable=1    failed=0    skipped=0    rescued=0    ignored=0   
~~~

The above issue is typically related to a problem with
your `ansible.cfg` file. Either it does not exist, has errors inside it, or you
have not copied your ssh public key onto the provisioner.example.com system. If
you notice closely, the Ansible playbook attempted to use my `rlopez` user instead
of my `kni` user since my local `ansible.cfg` did not exist **AND** I had not yet
set the `remote_user` parameter to `kni` (my privileged user).

1. When working with the Ansible playbook ensure you have an `ansible.cfg` 
located in the same directory as your `playbook.yml` file. The contents of the
`ansible.cfg` should look similar to the below with the exception of changing
your inventory path (location of `inventory` dir) and potentially your
privileged user if not using `kni`. 
~~~sh
$ cat ansible.cfg 
[defaults]
inventory=/path/to/baremetal-deploy/ansible-ipi-install/inventory
remote_user=kni

[privilege_escalation]
become=true
become_method=sudo
~~~
2. Next, ensure that you have copied your public ssh key from
your local system to the privileged user via the `ssh-copy-id` command.
~~~sh
ssh-copy-id kni@provisioner.example.com
~~~
NOTE: When prompted, enter the password of your privileged user (i.e. `kni`).
3. Verify connectivity using the `ping` module in Ansible
~~~sh
ansible -i inventory/hosts provisioner -m ping
provisioner.example.com | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
}
~~~
4. Re-run the Ansible playbook
~~~sh
$ ansible-playbook -i inventory/hosts playbook.yml 
~~~

## Dig lookup requires the python 'dnspython' library and it is not installed

One of the tasks in the `node-prep` role captures your API VIP and the Ingress
VIP of your environment using a `lookup` via `dig`. It does this 
[DNS query using the `dnspython` library](https://docs.ansible.com/ansible/latest/plugins/lookup/dig.html). 
This error is a little deceiving because the the `dnspython` package does 
**not need to be installed on the remote server** (i.e. provisioner.example.com) 
but the package must be **installed on your local host** that is running the 
Ansible playbook. 

~~~sh
TASK [node-prep : fail] ************************************************************************************************************
skipping: [provisioner.example.com]

TASK [node-prep : Verify DNS records for API VIP, Wildcard (Ingress) VIP] **********************************************************
fatal: [provisioner.example.com]: FAILED! => {"msg": "An unhandled exception occurred while running the lookup plugin 'dig'. Error was a <class 'ansible.errors.AnsibleError'>, original message: The dig lookup requires the python 'dnspython' library and it is not installed"}

PLAY RECAP *************************************************************************************************************************
provisioner.example.com : ok=2    changed=0    unreachable=0    failed=1    skipped=3    rescued=0    ignored=0 
~~~

The above issue can be fixed by simply installing `python3-dns` on your local
system (assuming your using an OS such as Fedora, Red Hat)

On a local host running Red Hat 7.x, run: 
~~~sh
# sudo yum install python3-dns
~~~

On a local host running Red Hat 8.x, run: 
~~~sh
# sudo dnf install python3-dns
~~~

On a local host running Fedora, run: 
~~~sh
# sudo dnf install python3-dns
~~~

Re-run the Ansible playbook
~~~sh
$ ansible-playbook -i inventory/hosts playbook.yml 
~~~

## Gotchas

### Using become: yes within ansible.cfg or inside playbook.yml 

This Ansible playbook takes advantage of the `ansible_user_dir` variable. As 
such, it is important to note that if within your `ansible.cfg` or within
the `playbook.yml` file the privilege escalation of `become: yes` is used, this
will modify the home directory to that of the root user (i.e. `/root`) instead
of using the home directory of your privileged user, `kni` with a home dir of
`/home/kni`



