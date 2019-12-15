// +build !unittests

package test_test

import (
	"flag"
	"testing"

	. "github.com/onsi/ginkgo"
	"github.com/onsi/ginkgo/reporters"
	. "github.com/onsi/gomega"
	_ "github.com/openshift-kni/baremetal-deploy/features/functests/performance" // this is needed otherwise the performance test won't be executed
	_ "github.com/openshift-kni/baremetal-deploy/features/functests/sctp"        // this is needed otherwise the sctp test won't be executed
	"github.com/openshift-kni/baremetal-deploy/features/functests/utils/clients"
)

var junitPath *string

func init() {
	junitPath = flag.String("junit", "junit.xml", "the path for the junit format report")
}

func TestTest(t *testing.T) {
	RegisterFailHandler(Fail)

	rr := []Reporter{}
	if junitPath != nil {
		rr = append(rr, reporters.NewJUnitReporter(*junitPath))
	}
	RunSpecsWithDefaultAndCustomReporters(t, "Test Suite", rr)
}

var _ = BeforeSuite(func() {
	clients.Setup()
	// Add here the setup for additional features
})
