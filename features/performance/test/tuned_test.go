package performance_test

import (
	"fmt"
	"os"

	. "github.com/onsi/ginkgo"
	"github.com/onsi/ginkgo/extensions/table"
	. "github.com/onsi/gomega"

	ini "gopkg.in/ini.v1"

	"k8s.io/apimachinery/pkg/util/yaml"

	tunedv1 "github.com/openshift/cluster-node-tuning-operator/pkg/apis/tuned/v1"
)

var tunedYamls = []string{
	"../manifests/00-tuned-network-latency.yaml",
	"../manifests/01-tuned-rt.yaml",
}

var _ = Describe("TestPerformanceTuned", func() {
	table.DescribeTable("Tuned files should provide complete options",
		func(fileName string) {
			t := loadTuned(fileName)
			Expect(t).ToNot(BeNil())
			validateProfiles(fileName, t)
		},
		// msg, fileName
		table.Entry(tunedYamls[0], tunedYamls[0]),
		table.Entry(tunedYamls[1], tunedYamls[1]),
	)
})

func loadTuned(path string) *tunedv1.Tuned {
	fd, err := os.Open(path)
	Expect(err).ToNot(HaveOccurred())
	defer fd.Close()
	t := tunedv1.Tuned{}
	err = yaml.NewYAMLOrJSONDecoder(fd, 1024).Decode(&t)
	Expect(err).ToNot(HaveOccurred())
	return &t
}

func validateProfiles(fileName string, t *tunedv1.Tuned) {
	for _, profile := range t.Spec.Profile {
		// caution here: Load() interprets string as file path, and []byte
		cfg, err := ini.Load([]byte(*profile.Data))
		Expect(err).ToNot(HaveOccurred())
		Expect(cfg).ToNot(BeNil())
		for _, sect := range cfg.Sections() {
			for _, key := range sect.Keys() {
				msg := fmt.Sprintf("error in %s:%s.%s.%s", fileName, *profile.Name, sect.Name(), key.Name())
				val := key.Value()
				Expect(val).NotTo(BeEmpty(), msg)
			}
		}
	}

}
