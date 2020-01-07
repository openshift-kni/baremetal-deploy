package performance

import (
	"fmt"
	"os/exec"
	"strings"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	ocv1 "github.com/openshift/api/config/v1"
	k8sv1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/fields"
	"k8s.io/apimachinery/pkg/labels"

	"github.com/openshift-kni/baremetal-deploy/features/functests/utils/clients"
)

const (
	perfTestNamespace                       = "perfomancetest"
	perfWorkerNodesLabel                    = "node-role.kubernetes.io/worker-rt="
	perfMachineConfigDaemonContainer        = "machine-config-daemon"
	perfClusterNodeTuningOperatorNamespaces = "openshift-cluster-node-tuning-operator"
	perfSysctlTimeout                       = 240
	perfSysctlPollInterval                  = 2
)

var mcKernelArguments = []string{"isolcpus"}

var _ = Describe("performance", func() {
	// 00-tuned-network-latency.yaml related verification
	var _ = Context("Network latency parameters adjusted by the Node Tuning Operator", func() {
		It("Should contain configuration injected through the 00-tuned-network-latency.yaml template", func() {
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
			const perfNodeNetworkLatencyTuned = "openshift-node-network-latency"
			_, err := clients.CntoConfig.TunedV1().Tuneds(perfClusterNodeTuningOperatorNamespaces).Get(perfNodeNetworkLatencyTuned,metav1.GetOptions{})
			Expect(err).ToNot(HaveOccurred(), "cannot find the Cluster Node Tuning Operator object "+ perfNodeNetworkLatencyTuned)

			nodes := getListOfNodes()
			execSysctlOnWorkers(nodes, sysctlMap)
		})
	})

	// 11-pre-boot-worker-tuning.yaml related verification
	var _ = Context("Pre boot tuning adjusted by the Machine Config Operator ", func() {
		const perfWorkerPreBootTuning = "11-worker-pre-boot-tuning"
		It("Should contain Machine Configuration profile "+perfWorkerPreBootTuning, func() {
			_, err := clients.MachineConfig.MachineconfigurationV1().MachineConfigs().Get(perfWorkerPreBootTuning, metav1.GetOptions{})
			Expect(err).ToNot(HaveOccurred(), "doesn't contain Machine Configuration profile "+perfWorkerPreBootTuning)
		})

		const perfRtKernelPrebootTuningScript = "/usr/local/bin/pre-boot-tuning.sh"
		It(perfRtKernelPrebootTuningScript+" should exist on the nodes", func() {
			nodes := getListOfNodes()
			checkWorkerRtProfileReadiness(nodes)
			checkFileExistense(nodes, perfRtKernelPrebootTuningScript)
		})

		It("Should contain a custom initrd image in the boot loader", func() {
			nodes := getListOfNodes()
			checkWorkerRtProfileReadiness(nodes)
			for _, node := range nodes {
				mcd, err := mcdForNode(&node)
				Expect(err).ToNot(HaveOccurred())
				mcdName := mcd.ObjectMeta.Name
				By("executing the command \"grep -R  initrd /rootfs/boot/loader/entries/\" inside the pod " + mcdName)
				bootLoaderEntries, err := exec.Command("oc", "rsh", "-n", mcd.ObjectMeta.Namespace, "-c",
					perfMachineConfigDaemonContainer, mcdName, "grep", "-R", "initrd", "/rootfs/boot/loader/entries/").CombinedOutput()
				Expect(err).ToNot(HaveOccurred())
				Expect(strings.Contains(string(bootLoaderEntries), "iso_initrd.img")).To(BeTrue(), "cannot find iso_initrd.img entry among the bootloader entries")
			}
		})
	})

	// 11-machine-config-worker-rt-kernel.yaml related verifications
	var _ = Context("Cluster configuration", func() {
		const perfWorkerRTKernelMC = "11-worker-rt-kernel"
		It("Should contain Machine Configuration profile "+perfWorkerRTKernelMC, func() {
			_, err := clients.MachineConfig.MachineconfigurationV1().MachineConfigs().Get(perfWorkerRTKernelMC, metav1.GetOptions{})
			Expect(err).ToNot(HaveOccurred(), "doesn't contain Machine Configuration profile "+perfWorkerRTKernelMC)
		})

		const perfRTKernelPatchScript = "/usr/local/bin/rt-kernel-patch.sh"
		It(perfRTKernelPatchScript+" should exist on the nodes", func() {
			nodes := getListOfNodes()
			checkWorkerRtProfileReadiness(nodes)
			checkFileExistense(nodes, perfRTKernelPatchScript)
		})

		const perfKernelVersionValuePreemptEntry = "PREEMPT"
		const perfKernelVersionValueRTEntry = "RT"
		It(fmt.Sprintf("Should contain %s and %s entries",
			perfKernelVersionValueRTEntry, perfKernelVersionValuePreemptEntry), func() {
			nodes := getListOfNodes()
			checkWorkerRtProfileReadiness(nodes)
			for _, node := range nodes {
				mcd, err := mcdForNode(&node)
				Expect(err).ToNot(HaveOccurred())
				mcdName := mcd.ObjectMeta.Name
				By("executing the command \"uname -v\" inside the pod " + mcdName)
				Eventually(func() bool {
					out, err := exec.Command("oc", "rsh", "-n", mcd.ObjectMeta.Namespace,
						"-c", perfMachineConfigDaemonContainer, mcdName, "uname", "-v").CombinedOutput()
					if err != nil {
						return false
					}
					line := strings.TrimSpace(string(out))
					return strings.Contains(line, perfKernelVersionValuePreemptEntry) &&
						strings.Contains(line, perfKernelVersionValueRTEntry)
				}, perfSysctlTimeout*time.Second, perfSysctlPollInterval*time.Second).Should(BeTrue(), "RT kernel is not installed")
			}
		})
	})

	// 12-worker-rt-kargs.yaml related verifications
	var _ = Context("RT kernel arguments", func() {
		const perfWorkerRtKernelArgsMc = "12-worker-rt-kargs"
		It("Should contain Machine Configuration profile "+perfWorkerRtKernelArgsMc, func() {
			_, err := clients.MachineConfig.MachineconfigurationV1().MachineConfigs().Get(perfWorkerRtKernelArgsMc, metav1.GetOptions{})
			Expect(err).ToNot(HaveOccurred(), fmt.Sprintf("doesn't contain %s Machine Configiguration profile", perfWorkerRtKernelArgsMc))
		})

		It(fmt.Sprintf("Should contain kernel arguments set by %s machine configuration", perfWorkerRtKernelArgsMc), func() {
			nodes := getListOfNodes()
			checkWorkerRtProfileReadiness(nodes)
			for _, node := range nodes {
				mcd, err := mcdForNode(&node)
				Expect(err).ToNot(HaveOccurred())
				mcdName := mcd.ObjectMeta.Name
				By("executing the command \"cat /rootfs/proc/cmdline\" inside the pod " + mcdName)
				kargsBytes, err := exec.Command("oc", "rsh", "-n", mcd.ObjectMeta.Namespace, mcdName,
					"cat", "/rootfs/proc/cmdline").CombinedOutput()
				Expect(err).ToNot(HaveOccurred())
				kargs := string(kargsBytes)
				for _, v := range mcKernelArguments {
					Expect(strings.Contains(kargs, v)).To(BeTrue(), "unable to find kernel argument "+v)
				}
			}
		})
	})

	// 12-kubelet-config-worker-rt.yaml related verifications
	var _ = Context("Kubelet configuration", func() {
		const perfKubeletWorkerRT = "worker-rt"
		It("Should contain Kubelet Configuration profile "+perfKubeletWorkerRT, func() {
			_, err := clients.MachineConfig.MachineconfigurationV1().KubeletConfigs().Get(perfKubeletWorkerRT, metav1.GetOptions{})
			Expect(err).ToNot(HaveOccurred(), fmt.Sprintf("doesn't contain %s Kubelet Configiguration profile", perfKubeletWorkerRT))
		})
	})

	// 12-feature-gate-latency-sensitive.yaml verification
	var _ = Context("FeatureSet configuration", func() {
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
	})

	// 12-tuned-worker-rt.yaml related verifications
	var _ = Context("Tuned kernel parameters", func() {
		It("Should contain configuration injected through the 12-tuned-worker-rt template", func() {
			sysctlMap := map[string]string{
				"kernel.hung_task_timeout_secs": "600",
				"kernel.nmi_watchdog":           "0",
				"kernel.sched_rt_runtime_us":    "-1",
				"vm.stat_interval":              "10",
				"kernel.timer_migration":        "0",
			}

			const perfRealTimeNodeProfile = "openshift-realtime-node"

			_, err := clients.CntoConfig.TunedV1().Tuneds(perfClusterNodeTuningOperatorNamespaces).Get(perfRealTimeNodeProfile ,metav1.GetOptions{})
			Expect(err).ToNot(HaveOccurred(), "cannot find the Cluster Node Tuning Operator object "+ perfRealTimeNodeProfile )
			nodes := getListOfNodes()
			execSysctlOnWorkers(nodes, sysctlMap)
		})
	})
})

// getListOfNodes finds appropriate nodes
func getListOfNodes() []k8sv1.Node {
	By("Getting list of nodes")
	nodes, err := clients.K8s.CoreV1().Nodes().List(metav1.ListOptions{
		LabelSelector: perfWorkerNodesLabel,
	})
	Expect(err).ToNot(HaveOccurred())
	Expect(len(nodes.Items)).Should(BeNumerically(">", 0), "cannot find nodes labeled as "+perfWorkerNodesLabel)
	return nodes.Items
}

// find the MCD pod that has spec.nodeNAME = node.Name and get its name
func mcdForNode(node *k8sv1.Node) (*k8sv1.Pod, error) {
	listOptions := metav1.ListOptions{
		FieldSelector: fields.SelectorFromSet(fields.Set{"spec.nodeName": node.Name}).String(),
	}
	listOptions.LabelSelector = labels.SelectorFromSet(labels.Set{"k8s-app": "machine-config-daemon"}).String()

	mcdList, err := clients.K8s.CoreV1().Pods("openshift-machine-config-operator").List(listOptions)
	if err != nil {
		return nil, err
	}

	Expect(len(mcdList.Items)).To(Equal(1), "there should be one machine config daemon per node")
	return &mcdList.Items[0], nil
}

// execute sysctl command inside container in a MCD pod
func execSysctlOnWorkers(nodes []k8sv1.Node, sysctlMap map[string]string) {
	for _, node := range nodes {
		mcd, err := mcdForNode(&node)
		Expect(err).ToNot(HaveOccurred())
		mcdName := mcd.ObjectMeta.Name
		for param, expected := range sysctlMap {
			By(fmt.Sprintf("executing the command \"sysctl -n %s\" inside the pod %s", param, mcdName))
			Eventually(func() string {
				out, _ := exec.Command("oc", "rsh", "-n", mcd.ObjectMeta.Namespace,
					"-c", perfMachineConfigDaemonContainer, mcdName, "sysctl", "-n", param).CombinedOutput()
				return strings.TrimSpace(string(out))
			}, perfSysctlTimeout*time.Second, perfSysctlPollInterval*time.Second).Should(Equal(expected),
				fmt.Sprintf("parameter %s value is not %s", param, expected))
		}
	}
}

// Check whether the "worker-rt" pool is updated and all the nodes labeled as "worker-rt" are ready
func checkWorkerRtProfileReadiness(nodes []k8sv1.Node) {
	const rtMachineConfigPool = "worker-rt"
	Eventually(func() bool {
		p, err := clients.MachineConfig.MachineconfigurationV1().MachineConfigPools().Get(rtMachineConfigPool, metav1.GetOptions{})
		if err != nil {
			return false
		}
		return int(p.Status.ReadyMachineCount) == len(nodes)
	}, 1800*time.Second, perfSysctlPollInterval*time.Second).Should(BeTrue(), rtMachineConfigPool+" is not ready")
}

// Check whether appropriate file exists on the system
func checkFileExistense(nodes []k8sv1.Node, file string) {
	for _, node := range nodes {
		mcd, err := mcdForNode(&node)
		Expect(err).ToNot(HaveOccurred())
		mcdName := mcd.ObjectMeta.Name
		By(fmt.Sprintf("executing the command \"ls %s\" inside the pod %s", file, mcdName))
		err = exec.Command("oc", "rsh", "-n", mcd.ObjectMeta.Namespace, "-c",
			perfMachineConfigDaemonContainer, mcdName, "ls", "/rootfs/"+file).Run()
		Expect(err).To(BeNil(), "cannot find the script "+file)
	}
}

