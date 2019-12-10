package performance_test

import (
	"os"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"k8s.io/apimachinery/pkg/util/yaml"

	configv1 "github.com/openshift/api/config/v1"
)

// beware the typo (sic)
var featuregateYaml = "../manifests/generated/12-fg-latency-sensetive.yaml"

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

func loadFeatureGate(path string) *configv1.FeatureGate {
	fd, err := os.Open(path)
	Expect(err).ToNot(HaveOccurred())
	defer fd.Close()
	fg := configv1.FeatureGate{}
	err = yaml.NewYAMLOrJSONDecoder(fd, 1024).Decode(&fg)
	Expect(err).ToNot(HaveOccurred())
	return &fg
}
