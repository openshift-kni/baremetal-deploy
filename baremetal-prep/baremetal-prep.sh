#!/usr/bin/env bash
#################################################################
# Script Prepares Provisioning Node For OpenShift Deployment    #
#################################################################

howto(){
  echo "Usage: ./baremetal-prep.sh -p <provisioning interface> -b <baremetal interface> -d (configure for disconnected) -g (generate install-config.yaml) -m (generate metal3-config.yaml)"
  echo "Example: ./baremetal-prep.sh -p ens3 -b ens4 -d -g -m"
}

#disabled, might be removed at a later stage
disable_selinux(){
  echo -n "Disabling selinux..."
  sudo setenforce permissive >/dev/null 2>&1
  sudo sed -i "s/=enforcing/=permissive/g" /etc/selinux/config >/dev/null 2>&1
  echo "Success!"

}

setup_default_pool(){

  #libvirt must be running
  if ( ! systemctl is-active libvirtd) then
    echo "starting libvirt"
    sudo systemctl start libvirtd
    sleep 2
  fi
  
  if `sudo virsh pool-info default >/dev/null 2>&1`; then
    echo "Default pool exists...Skipping!"
  else
    echo -n "Creating default pool..."
    sudo virsh pool-define-as --name default --type dir --target /var/lib/libvirt/images
    sudo virsh pool-start default
    sudo virsh pool-autostart default
    sudo usermod --append --groups libvirt $USERNAME
    echo "Success!"
  fi
}

setup_repository(){
  if `sudo podman ps|grep ocpdiscon-registry|grep Up>/dev/null 2>&1`; then
    sudo podman stop ocpdiscon-registry
    sudo podman rm ocpdiscon-registry
  fi
  sudo yum -y install podman httpd httpd-tools
  sudo mkdir -p /opt/registry/{auth,certs,data}
  sudo openssl req -newkey rsa:4096 -nodes -sha256 -keyout /opt/registry/certs/domain.key -x509 -days 365 -out /opt/registry/certs/domain.crt -subj "/C=US/ST=Massachussetts/L=Boston/O=Red Hat/OU=Engineering/CN=$HOST_URL"
  sudo cp /opt/registry/certs/domain.crt $HOME/domain.crt
  sudo chown $USERNAME:$USERNAME $HOME/domain.crt
  sudo cp /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/
  sudo update-ca-trust extract
  sudo htpasswd -bBc /opt/registry/auth/htpasswd dummy dummy
  sudo firewall-cmd --add-port=5000/tcp --zone=libvirt  --permanent
  sudo firewall-cmd --add-port=5000/tcp --zone=public   --permanent
  sudo firewall-cmd --add-service=http  --permanent
  sudo firewall-cmd --reload
  sudo podman create --name ocpdiscon-registry -p 5000:5000 -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /opt/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key docker.io/library/registry:2
  sudo podman start ocpdiscon-registry
  AUTHSTRING="{\"$HOST_URL:5000\": {\"auth\": \"ZHVtbXk6ZHVtbXk=\",\"email\": \"$USERNAME@redhat.com\"}}"
  jq ".auths += $AUTHSTRING" < $PULLSECRET > $PULLSECRET.new
  LOCAL_SECRET_JSON=$PULLSECRET.new
  mirror_images
  update_installconfig
}

update_installconfig(){
  echo "Updating install-config.yaml..."
  sed -i -e 's/^/  /' $HOME/domain.crt
  sed  -i '/^pullSecret/d' $INSTALLCONFIG
  echo "pullSecret: '`cat $PULLSECRET.new`'" >> $INSTALLCONFIG
  echo "additionalTrustBundle: |" >> $INSTALLCONFIG
  cat $HOME/domain.crt >> $INSTALLCONFIG
  echo "imageContentSources:" >> $INSTALLCONFIG
  echo "- mirrors:" >> $INSTALLCONFIG
  echo "  - $HOST_URL:5000/ocp4/openshift4" >> $INSTALLCONFIG
  echo "  source: registry.svc.ci.openshift.org/ocp/$NEW_RELEASE" >> $INSTALLCONFIG
  echo "- mirrors:" >> $INSTALLCONFIG
  echo "  - $HOST_URL:5000/ocp4/openshift4" >> $INSTALLCONFIG
  echo "  source: registry.svc.ci.openshift.org/ocp/release" >> $INSTALLCONFIG

}

mirror_images(){
  echo "Mirroring remote repository to local respository..."
  /usr/local/bin/oc adm release mirror -a $LOCAL_SECRET_JSON --from=$UPSTREAM_REPO --to-release-image=$LOCAL_REG/$LOCAL_REPO:$OCP_RELEASE --to=$LOCAL_REG/$LOCAL_REPO
}

find_pullsecret_file(){
  if [ -f $HOME/pull-secret ] && ( file $HOME/pull-secret|grep ASCII>/dev/null 2>&1 ); then
     PULLSECRET="$HOME/pull-secret"
  elif [ -f $HOME/pull-secret.txt ] && ( file $HOME/pull-secret.txt|grep ASCII>/dev/null 2>&1 ); then
     PULLSECRET="$HOME/pull-secret.txt"
  elif [ -f $HOME/pull-secret.json ] && ( file $HOME/pull-secret.json|grep ASCII>/dev/null 2>&1 ); then
     PULLSECRET="$HOME/pull-secret.json"
  else
     echo "Failed - $HOME/pull-secret, $HOME/pull-secret.txt or $HOME/pull-secret.json file not found"; exit 1
  fi
}

find_sshkey_file(){
  if [ -f $HOME/sshkey ] && ( ssh-keygen -l -f $HOME/sshkey >/dev/null 2>&1 ); then
     SSHKEY="$HOME/sshkey"
  elif [ -f $HOME/.ssh/id_rsa.pub ] && ( ssh-keygen -l -f $HOME/.ssh/id_rsa.pub >/dev/null 2>&1 ); then
     SSHKEY="$HOME/.ssh/id_rsa.pub"
  else
     # Generate user ssh key
     ssh-keygen -f ~/.ssh/id_rsa -P 
     SSHKEY="$HOME/.ssh/id_rsa.pub"
  fi	  
}

setup_env(){
  echo "Setting environment..."
  HOST_URL=`hostname -f`
  USERNAME=`whoami`
  HOME=/home/$USERNAME
  INSTALLCONFIG=$HOME/install-config.yaml
  
  find_pullsecret_file
  find_sshkey_file
  
  VERSION=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest/release.txt | grep 'Name:' | awk -F: '{print $2}' | xargs)
  RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}' | xargs)
  OBICMD=openshift-baremetal-install
  EXTRACTDIR=$(pwd)
  curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest/openshift-client-linux-$VERSION.tar.gz | tar zxvf - oc
  sudo cp ./oc /usr/local/bin/oc
  /usr/local/bin/oc adm release extract --registry-config "${PULLSECRET}" --command=$OBICMD --to "${EXTRACTDIR}" ${RELEASE_IMAGE}
  sudo cp ./openshift-baremetal-install /usr/local/bin/openshift-baremetal-install
  LATEST_CI_IMAGE=$(curl https://openshift-release.svc.ci.openshift.org/api/v1/releasestream/4.3.0-0.ci/latest | grep -o 'registry.svc.ci.openshift.org[^"]\+')
  OPENSHIFT_RELEASE_IMAGE="${OPENSHIFT_RELEASE_IMAGE:-$LATEST_CI_IMAGE}"
  GOPATH=$HOME/go
  OCP_RELEASE=`echo $LATEST_CI_IMAGE|cut -d: -f2`
  NEW_RELEASE=`echo $OCP_RELEASE|sed s/.0-0.ci//g`
  UPSTREAM_REPO=$LATEST_CI_IMAGE
  LOCAL_REG="${HOST_URL}:5000"
  LOCAL_REPO='ocp4/openshift4'
  export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=${LOCAL_REG}/${LOCAL_REPO}:${OCP_RELEASE}
}

setup_bridges(){
  if `ip a|egrep "baremetal|provisioning" >/dev/null 2>&1`; then
    echo "A baremetal or provisioning interface already exists...Skipping!"
  else
    echo "Setting up baremetal and provisioning bridges..."
    sudo nmcli connection add ifname provisioning type bridge con-name provisioning
    sudo nmcli con add type bridge-slave ifname "$PROV_CONN" master provisioning
    sudo nmcli connection add ifname baremetal type bridge con-name baremetal
    sudo nmcli con add type bridge-slave ifname "$MAIN_CONN" master baremetal
    sudo nmcli con down "System $MAIN_CONN";sudo pkill dhclient;sudo dhclient baremetal
    sudo nmcli connection modify provisioning ipv4.addresses 172.22.0.1/24 ipv4.method manual
    sudo nmcli con down provisioning
    sudo nmcli con up provisioning
  fi
}

install_depends(){
  echo "Installing required dependencies..."
  sudo yum -y install ansible jq git usbredir golang libXv virt-install libvirt libvirt-devel libselinux-utils qemu-kvm mkisofs 
}

setup_installconfig(){
  echo "Creating install-config.yaml..."
  /usr/bin/ansible-playbook -i hosts make-install-config.yaml
  echo "pullSecret: '`cat $PULLSECRET`'" >> $INSTALLCONFIG
  echo "sshKey: '`cat $SSHKEY`'" >> $INSTALLCONFIG
}

existing_install_config(){
  if ([ "$GENERATEINSTALLCONF" -eq "0" ]) then
    if [ ! -f "$INSTALLCONFIG" ]; then
      echo "$INSTALLCONFIG does not exist and -g was not passed"
      howto
      exit 1
    fi
  fi
}

setup_metalconfig(){
  echo "Creating metal3-config.yaml..."
  METALCONFIG=$HOME/metal3-config.yaml
  OPENSHIFT_INSTALLER=/usr/local/bin/openshift-baremetal-install
  OPENSHIFT_INSTALL_COMMIT=$($OPENSHIFT_INSTALLER version | grep commit | cut -d' ' -f4)
  OPENSHIFT_INSTALLER_RHCOS=${OPENSHIFT_INSTALLER_RHCOS:-https://raw.githubusercontent.com/openshift/installer/$OPENSHIFT_INSTALL_COMMIT/data/data/rhcos.json}
  RHCOS_IMAGE_JSON=$(curl "${OPENSHIFT_INSTALLER_RHCOS}")
  RHCOS_INSTALLER_IMAGE_URL=$(echo "${RHCOS_IMAGE_JSON}" | jq -r '.baseURI + .images.openstack.path')
  RHCOS_IMAGE_URL=${RHCOS_IMAGE_URL:-${RHCOS_INSTALLER_IMAGE_URL}}
  BAREMETALIP=`ip addr show|grep ens4|grep -o "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*"`
  echo "kind: ConfigMap" > $METALCONFIG
  echo "apiVersion: v1" >> $METALCONFIG
  echo "metadata:" >> $METALCONFIG
  echo "  name: metal3-config" >> $METALCONFIG
  echo "  namespace: openshift-machine-api" >> $METALCONFIG
  echo "data:" >> $METALCONFIG
  echo "  http_port: \"6180\"" >> $METALCONFIG
  echo "  provisioning_interface: \"${PROV_CONN}\"" >> $METALCONFIG
  echo "  provisioning_ip: \"172.22.0.3/24\"" >> $METALCONFIG
  echo "  dhcp_range: \"172.22.0.10,172.22.0.100\"" >> $METALCONFIG
  echo "  deploy_kernel_url: \"http://172.22.0.3:6180/images/ironic-python-agent.kernel\"" >> $METALCONFIG
  echo "  deploy_ramdisk_url: \"http://172.22.0.3:6180/images/ironic-python-agent.initramfs\"" >> $METALCONFIG
  echo "  ironic_endpoint: \"http://172.22.0.3:6385/v1/\"" >> $METALCONFIG
  echo "  ironic_inspector_endpoint: \"http://172.22.0.3:5050/v1/\"" >> $METALCONFIG
  echo "  cache_url: \"http://192.168.0.246/images\"" >> $METALCONFIG
  echo "  rhcos_image_url: $RHCOS_IMAGE_URL" >> $METALCONFIG
}

ENABLEDISCONNECT=0
GENERATEINSTALLCONF=0
GENERATEMETALCONF=0

while getopts p:b:dgmh option
do
case "${option}"
in
p) PROV_CONN=${OPTARG};;
b) MAIN_CONN=${OPTARG};;
d) ENABLEDISCONNECT=1;;
g) GENERATEINSTALLCONF=1;;
m) GENERATEMETALCONF=1;;
h) howto; exit 0;;
\?) howto; exit 1;;
esac
done

if ([ -z "$PROV_CONN" ] || [ -z "$MAIN_CONN" ]) then
 howto
 exit 1
fi

setup_env
existing_install_config
install_depends
#disable_selinux
setup_default_pool
setup_bridges
if ([ "$GENERATEINSTALLCONF" -eq "1" ]) then
  setup_installconfig
fi
if ([ "$GENERATEMETALCONF" -eq "1" ]) then
  setup_metalconfig
fi
if ([ "$ENABLEDISCONNECT" -eq "1" ]) then
  setup_repository
fi
exit
