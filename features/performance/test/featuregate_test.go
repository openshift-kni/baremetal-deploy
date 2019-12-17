package performance_test

import (
	"bytes"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"k8s.io/apimachinery/pkg/util/yaml"

	configv1 "github.com/openshift/api/config/v1"
)

var featuregateYaml = "12-feature-gate-latency-sensitive.yaml"

var _ = Describe("TestPerformanceFeatureGate", func() {
	Context("Performance Feature Gates", func() {
		It("Should enable the LatencySensitive", func() {
			fg := loadFeatureGate(featuregateYaml)
			featureSet := string(fg.Spec.FeatureSet)
			// case matters for the string here
			Expect(featureSet).To(ContainSubstring("LatencySensitive"))
		})
	})
})

func loadFeatureGate(filename string) *configv1.FeatureGate {
	// not relevant for this test, so hardcode the simplest value
	out := generateManifest(filename, "0", "0", "0", 1)
	fg := configv1.FeatureGate{}
	err := yaml.NewYAMLOrJSONDecoder(bytes.NewBuffer(out), 1024).Decode(&fg)
	Expect(err).ToNot(HaveOccurred())
	return &fg
}
