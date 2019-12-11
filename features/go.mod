module github.com/openshift-kni/baremetal-deploy/features

go 1.13

require (
	github.com/coreos/go-semver v0.3.0 // indirect
	github.com/imdario/mergo v0.3.8 // indirect
	github.com/onsi/ginkgo v1.10.3
	github.com/onsi/gomega v1.7.1
	github.com/openshift/api v3.9.1-0.20191201231411-9f834e337466+incompatible // indirect
	github.com/openshift/client-go v0.0.0-20191001081553-3b0e988f8cb0
	github.com/openshift/machine-config-operator v4.2.0-alpha.0.0.20190917115525-033375cbe820+incompatible
	github.com/vincent-petithory/dataurl v0.0.0-20191104211930-d1553a71de50 // indirect
	go4.org v0.0.0-20191010144846-132d2879e1e9 // indirect
	golang.org/x/oauth2 v0.0.0-20191202225959-858c2ad4c8b6 // indirect
	golang.org/x/time v0.0.0-20191024005414-555d28b269f0 // indirect
	k8s.io/api v0.0.0
	k8s.io/apimachinery v0.0.0
	k8s.io/client-go v11.0.0+incompatible
	k8s.io/utils v0.0.0-20191114200735-6ca3b61696b6 // indirect
)

replace (
	github.com/coreos/go-systemd => github.com/coreos/go-systemd v0.0.0-20190719114852-fd7a80b32e1f // indirect
	github.com/cri-o/cri-o => github.com/cri-o/cri-o v1.16.1
	github.com/go-log/log => github.com/go-log/log v0.1.1-0.20181211034820-a514cf01a3eb
	github.com/openshift/api => github.com/openshift/api v3.9.1-0.20191201231411-9f834e337466+incompatible
	github.com/openshift/client-go => github.com/openshift/client-go v0.0.0-20191125132246-f6563a70e19a
	github.com/openshift/machine-config-operator => github.com/openshift/machine-config-operator v0.0.1-0.20191204220237-5e6c4cabf194
	k8s.io/api => k8s.io/api v0.0.0-20190905175716-d9fae7ce8d9e
	k8s.io/apiextensions-apiserver => github.com/openshift/kubernetes-apiextensions-apiserver v0.0.0-20190918161926-8f644eb6e783
	k8s.io/apimachinery => k8s.io/apimachinery v0.0.0-20190913080033-27d36303b655
	k8s.io/apiserver => k8s.io/apiserver v0.0.0-20190819142446-92cc630367d0
	k8s.io/cli-runtime => k8s.io/cli-runtime v0.0.0-20190819144027-541433d7ce35
	k8s.io/client-go => k8s.io/client-go v0.0.0-20190929040153-a39e818a0987
	k8s.io/cloud-provider => k8s.io/cloud-provider v0.0.0-20190819145148-d91c85d212d5
	k8s.io/cluster-bootstrap => k8s.io/cluster-bootstrap v0.0.0-20190819145008-029dd04813af
	k8s.io/code-generator => k8s.io/code-generator v0.0.0-20190927045949-f81bca4f5e85
	k8s.io/component-base => k8s.io/component-base v0.0.0-20190819141909-f0f7c184477d
	k8s.io/cri-api => github.com/openshift/kubernetes-cri-api v0.0.0-20190828162817-608eb1dad4ac
	k8s.io/csi-translation-lib => k8s.io/csi-translation-lib v0.0.0-20190819145328-4831a4ced492
	k8s.io/kube-aggregator => k8s.io/kube-aggregator v0.0.0-20190819142756-13daafd3604f
	k8s.io/kube-controller-manager => k8s.io/kube-controller-manager v0.0.0-20190819144832-f53437941eef
	k8s.io/kube-proxy => k8s.io/kube-proxy v0.0.0-20190819144346-2e47de1df0f0
	k8s.io/kube-scheduler => k8s.io/kube-scheduler v0.0.0-20190819144657-d1a724e0828e
	k8s.io/kubelet => k8s.io/kubelet v0.0.0-20190831152136-ba9cf7ec6904
	k8s.io/kubernetes => k8s.io/kubernetes v1.15.3
	k8s.io/legacy-cloud-providers => k8s.io/legacy-cloud-providers v0.0.0-20190819145509-592c9a46fd00
	k8s.io/metrics => k8s.io/metrics v0.0.0-20190819143841-305e1cef1ab1
	k8s.io/sample-apiserver => k8s.io/sample-apiserver v0.0.0-20190819143045-c84c31c165c4
)
