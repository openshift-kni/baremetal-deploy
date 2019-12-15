package performance

import (
	"os/exec"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"k8s.io/apimachinery/pkg/fields"
	"k8s.io/apimachinery/pkg/labels"

	"github.com/openshift-kni/baremetal-deploy/features/functests/utils/clients"
	"github.com/openshift-kni/baremetal-deploy/features/functests/utils/namespace"

	k8sv1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const testNamespace = "perfomancetest"

var mcKernelArguments = []string{"non_iso_cpus"}

var _ = Describe("performance", func() {
	beforeAll(func() {
		namespace.Create(testNamespace, clients.K8s)
		namespace.Clean(testNamespace, clients.K8s)
	})

	var _ = Context("RT Kernel Arguments", func() {
		nodes, err := clients.K8s.CoreV1().Nodes().List(metav1.ListOptions{
			LabelSelector: "node-role.kubernetes.io/worker=",
		})
		It("Nodes should contain kernel arguments set by machine configuration", func() {
			Expect(err).ToNot(HaveOccurred())
			for _, node := range nodes.Items {
				mcd, err := mcdForNode(&node)
				Expect(err).ToNot(HaveOccurred())
				mcdName := mcd.ObjectMeta.Name
				kargsBytes, err := exec.Command("oc", "rsh", "-n", "openshift-machine-config-operator", mcdName,
					"cat", "/rootfs/proc/cmdline").CombinedOutput()
				kargs := string(kargsBytes)
				for _, v := range mcKernelArguments {
					Expect(strings.Contains(string(kargs), v)).To(BeTrue())
				}
			}
		})
	})

	var _ = Context("Pre boot tuning setup", func() {
		nodes, err := clients.K8s.CoreV1().Nodes().List(metav1.ListOptions{
			LabelSelector: "node-role.kubernetes.io/worker=",
		})
		It("Should contain a custome initrd image in boot loader", func() {
			Expect(err).ToNot(HaveOccurred())
			for _, node := range nodes.Items {
				mcd, err := mcdForNode(&node)
				Expect(err).ToNot(HaveOccurred())
				mcdName := mcd.ObjectMeta.Name
				bootLoaderEntries, err := exec.Command("oc", "rsh", "-n", "openshift-machine-config-operator", mcdName,
					"cat", "/rootfs/boot/loader/entries/*").CombinedOutput()
				Expect(strings.Contains(string(bootLoaderEntries), "iso_initrd.img")).To(BeTrue())
			}
		})
	})
})

func mcdForNode(node *k8sv1.Node) (*k8sv1.Pod, error) {
	// find the MCD pod that has spec.nodeNAME = node.Name and get its name:
	listOptions := metav1.ListOptions{
		FieldSelector: fields.SelectorFromSet(fields.Set{"spec.nodeName": node.Name}).String(),
	}
	listOptions.LabelSelector = labels.SelectorFromSet(labels.Set{"k8s-app": "machine-config-daemon"}).String()

	mcdList, err := clients.K8s.CoreV1().Pods("openshift-machine-config-operator").List(listOptions)
	if err != nil {
		return nil, err
	}
	// there should be one machine config deamon per node
	Expect(len(mcdList.Items)).To(Equal(1))
	return &mcdList.Items[0], nil
}

func beforeAll(fn func()) {
	first := true
	BeforeEach(func() {
		if first {
			first = false
			fn()
		}
	})
}
