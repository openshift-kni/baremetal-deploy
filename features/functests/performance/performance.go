package performance

import (
	"fmt"
	"os/exec"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	
	"k8s.io/apimachinery/pkg/fields"
	"k8s.io/apimachinery/pkg/labels"
	ocv1 "github.com/openshift/api/config/v1"
	k8sv1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	"github.com/openshift-kni/baremetal-deploy/features/functests/utils/clients"
	"github.com/openshift-kni/baremetal-deploy/features/functests/utils/namespace"
)

const (
	perfTestNamespace            = "perfomancetest"
	perfWorkerNodesLabel         = "node-role.kubernetes.io/worker-rt="
	perfWorkerRtKernelMcTemplate = "11-worker-rt-kernel"
	perfSysctlKernelVersionParam = "kernel.version"
//	perfSysctlKernelOsrelease    = "kernel.osrelease"
)

var mcKernelArguments = []string{"isolcpus"}

var _ = Describe("performance", func() {
	beforeAll(func() {
		namespace.Create(perfTestNamespace, clients.K8s)
		namespace.Clean(perfTestNamespace, clients.K8s)
	})

	var _ = Context("RT Kernel Arguments", func() {
		It("Nodes should contain kernel arguments set by machine configuration", func() {
			By("Getting list of nodes")
			nodes, err := clients.K8s.CoreV1().Nodes().List(metav1.ListOptions{
				LabelSelector: perfWorkerNodesLabel,
			})
			Expect(err).ToNot(HaveOccurred())
			Expect(len(nodes.Items)).Should(BeNumerically(">", 0), "cannot find nodes labeled as "+perfWorkerNodesLabel)

			for _, node := range nodes.Items {
				mcd, err := mcdForNode(&node)
				Expect(err).ToNot(HaveOccurred())
				mcdName := mcd.ObjectMeta.Name
				By("executing a command inside the pod " + mcdName)
				kargsBytes, err := exec.Command("oc", "rsh", "-n", "openshift-machine-config-operator", mcdName,
					"cat", "/rootfs/proc/cmdline").CombinedOutput()
				Expect(err).ToNot(HaveOccurred())
				kargs := string(kargsBytes)
				for _, v := range mcKernelArguments {
					Expect(strings.Contains(kargs, v)).To(BeTrue(), "unable to find kernel argument "+v)
				}
			}
		})
	})

	var _ = Context("Pre boot tuning setup", func() {
		It("Should contain a custome initrd image in boot loader", func() {
			nodes, err := clients.K8s.CoreV1().Nodes().List(metav1.ListOptions{
				LabelSelector: perfWorkerNodesLabel,
			})
			Expect(err).ToNot(HaveOccurred())
			Expect(len(nodes.Items)).Should(BeNumerically(">", 0), "cannot find nodes labeled as "+perfWorkerNodesLabel)

			for _, node := range nodes.Items {
				mcd, err := mcdForNode(&node)
				Expect(err).ToNot(HaveOccurred())
				mcdName := mcd.ObjectMeta.Name
				By("executing a command inside the pod " + mcdName)
				bootLoaderEntries, err := exec.Command("oc", "rsh", "-n", "openshift-machine-config-operator", mcdName,
					"grep", "-R", "initrd", "/rootfs/boot/loader/entries/").CombinedOutput()
				Expect(err).ToNot(HaveOccurred())
				Expect(strings.Contains(string(bootLoaderEntries), "iso_initrd.img")).To(BeTrue(), "cannot find iso_initrd.img entry among the bootloader entries")
			}
		})
	})

	var _ = Context("Network latency parameters", func() {
		It("Should contain configuration injected through the 00-tuned-network-latency template", func() {
			sysctlMap := map[string]string{
				"net.core.busy_read":              "50",
				"net.core.busy_poll":              "50",
				"net.ipv4.tcp_fastopen":           "3",
				"kernel.numa_balancing":           "0",
				"kernel.sched_min_granularity_ns": "10000000",
				"vm.dirty_ratio":                  "10",
				"vm.dirty_background_ratio":       "3",
				"vm.swappiness":                   "10",
				"kernel.sched_migration_cost_ns":  "5000000",
			}

			nodes, err := clients.K8s.CoreV1().Nodes().List(metav1.ListOptions{
				LabelSelector: perfWorkerNodesLabel,
			})
			Expect(err).ToNot(HaveOccurred())
			Expect(len(nodes.Items)).Should(BeNumerically(">", 0), "cannot find nodes labeled as "+perfWorkerNodesLabel)

			for _, node := range nodes.Items {
				mcd, err := mcdForNode(&node)
				Expect(err).ToNot(HaveOccurred())
				mcdName := mcd.ObjectMeta.Name
				By("executing a command inside the pod " + mcdName)
				out, err := exec.Command("oc", "rsh", "-n", "openshift-machine-config-operator", mcdName,
					"sysctl", "-A").CombinedOutput()
				Expect(err).ToNot(HaveOccurred())

				for _, str := range strings.Split(string(out), "\n") {
					line := strings.Split((string(str)), "=")
					param := strings.TrimSpace(line[0])
					value := strings.TrimSpace(strings.Join(line[1:], ""))
					if expected, ok := sysctlMap[param]; ok {
						By(fmt.Sprintf("checking whether parameter %s value is %s", param, expected))
						Expect(value).To(Equal(expected), fmt.Sprintf("parameter %s value is not %s", param, expected))
					}
				}
			}
		})
	})

	var _ = Context("Tuned kernel parameters", func() {
		It("Should contain configuration injected through the 12-tuned-worker-rt template", func() {
			sysctlMap := map[string]string{
				"kernel.hung_task_timeout_secs": "600",
				"kernel.nmi_watchdog":           "0",
				"kernel.sched_rt_runtime_us":    "-1",
				"vm.stat_interval":              "10",
				"kernel.timer_migration":        "0",
			}

			nodes, err := clients.K8s.CoreV1().Nodes().List(metav1.ListOptions{
				LabelSelector: "node-role.kubernetes.io/worker-rt=",
			})
			Expect(err).ToNot(HaveOccurred())
			Expect(len(nodes.Items)).Should(BeNumerically(">", 0), "cannot find nodes labeled as "+perfWorkerNodesLabel)

			for _, node := range nodes.Items {
				mcd, err := mcdForNode(&node)
				Expect(err).ToNot(HaveOccurred())
				mcdName := mcd.ObjectMeta.Name
				By("executing a command inside the pod " + mcdName)
				out, err := exec.Command("oc", "rsh", "-n", "openshift-machine-config-operator", mcdName,
					"sysctl", "-A").CombinedOutput()
				Expect(err).ToNot(HaveOccurred())

				for _, str := range strings.Split(string(out), "\n") {
					line := strings.Split((string(str)), "=")
					param := strings.TrimSpace(line[0])
					value := strings.TrimSpace(strings.Join(line[1:], ""))
					if expected, ok := sysctlMap[param]; ok {
						By(fmt.Sprintf("checking whether parameter %s value is %s", param, expected))
						Expect(value).To(Equal(expected), fmt.Sprintf("parameter %s value is not %s", param, expected))
					}
				}
			}
		})
	})

	var _ = Context("Essential RT kernel parameters", func() {
		It("Should contain appropriate entries", func() {
			nodes, err := clients.K8s.CoreV1().Nodes().List(metav1.ListOptions{
				LabelSelector: perfWorkerNodesLabel,
			})
			Expect(err).ToNot(HaveOccurred())
			Expect(len(nodes.Items)).Should(BeNumerically(">", 0), "cannot find nodes labeled as "+perfWorkerNodesLabel)

			for _, node := range nodes.Items {
				mcd, err := mcdForNode(&node)
				Expect(err).ToNot(HaveOccurred())
				mcdName := mcd.ObjectMeta.Name
				By("executing a command inside the pod " + mcdName)
				out, err := exec.Command("oc", "rsh", "-n", "openshift-machine-config-operator", mcdName,
					"sysctl", "-A").CombinedOutput()
				Expect(err).ToNot(HaveOccurred())

				for _, str := range strings.Split(string(out), "\n") {
					line := strings.Split(str, "=")
					param := strings.TrimSpace(line[0])
					value := strings.TrimSpace(strings.Join(line[1:], ""))
					if param == perfSysctlKernelVersionParam {
						By(fmt.Sprintf("checking whether kernel parameter %s contains PREEMPT entry", param))
						Expect(strings.Contains(value, "PREEMPT")).To(BeTrue(), fmt.Sprintf("kernel parameter %s doesn't contain PREEMPT entry", param))

						By(fmt.Sprintf("checking whether parameter %s contains RT entry", param))
						Expect(strings.Contains(value, "PREEMPT")).To(BeTrue(), fmt.Sprintf("kernel parameter %s doesn't contain RT entry", param))
					}

				//	if param == perfSysctlKernelOsrelease {
				//		By(fmt.Sprintf("checking whether kernel name %s contains 'rt' entry", param))
				//		Expect(strings.Contains(value, "rt")).To(BeTrue(), "the kernel doesn't have the 'rt' extension")
				//	}
				}
			}
		})
	})

	var _ = Context("Cluster configuration", func() {
		It("FeatureSet should be LatencySensitive for FeatureGates spec", func() {
			fg, err := clients.OcpConfig.FeatureGates().List(metav1.ListOptions{})
			Expect(err).ToNot(HaveOccurred())
			Expect(len(fg.Items)).Should(BeNumerically(">", 0), "cannot find FeatureGates")

			lsStr := string(ocv1.LatencySensitive)
			for _, o := range fg.Items {
				By("checking whether FetureSet is configured as " + lsStr)
				Expect(string(o.Spec.FeatureSet)).Should(Equal(lsStr), "FeauterSet is not set to "+lsStr)
			}
		})

		It("Should contain worker RT kernel MachineConfiguration template", func() {
			_, err := clients.MachineConfig.MachineconfigurationV1().MachineConfigs().Get(perfWorkerRtKernelMcTemplate, metav1.GetOptions{})
			Expect(err).ToNot(HaveOccurred())
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

	Expect(len(mcdList.Items)).To(Equal(1), "there should be one machine config deamon per node")
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
