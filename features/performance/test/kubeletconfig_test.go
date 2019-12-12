package performance_test

import (
	"bytes"
	"fmt"

	. "github.com/onsi/ginkgo"
	"github.com/onsi/ginkgo/extensions/table"
	. "github.com/onsi/gomega"

	"k8s.io/apimachinery/pkg/util/yaml"
	kubeletconfigv1beta1 "k8s.io/kubelet/config/v1beta1"

	mcfgv1 "github.com/openshift/machine-config-operator/pkg/apis/machineconfiguration.openshift.io/v1"
	mcfgScheme "github.com/openshift/machine-config-operator/pkg/generated/clientset/versioned/scheme"
)

const kubeletconfigYaml = "12-kubeletconfig-worker-rt.yaml" // TODO pass it as a param?

var _ = Describe("TestPerformanceKubeletConfig", func() {
	var _ = Context("CPU Manager policy", func() {
		It("Should set the policy to 'static'", func() {
			// parameters not really relevant for this test, just use something valid
			kc := loadKubeletConfig(kubeletconfigYaml, "1-15", "0")
			Expect(kc).ToNot(BeNil())
			specKubeletConfig, err := decodeKubeletConfig(kc.Spec.KubeletConfig.Raw)
			Expect(err).ToNot(HaveOccurred())
			Expect(specKubeletConfig.CPUManagerPolicy).To(Equal("static"))
		})
	})

	table.DescribeTable("KubeletConfig files should be loadable",
		func(fileName, isolatedCPUs, reservedCPUs string) {
			kc := loadKubeletConfig(fileName, isolatedCPUs, reservedCPUs)
			Expect(kc).ToNot(BeNil())
			_, err := decodeKubeletConfig(kc.Spec.KubeletConfig.Raw)
			Expect(err).ToNot(HaveOccurred())
		},
		// cpu params not relevant here, just use something valid
		table.Entry(fmt.Sprintf("kubeletconfig manifest %s", kubeletconfigYaml), kubeletconfigYaml, "0", "1-15"),
		table.Entry(fmt.Sprintf("kubeletconfig manifest %s", kubeletconfigYaml), kubeletconfigYaml, "0,1", "2-15"),
		table.Entry(fmt.Sprintf("kubeletconfig manifest %s", kubeletconfigYaml), kubeletconfigYaml, "0-3", "4-15"),
		table.Entry(fmt.Sprintf("kubeletconfig manifest %s", kubeletconfigYaml), kubeletconfigYaml, "1-15", "0"),
		table.Entry(fmt.Sprintf("kubeletconfig manifest %s", kubeletconfigYaml), kubeletconfigYaml, "2-15", "0,1"),
		table.Entry(fmt.Sprintf("kubeletconfig manifest %s", kubeletconfigYaml), kubeletconfigYaml, "4-15", "0-3"),
	)
})

func loadKubeletConfig(filename, isolatedCpus, reservedCpus string) *mcfgv1.KubeletConfig {
	decode := mcfgScheme.Codecs.UniversalDeserializer().Decode
	out := generateManifest(filename, isolatedCpus, reservedCpus)
	obj, _, err := decode(out, nil, nil)
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
