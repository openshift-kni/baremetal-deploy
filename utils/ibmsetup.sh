#!/bin/bash -eux

DETAILSFILE=$(mktemp)
trap "rm -f $DETAILSFILE" EXIT

dnf install -y openssh-clients openssh jq python3-netaddr python3-dns iputils ansible which diffutils findutils

BASEDIR=$(dirname $0)

which ibmcloud || curl -fsSL https://clis.cloud.ibm.com/install/linux | sh

python3 $BASEDIR/ibmsetup.py > $DETAILSFILE
cat $DETAILSFILE
cd ansible-ipi-install

if [ $? != 0 ] ; then
    echo "Missing/Unsupported insfrastructure"
    exit 1
fi

SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

DHCPHOSTS=$(jq -r .dhcphosts $DETAILSFILE)
DHCPRANGE=$(jq -r .dhcprange $DETAILSFILE)
DOMAIN=$(jq -r .domain $DETAILSFILE)
GATEWAY=$(jq -r .gateway $DETAILSFILE)
PROV_PUB_IP=$(jq -r .bootstrap_pub_ip $DETAILSFILE)
PROV_PRIV_IP=$(jq -r .bootstrap_priv_ip $DETAILSFILE)
BS_PRIV_NIC=$(jq -r .bootstrap_priv_nics $DETAILSFILE)
BS_PUB_NIC=$(jq -r .bootstrap_pub_nics $DETAILSFILE)
MGTNET=$(jq -r .mgtnet $DETAILSFILE)
PRIVATEGATEWAY=$(jq -r .privategateway $DETAILSFILE)
PUBLICCIDR=$(jq -r .publiccidr $DETAILSFILE)
PRIVATECIDR=$(jq -r .privatecidr $DETAILSFILE)

set +e
cat - <<-EOF | $SSH root@$PROV_PUB_IP -t
set -xeu

cd /etc/sysconfig/network-scripts/
if ! [ -e ifcfg-provisioning ] ; then
    cp -r /etc /etc-\$(date +%s)
    rm -f *
    echo -e '$MGTNET src $PROV_PRIV_IP\n10.0.0.0/8 via $PRIVATEGATEWAY src $PROV_PRIV_IP\n166.8.0.0/14 via $PRIVATEGATEWAY src $PROV_PRIV_IP\n161.26.0.0/16 via $PRIVATEGATEWAY src $PROV_PRIV_IP' > route-provisioning
    echo -e 'TYPE=Bridge\nBOOTPROTO=none\nIPV6_DISABLED=yes\nDEVICE=baremetal\nONBOOT=yes\nIPADDR=$PROV_PUB_IP\nPREFIX=$PUBLICCIDR\nGATEWAY=$GATEWAY' > ifcfg-baremetal
    echo -e 'TYPE=Bridge\nBOOTPROTO=none\nIPV6_DISABLED=yes\nDEVICE=provisioning\nONBOOT=yes\nIPADDR0=172.22.0.4\nPREFIX0=24\nIPADDR1=$PROV_PRIV_IP\nPREFIX1=$PRIVATECIDR' > ifcfg-provisioning
    for NIC in $BS_PRIV_NIC ; do
        echo -e "TYPE=Ethernet\nNAME=\$NIC\nDEVICE=\$NIC\nONBOOT=yes\nBRIDGE=provisioning" > ifcfg-\$NIC
    done
    for NIC in $BS_PUB_NIC ; do
        echo -e "TYPE=Ethernet\nNAME=\$NIC\nDEVICE=\$NIC\nONBOOT=yes\nBRIDGE=baremetal" > ifcfg-\$NIC
    done
    echo "====================================================="
    echo "RESTARTING BOOTSTRAP HOST"
    echo "====================================================="
    init 6
fi

EOF
set -e

# Wait for the reboot to complete
while ! $SSH root@$PROV_PUB_IP hostname ; do sleep 5 ; done

cat - <<-EOF | $SSH root@$PROV_PUB_IP -t
set -xeu

id -u kni || useradd kni
if ! [ -d ~kni/.ssh ] ; then
  cp -r ~/.ssh ~kni/.ssh
  chown -R kni ~kni/.ssh
  chmod 700 ~kni/.ssh
  chmod 400 ~kni/.ssh/authorized_keys

fi
echo 'kni        ALL=(ALL)       NOPASSWD: ALL' > /etc/sudoers.d/kni

cat - <<-EOS > /etc/dnsmasq.conf
interface=baremetal
except-interface=lo
bind-dynamic
log-dhcp

dhcp-range=$DHCPRANGE
dhcp-option=baremetal,121,0.0.0.0/0,$GATEWAY,$MGTNET,$PROV_PUB_IP

dhcp-hostsfile=/var/lib/dnsmasq/dnsmasq.hostsfile
EOS

echo "$DHCPHOSTS" > /var/lib/dnsmasq/dnsmasq.hostsfile

systemctl --no-pager status firewalld || systemctl start firewalld
systemctl restart dnsmasq
systemctl enable dnsmasq

# Permanent versions of above
firewall-cmd --permanent --add-port 53/udp
firewall-cmd --permanent --add-port 67/udp
# Adding provisioning to a zone with masquerade, so that ipmi to the mgt subnet gets NAT'ed (bootstrap and cluster nodes don't have an IP on mgt network)
firewall-cmd --permanent --change-zone=provisioning --zone=external || true
firewall-cmd --reload

EOF

diff inventory/hosts.sample inventory/hosts || true
ansible-playbook -i inventory/hosts playbook.yml -v --skip-tags network
