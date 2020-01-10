package clients

import (
	"log"
	"os"

	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"

	configClientv1 "github.com/openshift/client-go/config/clientset/versioned/typed/config/v1"
	tunedClient "github.com/openshift/cluster-node-tuning-operator/pkg/generated/clientset/versioned"
	mcfgClient "github.com/openshift/machine-config-operator/pkg/generated/clientset/versioned"
)

var K8s *kubernetes.Clientset
var OcpConfig *configClientv1.ConfigV1Client
var MachineConfig *mcfgClient.Clientset

// Cluster Node Tuning Operator client
var CntoConfig *tunedClient.Clientset

func Setup() {
	kubeconfig := os.Getenv("KUBECONFIG")
	if len(kubeconfig) < 0 {
		log.Fatalf("No kubeconfig defined")
	}
	config, err := clientcmd.BuildConfigFromFlags("", kubeconfig)
	if err != nil {
		log.Fatal("Failed to build config", err)
	}

	K8s = kubernetes.NewForConfigOrDie(config)
	OcpConfig = configClientv1.NewForConfigOrDie(config)
	MachineConfig = mcfgClient.NewForConfigOrDie(config)
	CntoConfig = tunedClient.NewForConfigOrDie(config)
}
