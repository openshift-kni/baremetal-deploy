package performance_test

import (
	"fmt"
	"io/ioutil"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	mcfgv1 "github.com/openshift/machine-config-operator/pkg/apis/machineconfiguration.openshift.io/v1"
	mcfgScheme "github.com/openshift/machine-config-operator/pkg/generated/clientset/versioned/scheme"
)

const machineconfigYaml = "../manifests/generated/12-machine-config-worker-rt-kargs.yaml" // TODO pass it as a param?

var _ = Describe("TestPerformanceMachineConfig", func() {
	var _ = Context("Kernel Arguments MachineConfig", func() {
		It("Should provide syntactically valid kernel arguments", func() {
			mc := loadMC()
			for _, kArg := range mc.Spec.KernelArguments {
				items := strings.Split(strings.TrimSpace(kArg), "=")
				// debug aid
				fmt.Fprintf(GinkgoWriter, "kArg=%s items=%#v\n", kArg, items)
				if len(items) == 2 {
					Expect(items[0]).To(Not(BeEmpty())) // key
					Expect(items[1]).To(Not(BeEmpty())) // value
				} else {
					Expect(len(items)).To(Equal(1))
				}
			}
		})
	})
})

func loadMC() *mcfgv1.MachineConfig {
	decode := mcfgScheme.Codecs.UniversalDeserializer().Decode
	mcoyaml, err := ioutil.ReadFile(machineconfigYaml)
	Expect(err).ToNot(HaveOccurred())

	obj, _, err := decode([]byte(mcoyaml), nil, nil)
	Expect(err).ToNot(HaveOccurred())
	mc, ok := obj.(*mcfgv1.MachineConfig)
	Expect(ok).To(BeTrue())
	return mc
}
