package ptp

import (
	"fmt"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/openshift-kni/baremetal-deploy/features/functests/utils/clients"

	v1 "k8s.io/api/apps/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const (
	ptpLinuxDaemonNamespace         = "openshift-ptp"
	ptpOperatorDeploymentName       = "ptp-operator"
	ptpSlaveNodeLabel               = "ptp/slave"
	ptpGrandmasterNodeLabel         = "ptp/grandmaster"
	ptpResourcesGroupVersionPrefix  = "ptp.openshift.io/v"
	ptpResourcesNameOperatorConfigs = "ptpoperatorconfigs"
)

var _ = Describe("ptp", func() {
	var _ = Context("PTP configuration verifications", func() {
		It("Should check that nodes are labeled properly", func() {
			By("Get list of nodes")
			nodes, err := clients.K8s.CoreV1().Nodes().List(metav1.ListOptions{})
			Expect(err).ToNot(HaveOccurred())
			Expect(len(nodes.Items)).To(BeNumerically(">", 0), "number of nodes should be more than 0")

			grands := 0
			slaves := 0

			By("Check labels")
			for _, n := range nodes.Items {
				if _, ok := n.Labels[ptpGrandmasterNodeLabel]; ok {
					By(fmt.Sprintf("Checking whether grandmaster %s is labeled as slave", n.Name))
					_, ok := n.Labels[ptpSlaveNodeLabel]
					Expect(ok).NotTo(BeTrue(),
						fmt.Sprintf("Grandmaster node %s shouldn't contain %s label", n.Name, ptpSlaveNodeLabel))

					grands++
				}

				if _, ok := n.Labels[ptpSlaveNodeLabel]; ok {
					By(fmt.Sprintf("Checking whether slave %s is labeled as grandmaster", n.Name))
					_, ok := n.Labels[ptpGrandmasterNodeLabel]
					Expect(ok).NotTo(BeTrue(),
						fmt.Sprintf("Slave node %s shouldn't contain %s label", n.Name, ptpGrandmasterNodeLabel))

					slaves++
				}
			}

			By("Checking that all nodes are labeled")
			Expect(len(nodes.Items)).To(Equal(grands+slaves), "not nodes are labeled properly")

			By("Checking whether only one Grandmaster exists")
			Expect(grands).To(Equal(1), "there should be one Grandmaster")
		})

		It("Should check whether PTP operator appropriate resource exists", func() {
			By("Getting list of available resources")
			rl, err := clients.K8s.ServerPreferredResources()
			Expect(err).ToNot(HaveOccurred())

			found := false
			By("Find appropriate resources")
			for _, g := range rl {
				if strings.Contains(g.GroupVersion, ptpResourcesGroupVersionPrefix) {
					for _, r := range g.APIResources {
						By("Search for resource " + ptpResourcesNameOperatorConfigs)
						if r.Name == ptpResourcesNameOperatorConfigs {
							found = true
						}
					}
				}
			}

			Expect(found).To(BeTrue(), fmt.Sprintf("resource %s not found", ptpResourcesNameOperatorConfigs))
		})

		It("Should check that all nodes are running at least one replica of linuxptp-daemon", func() {
			By("Getting list of nodes")
			nodes, err := clients.K8s.CoreV1().Nodes().List(metav1.ListOptions{})
			Expect(err).NotTo(HaveOccurred())
			By("Checking number of nodes")
			Expect(len(nodes.Items)).To(BeNumerically(">", 0), "number of nodes should be more than 0")

			By("Get daemonsets collection for the namespace " + ptpLinuxDaemonNamespace)
			ds, err := clients.K8s.AppsV1().DaemonSets(ptpLinuxDaemonNamespace).List(metav1.ListOptions{})
			Expect(err).ToNot(HaveOccurred())
			Expect(len(ds.Items)).To(BeNumerically(">", 0), "no damonsets found in the namespace "+ptpLinuxDaemonNamespace)
			By("Checking number of scheduled instances")
			Expect(ds.Items[0].Status.CurrentNumberScheduled).To(BeNumerically("==", len(nodes.Items)), "should be one instance per node")
		})

		It("Should check that operator is deployed", func() {
			By("Getting deployment " + ptpOperatorDeploymentName)
			dep, err := clients.K8s.AppsV1().Deployments(ptpLinuxDaemonNamespace).Get(ptpOperatorDeploymentName, metav1.GetOptions{})
			Expect(err).ToNot(HaveOccurred())
			By("Checking availability of the deployment")
			for _, c := range dep.Status.Conditions {
				if c.Type == v1.DeploymentAvailable {
					Expect(string(c.Status)).Should(Equal("True"), ptpOperatorDeploymentName+" deployment is not available")
				}
			}
		})
	})
})
