package performance_test

import (
	"flag"
	"fmt"
	"os/exec"
	"path"
	"runtime"
	"testing"

	. "github.com/onsi/ginkgo"
	"github.com/onsi/ginkgo/reporters"
	. "github.com/onsi/gomega"
)

var junitPath *string

func init() {
	junitPath = flag.String("junit", "junit.xml", "the path for the junit format report")
}

func generateManifest(filename, isolatedCpus, reservedCpus string, nonIsolatedCpus string, hugepagesNumber int) []byte {
	_, source, _, ok := runtime.Caller(1)
	Expect(ok).To(BeTrue())
	generator := path.Join(path.Dir(source), "./../generate.sh")
	cmd := exec.Command(generator, filename)
	// not relevant for this test, so hardcode the simplest value
	cmd.Env = append(cmd.Env,
		fmt.Sprintf("ISOLATED_CPUS=%s", isolatedCpus),
		fmt.Sprintf("RESERVED_CPUS=%s", reservedCpus),
		fmt.Sprintf("NON_ISOLATED_CPUS=%s", nonIsolatedCpus),
		fmt.Sprintf("HUGEPAGES_NUMBER=%d", hugepagesNumber),
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
