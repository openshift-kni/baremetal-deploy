package performance_test

import (
	"flag"
	"testing"

	. "github.com/onsi/ginkgo"
	"github.com/onsi/ginkgo/reporters"
	. "github.com/onsi/gomega"
)

var junitPath *string

func init() {
	junitPath = flag.String("junit", "junit.xml", "the path for the junit format report")
}

func TestPerformanceManifests(t *testing.T) {
	RegisterFailHandler(Fail)

	rr := []Reporter{}
	if junitPath != nil {
		rr = append(rr, reporters.NewJUnitReporter(*junitPath))
	}
	RunSpecsWithDefaultAndCustomReporters(t, "Performance Manifests Test Suite", rr)
}
