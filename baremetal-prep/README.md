**Baremetal-prep.sh Usage Documentation**

**Purpose:**

Baremetal-prep.sh is a script designed to prepare a RHEL8 host for use as a bootstrap/provisioning node to deploy a IPI OpenShift cluster.

**What it does:**

Baremetal-prep.sh does the following to prepare a node:

- Installs required dependencies
- Enable firewalld and enables required ports
- Enables libvirt and configures the default libvirt storage pool
- Configures a provisioning bridge and baremetal bridge from the interfaces passed at runtime
- Will generate a install-config.yaml if requested at runtime
- Will generate a metal3-config.yaml if requested at runtime
- Will configure a disconnected repository if requested at runtime and update install-config.yaml

**Requirements for use:**

To use baremetal-prep.sh the system needs the following:

- RHEL8 entitled host
- Two network interfaces: one for provisioning and one for baremetal
- Should be run as a regular user that has sudo rights for everything
- Needs a pull-secret\{.json,.txt,\} file in regular user\'s home directory
- Needs a install-config.yaml file in regular users home directory if not generating install-config.yaml
- Requires a Ansible host inventory file in regular users home directory of generating install-config.yaml

**Usage:**

To use baremetal-prep.sh one simply needs to clone the repo down to the provisioning host. Then set the execute bit on baremetal-prep.sh. Then copy the hosts.sample file to hosts and update the information in the file according to the deployment environment.

There are currently 7 options that can be passed:

- -p \<nic\> (required) physical interface on host that will be used for provisioning bridge
- -b \<nic\> (required) physical interface on the host that will be used for the baremetal bride
- -c \<cache url\> (optional): default http://\<deploy host ip\>/images
- -r \<release\> (optional) : default 4.3.0-0.nightly-2019-12-09-035405
- -d (optional) will configure for a disconnected install
- -g (optional) will generate a install-config.yaml
- -m (optional) will generate a metal3-config.yaml

**Example:**

```bash
./baremetal-prep.sh
Usage:
         ./baremetal-prep.sh
           -p <provisioning interface>
           -b <baremetal interface>
           [-c <cache url>] : default http://10.19.140.64/images
           [-r <release>] : default 4.3.0-0.nightly-2019-12-09-035405
           [-d] (configure for disconnected)
           [-g] (generate install-config.yaml)
           [-m] (generate metal3-config.yaml)
Example: ./baremetal-prep.sh -p ens3 -b ens4 -d -g -m
```

**To Dos:**
