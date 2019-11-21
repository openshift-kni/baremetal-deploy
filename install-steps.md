Ran the following commands on (worker-0 / provision host) on RHEL 8.1

Environment - TBD

Assumptions- TBD

---

```bash
firewall-cmd --zone=public --add-service=http
firewall-cmd --zone=public --permanent --add-service=http


subscription-manager register --username=<user> --password=<pass>
subscription-manager repos --enable=rhel-8-for-x86_64-appstream-rpms --enable=rhel-8-for-x86_64-baseos-rpms

#optional - if you gonna use preflight get ansible (to create install-config.yaml)
subscription-manager repos --enable ansible-2-for-rhel-8-x86_64-rpms
dnf install -y ansible

#optional - if you gonna use preflight, install jq
dnf install -y jq

dnf install -y libvirt qemu-kvm mkisofs
systemctl start libvirtd
systemctl enable libvirtd

cat << EOF > default_storage.xml 
<pool type='dir'>
  <name>default</name>
  <source>
  </source>
  <target>
    <path>/var/lib/libvirt/images</path>
    <permissions>
      <mode>0711</mode>
      <owner>0</owner>
      <group>0</group>
      <label>system_u:object_r:virt_image_t:s0</label>
    </permissions>
  </target>
</pool>
EOF

virsh pool-define default_storage.xml 
virsh pool-start default
virsh pool-autostart default

nmcli connection add ifname provisioning type bridge con-name provisioning
nmcli con add type bridge-slave ifname eno1 master provisioning
nmcli connection add ifname baremetal type bridge con-name baremetal
nmcli con add type bridge-slave ifname eno2 master baremetal

#optional - verify you see the connections 
nmcli con show

#warning - if you are on an ssh terminal, you will kill connection running this
nmcli con down eno2

#warning - if you used dhclient to get an IP on eno2, kill the dhclient process
ps -ef | grep dhclient
kill -9 <id_of_dhclient_process>

dhclient baremetal

nmcli connection modify provisioning ipv4.addresses 172.22.0.1/24 ipv4.method manual
nmcli con down provisioning
nmcli con up provisioning 

cat << EOF > provisioning.xml
<network>
  <name>provisioning</name>
  <bridge name='provisioning'/>
  <forward mode='bridge'/>
</network>
EOF

virsh net-define provisioning.xml
virsh net-start provisioning
virsh net-autostart provisioning

cat << EOF > baremetal.xml
<network>
  <name>baremetal</name>
  <bridge name='baremetal'/>
  <forward mode='bridge'/>
</network>
EOF

virsh net-define baremetal.xml
virsh net-start baremetal
virsh net-autostart baremetal
```

     # optional - check the networks on virsh
     virsh net-list
     Name                 State      Autostart     Persistent
     ----------------------------------------------------------
     baremetal            active     yes           yes
     default              active     yes           yes
     provisioning         active     yes           yes

```bash
systemctl restart libvirtd

# still need this? i cant remember why. 
echo 'ZONE=libvirt' >> /etc/sysconfig/network-scripts/ifcfg-provisioning

#Lets create a user (kni) so we aren't deploying as root and set ssh key
echo "kni ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/kni
chmod 0440 /etc/sudoers.d/kni
su - kni -c "ssh-keygen -t rsa -f /home/kni/.ssh/id_rsa -N ''"

#lets make sure python3 is default
alternatives --set python /usr/bin/python3


#Get your pull-secret file on the system
TODO

# Get the oc binary and place oc in /usr/local/bin

export VERSION=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest/release.txt | grep 'Name:' | awk -F: '{print $2}' | xargs)
export RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}' | xargs)
export cmd=openshift-baremetal-install
export pullsecret_file=pull-secret.txt
export extract_dir=$(pwd)
curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest/openshift-client-linux-$VERSION.tar.gz | tar zxvf - oc
sudo cp oc /usr/local/bin/
```
 
---

# Create your install-config.yaml file
#### In the following example, some keys have been deleted, so it will not work as is

```yaml
apiVersion: v1
baseDomain: cloud.lab.eng.bos.redhat.com
metadata:
  name: rna1
networking:
  machineCIDR: 10.19.1.128/25
compute:
- name: worker
  replicas: 0
controlPlane:
  name: master
  replicas: 3
  platform:
    baremetal: {}
platform:
  baremetal:
    apiVIP: 10.19.1.249
    ingressVIP: 10.19.1.248
    dnsVIP: 10.19.1.247
    hosts:
      - name: master-0
        role: master
        bmc:
          address: ipmi://172.22.0.231
          username: root
          password: r3dh@tPW
        bootMACAddress: 98:03:9B:61:88:40
        hardwareProfile: default
      - name: master-1
        role: master
        bmc:
          address: ipmi://172.22.0.232
          username: root
          password: r3dh@tPW
        bootMACAddress: 98:03:9B:61:88:10
        hardwareProfile: default
      - name: master-2
        role: master
        bmc:
          address: ipmi://172.22.0.233
          username: root
          password: r3dh@tPW
        bootMACAddress: 98:03:9B:61:6E:D8
        hardwareProfile: default
pullSecret: '{"auths":{"cloud.openshift.com":{"auth":"XXX","email":"rlopez@redhat.com"},"quay.io":{"auth":"XXX","email":"rlopez@redhat.com"},"registry.connect.redhat.com":{"auth":"XXX","email":"rlopez@redhat.com"},"registry.redhat.io":{"auth":"XXX","email":"rlopez@redhat.com"},"registry.svc.ci.openshift.org": { "auth": "XXX" } } }'
sshKey: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcwkj59OpeVt9AttLZ4+/AEnkt2/gi7eHKYzRyXUWrBLYTrZ91DBV5PhAmlMNiqbOCFZ2lFEW9Z9eJrPZEoO4zvAPqXd5RgQwAmeXSA5MUQgl+LRjahePZhF70rw52I3M6v6BMiZe3cNjWuXeTqQ7MgMPqqikZf58L+1lZj/bRuge7bVadsQfdVygo3RX6adXrrPKXI6LSX86JZLrlYuIdJexj9xFoa1193TdEShvfxB7/1YI1I9BPurIcU8ZQaSAKNUZl/LAzk7WuLJxrWBnKOmF+dzi4BxQNxoxMBW0PwQ6gjZhPOjrXntK7VyIP/fz0b90ZgvxJfcXEO4mldE6q35O4CEbtLF8Uj+fEs/Kmd/AkdAFkikFcvk6ncosWSJrb/y5HLknk9FavDYgmMnCT66yl3OFvsv0NG695SiXwwUxfXTzQcIu5wiVq3tO7zRHLrZk5MNrbhV827VS2GzgGg96v6cNkmc29EM= kni@worker-0'
```

----

```bash
mkdir testcluster
cp install-config.yaml testcluster/
./openshift-baremetal-install --dir testcluster --log-level debug create cluster
```

