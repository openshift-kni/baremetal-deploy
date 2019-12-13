# Introduction

This write-up will guide you through the process of deploying a Baremetal IPI installation of Red Hat OpenShift 4.
# Prerequisites

* 6 Physical servers (1 provision node, 3 master and 2 worker nodes)
* Each server needs 2 NICs pre-configured. NIC1 for the private network and NIC2 for the external network. NIC interface names need to be identical. See [issue](https://github.com/openshift/installer/issues/2762)
* Each server should have a RAID-1 configured and initialized
* Each server must have IPMI configured
* Each server must have DHCP setup for external NICs
* Each server must have DNS setup for the API, wildcard applications
* A DNS VIP is IP on the `baremetal` network is required for reservation. Reservation is done via our DHCP server (though not required).  
* Optional - Include DNS entries for the external hostnames for each of the servers
* Download a copy of your [Pull secret](https://cloud.redhat.com/openshift/install/metal/user-provisioned)
* Append to the `pull-secret.txt` the [Pull secret](https://docs.google.com/document/d/1pWRtk7IbnfPo6cSDsopUMrxS22t3VJ2PuN39MJp9tHM/edit) with access to `registry.svc.ci.openshift.org` and `registry.redhat.io`

## Networking Requirements

### NIC Configuration

Each server requires two NICs for `provisioning` and `baremetal` network access 
respectively. The `provisioning` network is a non-routable network used
for provisioning the underlying operating system on each server that are part
of the Red Hat OpenShift cluster. The `baremetal` network is a routable network
used for external network access to the outside world. 

NOTE: It is recommended that each NIC be on a separate VLAN. 

### Network Ranges

The `provisioning` network is automatically assigned and configured using the
`172.22.0.0/24` range. The `baremetal` (external) network assignment is to be provided
by your network administrator. It is required that each server be assigned a 
external IP address via a DHCP server. 

NOTE: Since the Red Hat OpenShift installation uses `ironic-dnsmasq` it is 
important that no other DHCP server is running on the same broadcast domain.

### Reserved IPs on DHCP Server

Each server must have an IP reserved on the `baremetal` network. Additionally,
3 additional IPs on the `baremetal` network are required for reservation. 

* 1 IP for the API endpoint
* 1 IP for the wildcard ingress endpoint
* 1 IP for the name server

The following table shows a list of all items that require a reserved IP address
on the `baremetal` network. Ensure a DHCP entry for each item listed on the
table below is reserved and allocated at all times. Examples on using `dnsmasq`
or a proper DHCP server to allocate these entries is shown later in this
document. 


| Usage   |      Hostname      |  IP |
|----------|-------------|------|
| API | api.\<cluster-name\>.\<domain\> | \<ip\> |
| Ingress LB (apps) |  *.apps.\<cluster-name\>.\<domain\>  | \<ip\> |
| Nameserver | ns1.\<cluster-name\>.\<domain\> | \<ip\> |
| Provisioning node | provisioner.\<cluster-name\>.<domain\> | \<ip\> |
| Master-0 | \<cluster-name\>-master-0.<domain\> | \<ip\> |
| Master-1 | \<cluster-name\>-master-1.<domain\> | \<ip\> |
| Master-2 | \<cluster-name\>-master-2.<domain\> | \<ip\> |
| Worker-0 | \<cluster-name\>-worker-0.<domain\> | \<ip\> |
| Worker-1 | \<cluster-name\>-worker-1.<domain\> | \<ip\> |

### DNS Server

A subzone is required on the \<domain\> that is to be used. The subzone name
is recommended to be the \<cluster-name\> as shown in the table above. Examples
on using `dnsmasq` or a proper DNS server to allocate these DNS resolution entries
is shown later in this document. 

<!--

TODO
### Diagram 

![Network Diagram](diagrams/bos-server-net.png)
-->
# Installation Flow

1. Installation of RHEL 8.1 on one of the 6 servers to be used as our provisioning node
2. (Option 1) Configuration of DNS and DHCP entries
3. (Option 2) Configuration of DNS and DHCP entries using `dnsmasq`
4. Provisioning node to provision a 3 master, 2 worker Red Hat OpenShift cluster
5. Once the cluster is up and running, re-provision the provisioning node as a worker node (worker-2) using `ironic`

# Configuring Servers

Each server requires the following configuration for proper installation. 

WARNING: A mismatch between servers will cause an installation failure.

While the servers that are used in your environment may contain additional
NICs. For the purposes of installation, we are only focused on the following: 

| NIC   | NETWORK | VLAN |
|----------|-------------|------|
| NIC1 | `provisioning`| \<provisioning-vlan\> |
| NIC2 | `baremetal`| \<baremetal-vlan\> |

While installation of RHEL 8.1 on the **provisioning** node will vary within
environments, the reasoning
for NIC2 to have PXE-enabled is to ensure easily installation using a local
satellite server. As mentioned prior, NIC1 is a non-routable network (`provisioning`)
that is only to be used for the installation of the Red Hat OpenShift cluster.

| PXE | Boot Order |
|----------|-------|
| NIC1 PXE-enabled (`provisioning` network) | 1 |
| NIC2 PXE-enabled (`baremetal` network) | 2 |

NOTE: PXE has been disabled on all other NICs.

The **master** and **worker** nodes have been configured as follows:

| PXE | Boot Order |
|----------|-------|
| NIC1 PXE-enabled (`provisioning` network) | 1 |

NOTE: PXE has been disabled on all other NICs.

## Out of Band Management

Each server is required to have access to out of band management. The
provisioning node will require access to the out of band management network for
a successful OpenShift 4 installation. The out of band management setup is
out of scope for this document, however, it is recommended that a separate 
management network be created for best practices. This is not applicable, using
either the `provisioning` network or `baremetal` network are other options as
well. 

## Required Data for Installation

Prior to the installation of the Red Hat OpenShift cluster, it is required to
gather the following information from **all** servers. The list includes:

* Out-of-Band Management IP
    * Examples
        * Dell (iDRAC) IP
        * HP (iLO) IP
* NIC1 (`provisioning`) MAC address
* NIC2 (`baremetal`) MAC address

# Reserve IPs for the VIPs and Nodes

Previously, it was mentioned we would need the following IP address reserved
on the `baremetal` network. The list included:

* IP for the api endpoint
* IP for the wildcard ingress endpoint
* IP for the nameserver
* IP for each node 

The total amount of IPs required for reservation is 9 - 6 IPs for the nodes
and 3 IPs for the API, wildcard ingress endpoint and the nameserver. It is
important to contact your network administrator to reserve these nine IPs to 
ensure no conflict on the network. 

# Create DNS records on a DNS server (Option 1)

Option 1 should be used if access to the appropriate DNS server for the `baremetal`
network is accessible or a request to your network admin to create the DNS records
is an option. If not an option, skip this section and move to section Create
DNS records using `dnsmasq` (Option 2).

First, create a subzone with the name of the cluster that is going to be used on
your domain. For clarity in the example, the domain used is `example.com` and the
cluster name used is `openshift`. Ensure to change these according to your 
environment specifics. 

1. Login to the DNS server via `ssh`
2. Suspend updates to all dynamic zones: `rndc freeze`
3. Edit /var/named/dynamic/example.com

    ~~~
    $ORIGIN openshift.example.com.
    $TTL 300        ; 5 minutes
    @  IN  SOA  dns1.example.com.  hostmaster.example.com. (
           2001062501  ; serial
           21600       ; refresh after 6 hours
           3600        ; retry after 1 hour
           604800      ; expire after 1 week
           86400 )     ; minimum TTL of 1 day
    ;
    api                     A       <api-ip>
    ns1                     A       <dns-vip-ip>
    $ORIGIN apps.openshift.example.com.
    *                       A       <wildcard-ingress-lb-ip>
    $ORIGIN openshift.example.com.
    provisioner             A       <NIC2-ip-of-provision>
    openshift-master-0      A       <NIC2-ip-of-master-0>
    openshift-master-1      A       <NIC2-ip-of-master-1>
    openshift-master-2      A       <NIC2-ip-of-master-2>
    openshift-worker-0      A       <NIC2-ip-of-worker-0>
    openshift-worker-1      A       <NIC2-ip-of-worker-1>
    ~~~
4. Increase the SERIAL value by 1
5. Edit /var/named/dynamic/1.0.10.in-addr.arpa

    ~~~
    $ORIGIN 1.0.10.in-addr.arpa.
    $TTL 300
    @  IN  SOA  dns1.example.com.  hostmaster.example.com. (
           2001062501  ; serial
           21600       ; refresh after 6 hours
           3600        ; retry after 1 hour
           604800      ; expire after 1 week
           86400 )     ; minimum TTL of 1 day
    ;
    126 IN      PTR      provisioner.openshift.example.com.
    127	IN 	PTR	openshift-master-0.openshift.example.com.
    128	IN 	PTR	openshift-master-1.openshift.example.com.
    129	IN 	PTR	openshift-master-2.openshift.example.com.
    130	IN 	PTR	openshift-worker-0.openshift.example.com.
    131	IN 	PTR	openshift-worker-1.openshift.example.com.
    132 IN      PTR     api.openshift.example.com.
    133 IN      PTR     ns1.openshift.example.com.
    ~~~
    
    NOTE: In this example IP address `10.0.1.126-133` are pointed to the
    correspoding fully qualified domain name. 
    
    NOTE: The filename `1.0.10.in-addr.arpa` is the reverse of the public CIDR example `10.0.1.0/24`
    
6. Increase the SERIAL value by 1
7. Enable updates to all dynamic zones and reload them: `rndc thaw`

# Create DNS records using `dnsmasq` (Option 2)

For creating DNS records simply open the `/etc/hosts` file and add the NIC2 
(baremetal net) IP followed by the hostname. For example purposes, the cluster
name is `openshift` and the domain is `example.com`

~~~sh
cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
<NIC2-IP> provisioner.openshift.example.com provisioner
<NIC2-IP> openshift-master-0.openshift.example.com openshift-master-0
<NIC2-IP> openshift-master-1.openshift.example.com openshift-master-1
<NIC2-IP> openshift-master-2.openshift.example.com openshift-master-2
<NIC2-IP> openshift-worker-0.openshift.example.com openshift-worker-0
<NIC2-IP> openshift-worker-1.openshift.example.com openshift-worker-1
<API-IP>  api.openshift.example.com api
<DNS-VIP-IP> ns1.openshift.example.com ns1
~~~

# Create DHCP reservations (Option 1)

Option 1 should be used if access to the appropriate DHCP server for the `baremetal`
network is accessible or a request to your network admin to create the DHCP 
reserverations
is an option. If not an option, skip this section and move to section Create
DHCP reserverations using `dnsmasq` (Option 2).

1. Login to the DHCP server via `ssh`
2. Edit /etc/dhcp/dhcpd.hosts

    ~~~
    host provisioner {
         option host-name "provisioner";
         hardware ethernet <mac-address-of-NIC2>;
         option domain-search "openshift.example.com";
         fixed-address <ip-address-of-NIC2>;
      }
    host openshift-master-0 {
         option host-name "master-0";
         hardware ethernet <mac-address-of-NIC2>;
         option domain-search "openshift.example.com";
         fixed-address <ip-address-of-NIC2>;
      }
    
    host openshift-master-1 {
         option host-name "master-1";
         hardware ethernet <mac-address-of-NIC2>;
         option domain-search "openshift.example.com";
         fixed-address <ip-address-of-NIC2>;
      }
    
    host openshift-master-2 {
         option host-name "master-2";
         hardware ethernet <mac-address-of-NIC2>;
         option domain-search "openshift.example.com";
         fixed-address <ip-address-of-NIC2>;
      }
    host openshift-worker-0 {
         option host-name "worker-0";
         hardware ethernet <mac-address-of-NIC2>;
         option domain-search "openshift.example.com";
         fixed-address <ip-address-of-NIC2>;
      }
    host openshift-worker-1 {
         option host-name "worker-1";
         hardware ethernet <mac-address-of-NIC2>;
         option domain-search "openshift.example.com";
         fixed-address <ip-address-of-NIC2>;
      }
    ~~~
3. Restart dhcpd service: 
   ~~~
   systemctl restart dhcpd
   ~~~
 

# Create DHCP reservations using `dnsmasq` (Option 2)


The following is an example setup of `dnsmasq` on a server that can access
the `baremetal` network. 

1. Install `dnsmasq`
   ~~~sh
   dnf install -y dnsmasq
   ~~~
2. Change to the `/etc/dnsmasq.d` directory
   ~~~sh
   cd /etc/dnsmasq.d
   ~~~
3. Create a file that reflects your OpenShift cluster appended by `.dns` (e.g. example.dns)
   ~~~sh 
   touch example.dns
   ~~~
4. Example of the `example.dns` file
   ~~~sh
   domain-needed
   bind-dynamic
   bogus-priv
   domain=rna1.cloud.lab.eng.bos.redhat.com
   dhcp-range=<baremetal-net-starting-ip,baremetal-net-ending-ip>
   #dhcp-range=10.0.1.4,10.0.14
   dhcp-option=3,<baremetal-net-gateway-ip>
   #dhcp-option=3,10.0.1.254
   resolv-file=/etc/resolv.conf.upstream
   interface=<nic-with-access-to-baremetal-net>
   #interface=em2
   server=<ip-of-existing-server-on-baremetal-net>
  

   #Wildcard for apps -- make changes to cluster-name (openshift) and domain (example.com)
   address=/.apps.openshift.example.com/<wildcard-ingress-lb-ip>

   #Static IPs for Masters
   dhcp-host=<NIC2-mac-address>,provisioner.openshift.example.com,<ip-of-provisioner>
   dhcp-host=<NIC2-mac-address>,openshift-master-0.openshift.example.com,<ip-of-master-0>
   dhcp-host=<NIC2-mac-address>,openshift-master-1.openshift.example.com,<ip-of-master-1>
   dhcp-host=<NIC2-mac-address>,openshift-master-2.openshift.example.com,<ip-of-master-2>
   dhcp-host=<NIC2-mac-address>,openshift-worker-0.openshift.example.com,<ip-of-worker-0>
   dhcp-host=<NIC2-mac-address>,openshift-worker-1.openshift.example.com,<ip-of-worker-1>
   ~~~
5. Create the `resolv.conf.upstream` file in order to provide DNS fowarding to an existing DNS server for resolution to the outside world.
   ~~~sh
   search <domain.com>
   nameserver <ip-of-my-existing-dns-nameserver>
   ~~~
6. Restart the `dnsmasq` service 
   ~~~sh
   systemctl restart dnsmasq
   ~~~
7. Verify the `dnsmasq` service is running.
   ~~~sh
   systemctl status dnsmasq
   ~~~

# Install RHEL on the Provision Node

With the networking portions complete, the next step in installing the 
Red Hat OpenShift (OCP) cluster is to install RHEL 8
on the provision node. This node will be used as the orchestrator in installing
the OCP cluster on the 3 master and 2 worker nodes. For the purposes of this
document, installing RHEL on the provision node is out of scope. However, options
include, but not limited to, using a RHEL Satellite server, PXE, or installation
media. 

# Preparing the Provision node for OpenShift Install

The following steps need to be performed in order to prepare the environment. 

1. Login into the provision node via `ssh`
2. Create a user (i.e `kni`) to deploy as non-root and provide that user `sudo` privileges
    ~~~sh
    useradd kni
    echo "kni ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/kni
    chmod 0440 /etc/sudoers.d/kni
4. Create an `ssh` key for the new user (i.e. `kni`)
    ~~~sh
    su - kni -c "ssh-keygen -t rsa -f /home/kni/.ssh/id_rsa -N ''"
    ~~~
5. Register your environment using `subscription-manager`
   ~~~sh
   subscription-manager register --username=<user> --password=<pass>
   subscription-manager repos --enable=rhel-8-for-x86_64-appstream-rpms --enable=rhel-8-for-x86_64-baseos-rpms
   ~~~
6. Install the following packages 
   ~~~sh
   dnf install -y libvirt qemu-kvm mkisofs python3-devel jq ipmitool
   ~~~
7. Modify the user to add the `libvirt` group to the newly created user (i.e. `kni`)
   ~~~sh
   usermod --append --groups libvirt <user> 
   ~~~
8. Start `firewalld`, enable the `http` service, enable port 5000.
   ~~~sh
   systemctl start firewalld
   firewall-cmd --zone=public --add-service=http --permanent
   firewall-cmd --add-port=5000/tcp --zone=libvirt  --permanent
   firewall-cmd --add-port=5000/tcp --zone=public   --permanent
   firewall-cmd --reload
   ~~~
9. Start and enable the `libvirtd` service
   ~~~sh
   systemctl start libvirtd
   systemctl enable libvirtd --now
   ~~~
10. Create the `default` storage pool and start it.
   ~~~sh
   virsh pool-define-as --name default --type dir --target /var/lib/libvirt/images
   virsh pool-start default
   virsh pool-autostart default
   ~~~
11. Configure networking (this step can also be run from the console)
    ~~~sh
    # You will be disconnected, but reconnect via your ssh session after running
    export PUB_CONN=<baremetal_nic_name>
    export PROV_CONN=<prov_nic_name>
    nmcli con delete "$PROV_CONN"
    nmcli con delete "$PUB_CONN"
    # RHEL 8.1 appends the word "System" in front of the connection, delete in case it exists
    nmcli con delete "System $PUB_CONN"
    nmcli connection add ifname provisioning type bridge con-name provisioning
    nmcli con add type bridge-slave ifname "$PROV_CONN" master provisioning
    nmcli connection add ifname baremetal type bridge con-name baremetal
    nmcli con add type bridge-slave ifname "$PUB_CONN" master baremetal
    nmcli con down "$PUB_CONN";pkill dhclient;dhclient baremetal
    nmcli connection modify provisioning ipv4.addresses 172.22.0.1/24 ipv4.method manual
    nmcli con down provisioning
    nmcli con up provisioning
    ~~~
<!--
    nmcli con add type bridge ifname provisioning autoconnect yes con-name provisioning stp off
    nmcli con modify provisioning ipv4.addresses 172.22.0.1/24 ipv4.method manual
    nmcli con add type bridge-slave autoconnect yes con-name "$PROV_CONN" ifname "$PROV_CONN" master provisioning
    nmcli con delete "$PUB_CONN"
    nmcli con add type bridge ifname baremetal autoconnect yes con-name baremetal stp off
    nmcli con add type bridge-slave autoconnect yes con-name "$PUB_CONN" ifname "$PUB_CONN" master baremetal
    systemctl restart NetworkManager
    systemctl restart libvirtd
-->
12. `ssh` back into your terminal session (if required)
13. Verify the connection bridges have been properly created
    ~~~sh
    nmcli con show
    NAME               UUID                                  TYPE      DEVICE       
    baremetal          4d5133a5-8351-4bb9-bfd4-3af264801530  bridge    baremetal    
    provisioning       43942805-017f-4d7d-a2c2-7cb3324482ed  bridge    provisioning 
    virbr0             d9bca40f-eee1-410b-8879-a2d4bb0465e7  bridge    virbr0       
    bridge-slave-eno1  76a8ed50-c7e5-4999-b4f6-6d9014dd0812  ethernet  eno1         
    bridge-slave-eno2  f31c3353-54b7-48de-893a-02d2b34c4736  ethernet  eno2 
    ~~~
14. Login in as the new user on the provision node
    ~~~sh
    su - kni
    ~~~
15. Copy the pull secret (`pull-secret.txt`) generated earlier and place it in the provision node new user home directory
    

## Retrieving the OpenShift Installer

Two approaches:

1. Choose a successfully deployed release that passed CI
2. Deploy latest

### Choosing a OpenShift Installer Release from CI

1. Go to [https://openshift-release.svc.ci.openshift.org/](https://openshift-release.svc.ci.openshift.org/) and choose a release which has passed the tests for metal.
2. Save the release name. e.g: `4.3.0-0.nightly-2019-12-09-035405`
3. Configure VARS
    ~~~sh
    export VERSION="4.3.0-0.nightly-2019-12-09-035405"
    export RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/$VERSION/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}' | xargs)
    ~~~

### Choosing the latest OpenShift Installer

1. Configure VARS
    ~~~sh
    export VERSION=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest/release.txt | grep 'Name:' | awk -F: '{print $2}' | xargs)
    export RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}' | xargs)
    ~~~

### Extract the Installer

Once the installer has been chosen, the next step is to extract it. 

~~~sh
export cmd=openshift-baremetal-install
export pullsecret_file=~/pull-secret.txt
export extract_dir=$(pwd)
# Get the oc binary
curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/$VERSION/openshift-client-linux-$VERSION.tar.gz | tar zxvf - oc
# Extract the baremetal installer
./oc adm release extract --registry-config "${pullsecret_file}" --command=$cmd --to "${extract_dir}" ${RELEASE_IMAGE}
~~~

## Configure the install-config and metal3-config

1. Configure the `install-config.yaml` (Make sure you change the pullSecret and sshKey)
    ~~~yaml
    apiVersion: v1
    baseDomain: <domain>
    metadata:
      name: <cluster-name>
    networking:
      machineCIDR: <public-cidr>
    compute:
    - name: worker
      replicas: 2
    controlPlane:
      name: master
      replicas: 3
      platform:
        baremetal: {}
    platform:
      baremetal:
        apiVIP: <api-ip>
        ingressVIP: <wildcard-ip>
        dnsVIP: <dns-ip>
        provisioningBridge: provisioning
        externalBridge: baremetal
        hosts:
          - name: openshift-master-0
            role: master
            bmc:
              address: ipmi://<out-of-band-ip>
              username: <user>
              password: <password>
            bootMACAddress: <NIC1-mac-address>
            hardwareProfile: default
          - name: openshift-master-1
            role: master
            bmc:
              address: ipmi://<out-of-band-ip>
              username: <user>
              password: <password>
            bootMACAddress: <NIC1-mac-address>
            hardwareProfile: default
          - name: openshift-master-2
            role: master
            bmc:
              address: ipmi://<out-of-band-ip>
              username: <user>
              password: <password>
            bootMACAddress: <NIC1-mac-address
            hardwareProfile: default
          - name: openshift-worker-0
            role: worker
            bmc:
              address: ipmi://<out-of-band-ip>
              username: <user>
              password: <password>
            bootMACAddress: <NIC1-mac-address
            hardwareProfile: unknown
          - name: openshift-worker-1
            role: worker
            bmc:
              address: ipmi://<out-of-band-ip>
              username: <user>
              password: <password>
            bootMACAddress: <NIC1-mac-address
            hardwareProfile: unknown
    pullSecret: '<pull_secret>'
    sshKey: '<ssh_pub_key>'
    ~~~

NOTE: Ensure to change the appropriate variables to match your environment.

2. Create a directory to store cluster configs
    ~~~sh
    mkdir ~/clusterconfigs
    cp install-config.yaml ~/clusterconfigs
    ~~~

3. Ensure all baremetal nodes are powered off prior to installing the OpenShift cluster
   ~~~sh
   ipmitool -I lanplus -U <user> -P <password> -H <management-server-ip> power off
   ~~~

4. IMPORTANT: This portion is critical as the OpenShift installation won't complete without
the metal3-operator being fully operational. This is due to this 
[issue](https://github.com/openshift/installer/pull/2449) we need 
to fix the ConfigMap for the Metal3 operator. This ConfigMap is used to notify 
`ironic` how to PXE boot new nodes.
   
   Create the sample ConfigMap `metal3-config.yaml.sample`
   ~~~yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: metal3-config
      namespace: openshift-machine-api
    data:
      cache_url: ''
      deploy_kernel_url: http://172.22.0.3:6180/images/ironic-python-agent.kernel
      deploy_ramdisk_url: http://172.22.0.3:6180/images/ironic-python-agent.initramfs
      dhcp_range: 172.22.0.10,172.22.0.100
      http_port: "6180"
      ironic_endpoint: http://172.22.0.3:6385/v1/
      ironic_inspector_endpoint: http://172.22.0.3:5050/v1/
      provisioning_interface: <NIC1>
      provisioning_ip: 172.22.0.3/24
      rhcos_image_url: ${RHCOS_PATH}${RHCOS_URI}
    ~~~
    NOTE: The `provision_ip` should be modified to an available IP on the `provision` network. The default is `172.22.0.3`

5. Create the final ConfigMap
    ~~~sh
    export COMMIT_ID=$(./openshift-baremetal-install version | grep '^built from commit' | awk '{print $4}')
    export RHCOS_URI=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json | jq .images.openstack.path | sed 's/"//g')
    export RHCOS_PATH=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json | jq .baseURI | sed 's/"//g')
    envsubst < metal3-config.yaml.sample > metal3-config.yaml
    ~~~
6. Create the OpenShift manifests
   ~~~sh
   ./openshift-baremetal-install --dir ~/clusterconfigs create manifests
   INFO Consuming Install Config from target directory 
   WARNING Making control-plane schedulable by setting MastersSchedulable to true for Scheduler cluster settings 
   WARNING Discarding the Openshift Manifests that was provided in the target directory because its dependencies are dirty and it needs to be regenerated 
   ~~~
7. Copy the `metal3-config.yaml` to the `clusterconfigs/openshift` directory
   ~~~sh
   cp ~/metal3-config.yaml clusterconfigs/openshift/99_metal3-config.yaml
   ~~~

## Deploying Routers on Worker Nodes

During the installation of an OpenShift cluster, router pods are deployed on
worker nodes (default 2 router pods). In the event that an installation *only* 
has one worker node or additional routers are required in order to 
handle external traffic destined for services within your OpenShift cluster, 
the following `yaml` file can be 
created to set the appropriate amount of router replicas. 

NOTE: By default two routers are deployed. If you have two worker nodes 
already, this section may be skipped. For more info on ingress operator visit:
https://docs.openshift.com/container-platform/4.2/networking/ingress-operator.html

The `router-replicas.yaml` file

~~~yaml
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  name: default
  namespace: openshift-ingress-operator
spec:
  replicas: <num-of-router-pods>
  endpointPublishingStrategy:
    type: HostNetwork
  nodePlacement:
    nodeSelector:
      matchLabels:
        node-role.kubernetes.io/worker: ""
~~~

NOTE: If working with just one worker node, set this value
to one. If working with more than 3+ workers, additional router pods (default 2) 
may be recommended.

Once the `router-replicas.yaml` file has been saved, copy the file to the
`clusterconfigs/openshift` directory.

~~~sh
cp ~/router-replicas.yaml clusterconfigs/openshift/99_router-replicas.yaml
~~~

## Deploying the Cluster via the OpenShift Installer

Run the OpenShift Installer
~~~sh
./openshift-baremetal-install --dir ~/clusterconfigs --log-level debug create cluster
~~~

<!--
## Fix Metal3 ConfigMap

While the installation is on-going, when the API is up and available, with
output that looks like the following:

~~~sh
INFO API v1.16.2 up                               
INFO Waiting up to 30m0s for bootstrapping to complete... 
~~~

This
portion is critical as the OpenShift installation won't complete without the
metal3-operator being fully operational. This is due to this 
[issue](https://github.com/openshift/installer/pull/2449) we need 
to fix the ConfigMap for the Metal3 operator. This ConfigMap is used to notify 
`ironic` how to PXE boot new nodes.

1. Open a new terminal, and log into the provisioner node as the `kni` user. 
2. Create the sample ConfigMap `metal3-config.yaml.sample`
   ~~~yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: metal3-config
      namespace: openshift-machine-api
    data:
      cache_url: ''
      deploy_kernel_url: http://172.22.0.3:6180/images/ironic-python-agent.kernel
      deploy_ramdisk_url: http://172.22.0.3:6180/images/ironic-python-agent.initramfs
      dhcp_range: 172.22.0.10,172.22.0.100
      http_port: "6180"
      ironic_endpoint: http://172.22.0.3:6385/v1/
      ironic_inspector_endpoint: http://172.22.0.3:5050/v1/
      provisioning_interface: <NIC1>
      provisioning_ip: 172.22.0.3/24
      rhcos_image_url: ${RHCOS_PATH}${RHCOS_URI}
    ~~~
    NOTE: The `provision_ip` should be modified to an available IP on the `provision` network. The default is `172.22.0.3`

3. Create the final ConfigMap
    ~~~sh
    export COMMIT_ID=$(./openshift-baremetal-install version | grep '^built from commit' | awk '{print $4}')
    export RHCOS_URI=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json | jq .images.openstack.path | sed 's/"//g')
    export RHCOS_PATH=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json | jq .baseURI | sed 's/"//g')
    envsubst < metal3-config.yaml.sample > metal3-config.yaml
    ~~~
4. Load the ConfigMap
    ~~~sh
    export KUBECONFIG=~/clusterconfigs/auth/kubeconfig
    ./oc create -f metal3-config.yaml
    configmap/metal3-config created
    ~~~
   NOTE: If the following error is encountered, this means your cluster is not
   ready to apply the configuration due to the API not being up.
   ~~~sh
   error: unable to recognize "clusterconfigs/metal3-config.yaml": no matches for kind "ConfigMap" in version "v1"
   ~~~
   NOTE: If the following error is encountered, this means the installation as
   yet to create the `openshift-machine-api` namespace
   ~~~sh
   Error from server (NotFound): error when creating "clusterconfigs/metal3-config.yaml": namespaces "openshift-machine-api" not found
   ~~~

-->

## Backup Cluster Config

At this point you will have a working OpenShift 4 cluster on baremetal. In order
to take advantage of the baremetal hardware that was the provision node, we will
re-purpose the provisioning node as a worker. Prior to re-provisioning 
the node, it is recommended to backup some existing files.

~~~sh
# Tar the cluster configs folder and download it to your laptop
tar cvfz clusterconfig.tar.gz ~/clusterconfig
# Copy the Private part for the SSH Key configured on the install-config.yaml to your laptop
tar cvfz clusterconfigsh.tar.gz ~/.ssh/id_rsa*
# Copy the install-config.yaml and metal3-config.yaml 
tar cvfz yamlconfigs.tar.gz install-config.yaml metal3-config.yaml
~~~

# Preparing Provisioner Node to be Deployed as a Worker Node

Considerations prior to converting the provisioning node to a worker node.

1. `ssh` to a system (i.e. laptop) that can access the out of band management network of the current provisioner node
2. Copy the backups `clusterconfig.tar.gz` , `clusterconfigsh.tar.gz` , and `yamlconfigs.tar.gz` to the new system
3. Copy the `oc` binary from the existing provisioning node to the new system (i.e. laptop)
4. Make a note of the <NIC1> <NIC2> mac addresses, the `baremetal` network IP used for the provisioner node and IP address of the Out of band Management Network
5. Reboot the system and ensure that PXE is enabled on <NIC1> (`provisioning` network) and PXE is disabled for all other NICs
6. If installation was done via the use of a Satellite server, please remove the Host entry for the existing provisioning node
7. Within the new system (i.e. laptop) install the `ipmitool` in order to power off the provisioner node


## Append DNS Records for the worker-2 (old provisioner) on DNS Server (Option 1)

1. Login to the DNS server via `ssh`
2. Suspend updates to all dynamic zones: `rndc freeze`
3. Edit /var/named/dynamic/example.com

    ~~~
    $ORIGIN openshift.example.com.
    <OUTPUT_OMITTED>
    openshift-worker-1      A       <ip-of-worker-1>
    openshift-worker-2      A       <ip-of-worker-2>
    ~~~
    NOTE: Ensure to remove the provisioner as it is replaced by openshift-worker-2
    
4. Increase the SERIAL value by 1
5. Edit /var/named/dynamic/1.0.10.in-addr.arpa

    ~~~
    <OUTPUT_OMITTED>
    131	IN 	PTR	openshift-worker-1.openshift.example.com.
    126	IN 	PTR	openshift-worker-2.openshift.example.com.
    ~~~
    NOTE: The filename `1.0.10.in-addr.arpa` is the reverse of the public CIDR example `10.0.1.0/24`
    
6. Increase the SERIAL value by 1
7.  Enable updates to all dynamic zones and reload them: `rndc thaw`

## Append DNS Record for the worker-2 (old provisioner) using `dnsmasq` (Option 2)

Within the server hosting the `dnsmasq` service append the following DNS record
to the `/etc/hosts` file

~~~sh
<OUTPUT_OMITTED>
<NIC2-IP> openshift-worker-1.openshift.example.com openshift-worker-1
<NIC2-IP> openshift-worker-2.openshift.example.com openshift-worker-2
~~~

NOTE: Remove the provisioner.openshift.example.com entry as it is replaced by worker-2

## Create DHCP Reservations for worker-2 (old provisioner) on DHCP Server (Option 1)

1. Login into DHCP server via `ssh`
2. Edit /etc/dhcp/dhcpd.hosts

    ~~~
    host openshift-worker-2 {
         option host-name "worker-2";
         hardware ethernet <NIC2-mac-address>;
         option domain-search "openshift.example.com";
         fixed-address <ip-address-of-NIC2>;
      }
    ~~~
    NOTE: Remove the provisioner host entry as it is replaced by the openshift-worker-2
3. Restart `dhcpd` service: 
   ~~~sh
   systemctl restart dhcpd
   ~~~

## Create DHCP Reservations for worker-2 (old provisioner) using `dnsmasq` (Option 2) 

Within the server hosting the `dnsmasq` service append the following DHCP
reservation to the `/etc/dnsmasq.d/example.dns` file

~~~sh
<OUTPUT_OMITTED>
dhcp-host=<NIC2-mac-address>,openshift-worker-1.openshift.example.com,<ip-of-worker-1>
dhcp-host=<NIC2-mac-address>,openshift-worker-2.openshift.example.com,<ip-of-worker-2>
~~~

NOTE: Remove the provisioner host entry as it is replaced by the openshift-worker-2

Once the change as been added and saved, restart the `dnsmasq` service
~~~sh
systemctl restart dnsmasq
~~~

## Deploy the Provisioner node as a Worker Node using Metal3

Once the prerequisites above have been set, the deploy process is as follows:
 
1. Poweroff the node using the `ipmitool` and confirm the provisioning node is powered off

    ~~~sh
    ssh <server-with-access-to-management-net>
    # Use the user, password and Management net IP adddress to shutdown the system
    ipmitool -I lanplus -U <user> -P <password> -H <management-server-ip> power off
    # Confirm the server is powered down
    ipmitool -I lanplus -U <user> -P <password> -H <management-server-ip> power status
    Chassis Power is off
    ~~~
3. Get `base64` strings for the Out of band Management credentials. In the example user is `root`, password is `calvin`

    ~~~sh
    # Use echo -ne, otherwise you will get your secrets with \n which will cause issues
    # Get root username in base64
    echo -ne "root" | base64
    # Get root password in base64
    echo -ne "calvin" | base64
    ~~~
4. Configure the BaremetalHost `bmh.yaml`

    ~~~yaml
    ---
    apiVersion: v1
    kind: Secret
    metadata:
      name: openshift-worker-2-bmc-secret
    type: Opaque
    data:
      username: ca2vdAo=
      password: MWAwTWdtdC0K
    ---
    apiVersion: metal3.io/v1alpha1
    kind: BareMetalHost
    metadata:
      name: openshift-worker-2
    spec:
      online: true
      bootMACAddress: <NIC1-mac-address>
      bmc:
        address: ipmi://<out-of-band-ip> 
        credentialsName: openshift-worker-2-bmc-secret
    ~~~
    
5. Create the BaremetalHost

    ~~~sh
    ./oc -n openshift-machine-api create -f bmh.yaml
    secret/openshift-worker-2-bmc-secret created
    baremetalhost.metal3.io/openshift-worker-2 created
    ~~~
6. The Node will be powered up and inspected

    ~~~sh
    ./oc -n openshift-machine-api get bmh openshift-worker-2

    NAME                 STATUS   PROVISIONING STATUS   CONSUMER   BMC                 HARDWARE PROFILE   ONLINE   ERROR
    openshift-worker-2   OK       inspecting                       ipmi://<out-of-band-ip>                      true     
    ~~~
7. Once the inspection finishes the node will be ready to be provisioned

    ~~~sh
    ./oc -n openshift-machine-api get bmh openshift-worker-2

    NAME                 STATUS   PROVISIONING STATUS   CONSUMER   BMC                 HARDWARE PROFILE   ONLINE   ERROR
    openshift-worker-2   OK       ready                            ipmi://<out-of-band-ip>   unknown            true     
    ~~~
8. Scale the workers machineset. Previously, we had 2 replicas during original installation. 

    ~~~sh
    ./oc get machineset -n openshift-machine-api
    NAME            DESIRED   CURRENT   READY   AVAILABLE   AGE
    openshift-worker-2   0         0                             21h

    ./oc -n openshift-machine-api scale machineset openshift-worker-2 --replicas=3
    ~~~
9. The baremetal host will move to provisioning status (this will take a while 30m~, status can be followed from the node console)

    ~~~sh
    oc -n openshift-machine-api get bmh openshift-worker-2

    NAME                 STATUS   PROVISIONING STATUS   CONSUMER                  BMC                 HARDWARE PROFILE   ONLINE   ERROR
    openshift-worker-2   OK       provisioning          openshift-worker-0-65tjz   ipmi://<out-of-band-ip>   unknown            true     
    ~~~
10. Once the node is provisioned it will move to provisioned status

    ~~~sh
    oc -n openshift-machine-api get bmh openshift-worker-2
    
    NAME                 STATUS   PROVISIONING STATUS   CONSUMER                  BMC                 HARDWARE PROFILE   ONLINE   ERROR
    openshift-worker-2   OK       provisioned           openshift-worker-2-65tjz   ipmi://<out-of-band-ip>   unknown            true     
    ~~~
11. Once the `kubelet` finishes its initialization the node is ready to be used (you can connect to the node and run `journalctl -fu kubelet` to check the process)

    ~~~sh
    oc get node
    NAME                                            STATUS   ROLES           AGE     VERSION
    master-0                                        Ready    master          30h     v1.16.2
    master-1                                        Ready    master          30h     v1.16.2
    master-2                                        Ready    master          30h     v1.16.2
    worker-0                                        Ready    worker          3m27s   v1.16.2
    worker-1                                        Ready    worker          3m27s   v1.16.2
    worker-2                                        Ready    worker          3m27s   v1.16.2
    ~~~
