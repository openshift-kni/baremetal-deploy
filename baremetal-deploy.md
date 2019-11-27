**Baremetal-deploy.sh Usage Documentation**

**Purpose:**

Baremetal-deploy.sh is a script designed to prepare a RHEL8 host for use as a bootstrap/provisioning node to deploy a IPI OpenShift cluster.

**What it does:**

Baremetal-deploy.sh does the following to prepare a node:

- Installs required dependencies
- Disables selinux
- Configures the default libvirt storage pool
- Configures a provisioning bridge and baremetal bridge from the interfaces passed at runtime
- Will generate a install-config.yaml if requested at runtime
- Will generate a metal3-config.yaml if requested at runtime
- Will configure a disconnected repository if requested at runtime and update install-config.yaml

**Requirements for use:**

To use baremetal-prep.sh the system needs the following:

- RHEL8 entitled host
- Two network interfaces: one for provisioning and one for baremetal
- Should be run as a regular user that has sudo rights for everything
- Needs a pull-secret.json file regular users home directory
- Needs a install-config.yaml file in regular users home directory if not generating install-config.yaml
- Requires a Ansible host inventory file in regular users home directory of generating install-config.yaml

**Usage:**

There are currently 4 switches that can be passed:

- -p (required) physical interface on host that will be used for provisioning bridge
- -b (required) physical interface on the host that will be used for the baremetal bride
- -d (optional) will configure for a disconnected install
- -g (optional) will generate a install-config.yaml
- -m (optional) will generate a metal3-config.yaml

**Example:**

./baremetal-prep.sh

Usage: ./baremetal-prep.sh -p (provisioning interface) -b (baremetal interface) -d (configure for disconnected) -g (generate install-config.yaml) -m (generate metal3-config.yaml)

Example: ./baremetal-prep.sh -p ens3 -b ens4 -d -g -m

**To Dos:**
