package performance_test

import (
	"bytes"
	"io/ioutil"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"k8s.io/apimachinery/pkg/util/yaml"
	kubeletconfigv1beta1 "k8s.io/kubelet/config/v1beta1"

	mcfgv1 "github.com/openshift/machine-config-operator/pkg/apis/machineconfiguration.openshift.io/v1"
	mcfgScheme "github.com/openshift/machine-config-operator/pkg/generated/clientset/versioned/scheme"
)

const kubeletconfigYaml = "../manifests/generated/12-kubeletconfig-worker-rt.yaml" // TODO pass it as a param?

var _ = Describe("TestPerformanceKubeletConfig", func() {
	var _ = Context("CPU Manager policy", func() {
		It("Should set the policy to 'static'", func() {
			kc := loadKC()
			specKubeletConfig, err := decodeKubeletConfig(kc.Spec.KubeletConfig.Raw)
			Expect(err).ToNot(HaveOccurred())
			Expect(specKubeletConfig.CPUManagerPolicy).To(Equal("static"))
		})
	})
})

func loadKC() *mcfgv1.KubeletConfig {
	decode := mcfgScheme.Codecs.UniversalDeserializer().Decode
	kcoyaml, err := ioutil.ReadFile(kubeletconfigYaml)
	Expect(err).ToNot(HaveOccurred())

	obj, _, err := decode([]byte(kcoyaml), nil, nil)
	Expect(err).ToNot(HaveOccurred())
	mc, ok := obj.(*mcfgv1.KubeletConfig)
	Expect(ok).To(BeTrue())
	return mc
}

func decodeKubeletConfig(data []byte) (*kubeletconfigv1beta1.KubeletConfiguration, error) {
	config := &kubeletconfigv1beta1.KubeletConfiguration{}
	d := yaml.NewYAMLOrJSONDecoder(bytes.NewReader(data), len(data))
	if err := d.Decode(config); err != nil {
		return nil, err
	}
	return config, nil
}
