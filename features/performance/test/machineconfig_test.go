package performance_test

import (
	"fmt"
	"net/url"
	"strings"

	"github.com/vincent-petithory/dataurl"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	mcfgv1 "github.com/openshift/machine-config-operator/pkg/apis/machineconfiguration.openshift.io/v1"
	mcfgScheme "github.com/openshift/machine-config-operator/pkg/generated/clientset/versioned/scheme"
)

const (
	machineconfigRTKernelYaml = "11-machine-config-worker-rt-kernel.yaml" // TODO pass it as a param?
	machineconfigRTKargsYaml  = "12-machine-config-worker-rt-kargs.yaml"  // TODO pass it as a param?
)

var _ = Describe("TestPerformanceMachineConfig", func() {
	Context("Kernel Arguments MachineConfig", func() {
		It("Should provide syntactically valid kernel arguments", func() {
			// cpu params not relevant here, just use something valid
			mc := loadMachineConfig(machineconfigRTKargsYaml, "1-15", "0")
			Expect(len(mc.Spec.KernelArguments)).To(BeNumerically(">=", 1))
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

	Context("RT Kernel setup MachineConfig", func() {
		It("Should ship a correctly encoded payload", func() {
			// cpu params not relevant here, just use something valid
			mc := loadMachineConfig(machineconfigRTKernelYaml, "0", "1-15")
			Expect(len(mc.Spec.Config.Storage.Files)).To(BeNumerically(">=", 1))
			for _, encodedFile := range mc.Spec.Config.Storage.Files {
				validateContentSource(encodedFile.Contents.Source)
			}
		})
		It("Should ship at least an enabled systemd unit", func() {
			// cpu params not relevant here, just use something valid
			mc := loadMachineConfig(machineconfigRTKernelYaml, "1-15", "0")
			Expect(len(mc.Spec.Config.Systemd.Units)).To(BeNumerically(">=", 1))
			for _, unitFile := range mc.Spec.Config.Systemd.Units {
				Expect(unitFile.Enabled).ToNot(BeNil())
				Expect(*unitFile.Enabled).To(BeTrue())
				Expect(unitFile.Contents).NotTo(BeEmpty())
			}
		})
	})
})

func loadMachineConfig(filename, isolatedCpus, reservedCpus string) *mcfgv1.MachineConfig {
	decode := mcfgScheme.Codecs.UniversalDeserializer().Decode
	out := generateManifest(filename, isolatedCpus, reservedCpus)
	obj, _, err := decode(out, nil, nil)
	Expect(err).ToNot(HaveOccurred())
	mc, ok := obj.(*mcfgv1.MachineConfig)
	Expect(ok).To(BeTrue())
	return mc
}

func validateContentSource(data string) {
	Expect(data).NotTo(BeEmpty())

	u, err := url.Parse(data)
	Expect(err).ToNot(HaveOccurred())
	Expect(u.Scheme).To(Equal("data"))

	_, err = dataurl.DecodeString(data)
	Expect(err).ToNot(HaveOccurred())
}
