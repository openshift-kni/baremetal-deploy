package test_test

import (
	"flag"
	"testing"

	. "github.com/onsi/ginkgo"
	"github.com/onsi/ginkgo/reporters"
	. "github.com/onsi/gomega"
	"github.com/openshift-kni/baremetal-deploy/features/functests/sctp"
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
	sctp.Setup()
})
