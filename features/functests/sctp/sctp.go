package sctp

import (
	"io/ioutil"
	"os"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	mcfgv1 "github.com/openshift/machine-config-operator/pkg/apis/machineconfiguration.openshift.io/v1"
	mcfgScheme "github.com/openshift/machine-config-operator/pkg/generated/clientset/versioned/scheme"

	"github.com/openshift-kni/baremetal-deploy/features/functests/utils/clients"
	"github.com/openshift-kni/baremetal-deploy/features/functests/utils/namespace"

	k8sv1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/intstr"
	"k8s.io/client-go/kubernetes"
)

const mcYaml = "../sctp/sctp_module_mc.yaml"
const hostnameLabel = "kubernetes.io/hostname"
const testNamespace = "sctptest"

var testerImage string

func init() {
	testerImage = os.Getenv("SCTPTEST_IMAGE")
	if testerImage == "" {
		testerImage = "fedepaol/sctptest:v1.1"
	}
}

var _ = Describe("sctp", func() {
	beforeAll(func() {
		namespace.Create(testNamespace, clients.K8s)
		namespace.Clean(testNamespace, clients.K8s)
		checkForSctpReady(clients.K8s)
		By("Creating the sctp service")
		createSctpService(clients.K8s)
	})

	var _ = Context("Client Server Connection", func() {
		var clientNode string
		var serverNode string
		It("Should connect a client pod to a server pod", func() {
			By("Choosing the nodes for the server and the client")
			nodes, err := clients.K8s.CoreV1().Nodes().List(metav1.ListOptions{
				LabelSelector: "node-role.kubernetes.io/worker=",
			})
			Expect(err).ToNot(HaveOccurred())
			clientNode = nodes.Items[0].ObjectMeta.Labels[hostnameLabel]
			serverNode = nodes.Items[0].ObjectMeta.Labels[hostnameLabel]
			if len(nodes.Items) > 1 {
				serverNode = nodes.Items[1].ObjectMeta.Labels[hostnameLabel]
			}

			By("Starting the server")
			serverArgs := []string{"-ip", "0.0.0.0", "-port", "30101", "-server"}
			pod := scptTestPod("scptserver", serverNode, "sctpserver", serverArgs)
			pod.Spec.Containers[0].Ports = []k8sv1.ContainerPort{
				k8sv1.ContainerPort{
					Name:          "sctpport",
					Protocol:      k8sv1.ProtocolSCTP,
					ContainerPort: 30101,
				},
			}
			serverPod, err := clients.K8s.CoreV1().Pods(testNamespace).Create(pod)
			Expect(err).ToNot(HaveOccurred())

			By("Fetching the server's ip address")
			var runningPod *k8sv1.Pod
			Eventually(func() k8sv1.PodPhase {
				runningPod, err = clients.K8s.CoreV1().Pods(testNamespace).Get(serverPod.Name, metav1.GetOptions{})
				Expect(err).ToNot(HaveOccurred())
				return runningPod.Status.Phase
			}, 3*time.Minute, 1*time.Second).Should(Equal(k8sv1.PodRunning))

			By("Connecting a client to the server")
			clientArgs := []string{"-ip", runningPod.Status.PodIP, "-port", "30101", "-lport", "30102"}
			clientPod := scptTestPod("sctpclient", clientNode, "sctpclient", clientArgs)
			clients.K8s.CoreV1().Pods(testNamespace).Create(clientPod)

			Eventually(func() k8sv1.PodPhase {
				pod, err := clients.K8s.CoreV1().Pods(testNamespace).Get(serverPod.Name, metav1.GetOptions{})
				Expect(err).ToNot(HaveOccurred())
				return pod.Status.Phase
			}, 1*time.Minute, 1*time.Second).Should(Equal(k8sv1.PodSucceeded))
		})
	})
})

func loadMC() *mcfgv1.MachineConfig {
	decode := mcfgScheme.Codecs.UniversalDeserializer().Decode
	mcoyaml, err := ioutil.ReadFile(mcYaml)
	Expect(err).ToNot(HaveOccurred())

	obj, _, err := decode([]byte(mcoyaml), nil, nil)
	Expect(err).ToNot(HaveOccurred())
	mc, ok := obj.(*mcfgv1.MachineConfig)
	Expect(ok).To(Equal(true))
	return mc
}

func checkForSctpReady(client *kubernetes.Clientset) {
	nodes, err := client.CoreV1().Nodes().List(metav1.ListOptions{
		LabelSelector: "node-role.kubernetes.io/worker=",
	})
	Expect(err).ToNot(HaveOccurred())

	args := []string{`set -x; x="$(checksctp 2>&1)"; echo "$x" ; if [ "$x" = "SCTP supported" ]; then echo "succeeded"; exit 0; else echo "failed"; exit 1; fi`}
	for _, n := range nodes.Items {
		job := jobForNode("checksctp", n.ObjectMeta.Labels[hostnameLabel], "checksctp", []string{"/bin/bash", "-c"}, args)
		client.CoreV1().Pods(testNamespace).Create(job)
	}

	Eventually(func() bool {
		pods, err := client.CoreV1().Pods(testNamespace).List(metav1.ListOptions{LabelSelector: "app=checksctp"})
		ExpectWithOffset(1, err).ToNot(HaveOccurred())

		for _, p := range pods.Items {
			if p.Status.Phase != k8sv1.PodSucceeded {
				return false
			}
		}
		return true
	}, 3*time.Minute, 10*time.Second).Should(Equal(true))
}

func createSctpService(client *kubernetes.Clientset) {
	service := k8sv1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "sctpservice",
			Namespace: testNamespace,
		},
		Spec: k8sv1.ServiceSpec{
			Selector: map[string]string{
				"app": "sctpserver",
			},
			Ports: []k8sv1.ServicePort{
				k8sv1.ServicePort{
					Protocol: k8sv1.ProtocolSCTP,
					Port:     30101,
					TargetPort: intstr.IntOrString{
						Type:   intstr.String,
						StrVal: "sctpserver",
					},
				},
			},
		},
	}
	_, err := client.CoreV1().Services(testNamespace).Create(&service)
	Expect(err).ToNot(HaveOccurred())
}

func scptTestPod(name, node, app string, args []string) *k8sv1.Pod {
	res := k8sv1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			GenerateName: name,
			Labels: map[string]string{
				"app": app,
			},
			Namespace: testNamespace,
		},
		Spec: k8sv1.PodSpec{
			RestartPolicy: k8sv1.RestartPolicyNever,
			Containers: []k8sv1.Container{
				{
					Name:    name,
					Image:   testerImage,
					Command: []string{"/usr/bin/sctptest"},
					Args:    args,
				},
			},
			NodeSelector: map[string]string{
				hostnameLabel: node,
			},
		},
	}

	return &res
}

func jobForNode(name, node, app string, cmd []string, args []string) *k8sv1.Pod {
	job := k8sv1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			GenerateName: name,
			Labels: map[string]string{
				"app": app,
			},
			Namespace: testNamespace,
		},
		Spec: k8sv1.PodSpec{
			RestartPolicy: k8sv1.RestartPolicyNever,
			Containers: []k8sv1.Container{
				{
					Name:    name,
					Image:   "quay.io/wcaban/net-toolbox:latest",
					Command: cmd,
					Args:    args,
				},
			},
			NodeSelector: map[string]string{
				hostnameLabel: node,
			},
		},
	}

	return &job
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
