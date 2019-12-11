package performance_test

import (
	"flag"
	"fmt"
	"os/exec"
	"testing"

	. "github.com/onsi/ginkgo"
	"github.com/onsi/ginkgo/reporters"
	. "github.com/onsi/gomega"
)

var junitPath *string

func init() {
	junitPath = flag.String("junit", "junit.xml", "the path for the junit format report")
}

func generateManifest(filename, isolatedCpus, reservedCpus string) []byte {
	generator := "../hack/generate.sh"
	cmd := exec.Command(generator, filename)
	// not relevant for this test, so hardcode the simplest value
	cmd.Env = append(cmd.Env,
		fmt.Sprintf("ISOLATED_CPUS=%s", isolatedCpus),
		fmt.Sprintf("RESERVED_CPUS=%s", reservedCpus),
	)
	out, err := cmd.Output()
	Expect(err).ToNot(HaveOccurred())
	return out
}

func TestPerformanceManifests(t *testing.T) {
	RegisterFailHandler(Fail)

	rr := []Reporter{}
	if junitPath != nil {
		rr = append(rr, reporters.NewJUnitReporter(*junitPath))
	}
	RunSpecsWithDefaultAndCustomReporters(t, "Performance Manifests Test Suite", rr)
}
