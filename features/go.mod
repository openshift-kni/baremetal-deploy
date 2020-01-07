module github.com/openshift-kni/baremetal-deploy/features

go 1.13

require (
	github.com/ishidawataru/sctp v0.0.0-20180918013207-6e2cb1366111
	github.com/onsi/ginkgo v1.10.3
	github.com/onsi/gomega v1.7.1
	github.com/openshift/api v3.9.1-0.20191213091414-3fbf6bcf78e8+incompatible
	github.com/openshift/client-go v0.0.0-20191205152420-9faca5198b4f
	github.com/openshift/cluster-node-tuning-operator v0.0.0-20191211081013-c3b21314f1f2
	github.com/openshift/machine-config-operator v4.2.0-alpha.0.0.20190917115525-033375cbe820+incompatible
	github.com/smartystreets/goconvey v1.6.4 // indirect
	github.com/vincent-petithory/dataurl v0.0.0-20191104211930-d1553a71de50
	gopkg.in/ini.v1 v1.51.0
	k8s.io/api v0.17.0
	k8s.io/apimachinery v0.17.0
	k8s.io/client-go v0.17.0
	k8s.io/kubelet v0.17.0
	k8s.io/utils v0.0.0-20191114184206-e782cd3c129f
)

replace (
	github.com/cri-o/cri-o => github.com/cri-o/cri-o v1.16.1
	github.com/go-log/log => github.com/go-log/log v0.1.0
	github.com/openshift/api => github.com/openshift/api v3.9.1-0.20191213091414-3fbf6bcf78e8+incompatible
	github.com/openshift/client-go => github.com/openshift/client-go v0.0.0-20191205152420-9faca5198b4f
	github.com/openshift/machine-config-operator => github.com/openshift/machine-config-operator v0.0.0-20191213153440-ca88a545b320
	golang.org/x/tools => golang.org/x/tools v0.0.0-20191206213732-070c9d21b343
	k8s.io/api => k8s.io/api v0.17.0
	k8s.io/apiextensions-apiserver => github.com/openshift/kubernetes-apiextensions-apiserver v0.0.0-20190403105241-b38f53ead9d2
	k8s.io/apimachinery => k8s.io/apimachinery v0.17.0
	k8s.io/apiserver => k8s.io/apiserver v0.17.0
	k8s.io/cli-runtime => k8s.io/cli-runtime v0.17.0
	k8s.io/client-go => k8s.io/client-go v0.17.0
	k8s.io/cloud-provider => k8s.io/cloud-provider v0.17.0
	k8s.io/cluster-bootstrap => k8s.io/cluster-bootstrap v0.17.0
	k8s.io/code-generator => k8s.io/code-generator v0.17.0
	k8s.io/component-base => k8s.io/component-base v0.17.0
	k8s.io/cri-api => github.com/openshift/kubernetes-cri-api v0.0.0-20191121183020-775aa3c1cf73
	k8s.io/csi-translation-lib => k8s.io/csi-translation-lib v0.17.0
	k8s.io/kube-aggregator => k8s.io/kube-aggregator v0.17.0
	k8s.io/kube-controller-manager => k8s.io/kube-controller-manager v0.17.0
	k8s.io/kube-proxy => k8s.io/kube-proxy v0.17.0
	k8s.io/kube-scheduler => k8s.io/kube-scheduler v0.17.0
	k8s.io/kubelet => k8s.io/kubelet v0.17.0
	k8s.io/kubernetes => k8s.io/kubernetes v0.17.0
	k8s.io/legacy-cloud-providers => k8s.io/legacy-cloud-providers v0.17.0
	k8s.io/metrics => k8s.io/metrics v0.17.0
	k8s.io/sample-apiserver => k8s.io/sample-apiserver v0.17.0
)
