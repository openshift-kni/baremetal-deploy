package test_test

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	mcfgv1 "github.com/openshift/machine-config-operator/pkg/apis/machineconfiguration.openshift.io/v1"
	mcfgScheme "github.com/openshift/machine-config-operator/pkg/generated/clientset/versioned/scheme"

	configClientv1 "github.com/openshift/client-go/config/clientset/versioned/typed/config/v1"
	mcfgClient "github.com/openshift/machine-config-operator/pkg/generated/clientset/versioned"
	k8sv1 "k8s.io/api/core/v1"
	k8serrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/intstr"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

type testClients struct {
	k8sClient       *kubernetes.Clientset
	ocpConfigClient *configClientv1.ConfigV1Client
	mcoClient       *mcfgClient.Clientset
}

var clients *testClients

const mc_yaml = "../sctp_module_mc.yaml" // TODO pass it as a param?
const hostnameLabel = "kubernetes.io/hostname"
const testNamespace = "sctptest"

var _ = BeforeSuite(func() {
	clients = setupClients()
})

func createNamespace(client *kubernetes.Clientset) {
	_, err := client.CoreV1().Namespaces().Create(&k8sv1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: testNamespace,
		}})

	if k8serrors.IsAlreadyExists(err) {
		return
	}

	Expect(err).ToNot(HaveOccurred())
}

func cleanNamespace(client *kubernetes.Clientset) {
	_, err := client.CoreV1().Namespaces().Get(testNamespace, metav1.GetOptions{})
	if err != nil {
		return
	}
	client.CoreV1().Pods(testNamespace).DeleteCollection(&metav1.DeleteOptions{
		GracePeriodSeconds: newInt64(0),
	}, metav1.ListOptions{})
}

var _ = Describe("TestSctp", func() {
	var mc *mcfgv1.MachineConfig

	beforeAll(func() {
		createNamespace(clients.k8sClient)
		cleanNamespace(clients.k8sClient)
		By("Applying the selinux policy")
		applySELinuxPolicy(clients.k8sClient)
		By("Load the mc config")
		mc = loadMC()
		By("Applying the mc config")
		applyMC(clients.mcoClient, clients.k8sClient, mc)
		By("Creating the sctp service")
		createSctpService(clients.k8sClient)
	})

	var _ = Context("Client Server Connection", func() {
		var clientNode string
		var serverNode string
		It("Should connect a client pod to a server pod", func() {
			fmt.Println("aaa")
			By("Choosing the nodes for the server and the client")
			nodes, err := clients.k8sClient.CoreV1().Nodes().List(metav1.ListOptions{
				LabelSelector: "node-role.kubernetes.io/worker=",
			})
			fmt.Println("bbb")
			Expect(err).ToNot(HaveOccurred())
			clientNode = nodes.Items[0].ObjectMeta.Labels[hostnameLabel]
			serverNode = nodes.Items[0].ObjectMeta.Labels[hostnameLabel]
			if len(nodes.Items) > 1 {
				serverNode = nodes.Items[1].ObjectMeta.Labels[hostnameLabel]
			}

			By("Starting the server")
			serverArgs := []string{"sctp_test -H localhost -P 30101 -l 2>&1 > sctp.log & while sleep 10; do if grep --quiet SHUTDOWN sctp.log; then exit 0; fi; done"}
			pod := JobForNode("scptserver", serverNode, "sctpserver", []string{"/bin/bash", "-c"}, serverArgs)
			pod.Spec.Containers[0].Ports = []k8sv1.ContainerPort{
				k8sv1.ContainerPort{
					Name:          "sctpport",
					Protocol:      k8sv1.ProtocolSCTP,
					ContainerPort: 30101,
				},
			}
			serverPod, err := clients.k8sClient.CoreV1().Pods(testNamespace).Create(pod)
			Expect(err).ToNot(HaveOccurred())

			By("Fetching the server's ip address")
			var runningPod *k8sv1.Pod
			Eventually(func() k8sv1.PodPhase {
				runningPod, err = clients.k8sClient.CoreV1().Pods(testNamespace).Get(serverPod.Name, metav1.GetOptions{})
				Expect(err).ToNot(HaveOccurred())
				return runningPod.Status.Phase
			}, 3*time.Minute, 1*time.Second).Should(Equal(k8sv1.PodRunning))

			By("Connecting a client to the server")
			clientArgs := []string{fmt.Sprintf("sctp_test -H localhost -P 30100 -h %s -p 30101 -s", runningPod.Status.PodIP)}
			clientPod := JobForNode("sctpclient", clientNode, "sctpclient", []string{"/bin/bash", "-c"}, clientArgs)
			clients.k8sClient.CoreV1().Pods(testNamespace).Create(clientPod)

			Eventually(func() k8sv1.PodPhase {
				pod, err := clients.k8sClient.CoreV1().Pods(testNamespace).Get(serverPod.Name, metav1.GetOptions{})
				Expect(err).ToNot(HaveOccurred())
				return pod.Status.Phase
			}, 1*time.Minute, 1*time.Second).Should(Equal(k8sv1.PodSucceeded))
		})
	})
})

func setupClients() *testClients {
	kubeconfig := os.Getenv("KUBECONFIG")
	if len(kubeconfig) < 0 {
		log.Fatalf("No kubeconfig defined")
	}
	config, err := clientcmd.BuildConfigFromFlags("", kubeconfig)
	if err != nil {
		log.Fatal("Failed to build config", err)
	}

	res := testClients{}
	res.k8sClient = kubernetes.NewForConfigOrDie(config)
	res.ocpConfigClient = configClientv1.NewForConfigOrDie(config)
	res.mcoClient = mcfgClient.NewForConfigOrDie(config)
	return &res
}

func loadMC() *mcfgv1.MachineConfig {
	decode := mcfgScheme.Codecs.UniversalDeserializer().Decode
	mcoyaml, err := ioutil.ReadFile(mc_yaml)
	Expect(err).ToNot(HaveOccurred())

	obj, _, err := decode([]byte(mcoyaml), nil, nil)
	Expect(err).ToNot(HaveOccurred())
	mc, ok := obj.(*mcfgv1.MachineConfig)
	Expect(ok).To(Equal(true))
	return mc
}

func applyMC(client *mcfgClient.Clientset, k8sClient *kubernetes.Clientset, mc *mcfgv1.MachineConfig) {
	client.MachineconfigurationV1().MachineConfigs().Create(mc)
	waitForMCApplied(client)
	checkForSctpReady(k8sClient)
}

func waitForMCApplied(client *mcfgClient.Clientset) {
	Eventually(func() bool {
		mcp, err := client.MachineconfigurationV1().MachineConfigPools().Get("worker", metav1.GetOptions{})
		ExpectWithOffset(1, err).ToNot(HaveOccurred())
		for _, s := range mcp.Status.Configuration.Source {
			if s.Name == "load-sctp-module" {
				return true
			}
		}
		return false
	}, 15*time.Minute, 10*time.Second).Should(Equal(true)) // long timeout since this requires reboots
}

func checkForSctpReady(client *kubernetes.Clientset) {
	nodes, err := client.CoreV1().Nodes().List(metav1.ListOptions{
		LabelSelector: "node-role.kubernetes.io/worker=",
	})
	Expect(err).ToNot(HaveOccurred())

	args := []string{`set -x; x="$(checksctp 2>&1)"; echo "$x" ; if [ "$x" = "SCTP supported" ]; then echo "succeeded"; exit 0; else echo "failed"; exit 1; fi`}
	for _, n := range nodes.Items {
		job := JobForNode("checksctp", n.ObjectMeta.Labels[hostnameLabel], "checksctp", []string{"/bin/bash", "-c"}, args)
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

func applySELinuxPolicy(client *kubernetes.Clientset) {
	nodes, err := client.CoreV1().Nodes().List(metav1.ListOptions{
		LabelSelector: "node-role.kubernetes.io/worker=",
	})
	Expect(err).ToNot(HaveOccurred())
	for _, n := range nodes.Items {
		createSEPolicyPods(client, n.ObjectMeta.Labels[hostnameLabel])
	}

	Eventually(func() bool {
		pods, err := client.CoreV1().Pods(testNamespace).List(metav1.ListOptions{LabelSelector: "app=sctppolicy"})
		ExpectWithOffset(1, err).ToNot(HaveOccurred())

		for _, p := range pods.Items {
			if p.Status.Phase != k8sv1.PodSucceeded {
				return false
			}
		}
		return true
	}, 3*time.Minute, 1*time.Second).Should(Equal(true))
}

func createSEPolicyPods(client *kubernetes.Clientset, node string) {
	pod := k8sv1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			GenerateName: "sctppolicy",
			Labels: map[string]string{
				"app": "sctppolicy",
			},
			Namespace: testNamespace,
		},
		Spec: k8sv1.PodSpec{
			RestartPolicy: k8sv1.RestartPolicyNever,
			Containers: []k8sv1.Container{
				{
					Name:    "sepolicy",
					Image:   "fedepaol/sctpsepolicy:v1",
					Command: []string{"/bin/sh", "-c"},
					Args: []string{`cp newsctp.pp /host/tmp;
							echo "applying policy";
					        chroot /host /usr/sbin/semodule -i /tmp/newsctp.pp;
					        echo "policy applied";`},
					SecurityContext: &k8sv1.SecurityContext{
						Privileged: newBool(true),
					},
					VolumeMounts: []k8sv1.VolumeMount{
						k8sv1.VolumeMount{
							Name:      "host",
							MountPath: "/host",
						},
					},
				},
			},
			Volumes: []k8sv1.Volume{
				k8sv1.Volume{
					Name: "host",
					VolumeSource: k8sv1.VolumeSource{
						HostPath: &k8sv1.HostPathVolumeSource{
							Path: "/",
							Type: newHostPath(k8sv1.HostPathDirectory),
						},
					},
				},
			},
			NodeSelector: map[string]string{
				hostnameLabel: node,
			},
		},
	}

	_, err := client.CoreV1().Pods(testNamespace).Create(&pod)
	if err != nil {
		log.Fatal("Failed to create policy pod", err)
	}
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

func JobForNode(name, node, app string, cmd []string, args []string) *k8sv1.Pod {
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

func newBool(x bool) *bool {
	return &x
}

func newInt(x int) *int {
	return &x
}

func newInt64(x int64) *int64 {
	return &x
}

func newHostPath(x k8sv1.HostPathType) *k8sv1.HostPathType {
	return &x
}
