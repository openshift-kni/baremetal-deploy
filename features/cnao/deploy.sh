oc create -f https://raw.githubusercontent.com/kubevirt/cluster-network-addons-operator/master/manifests/cluster-network-addons/0.22.0/namespace.yaml
oc create -f https://raw.githubusercontent.com/kubevirt/cluster-network-addons-operator/master/manifests/cluster-network-addons/0.22.0/network-addons-config.crd.yaml
oc create -f https://raw.githubusercontent.com/kubevirt/cluster-network-addons-operator/master/manifests/cluster-network-addons/0.22.0/operator.yaml
oc create -f cnao-cr.yaml
