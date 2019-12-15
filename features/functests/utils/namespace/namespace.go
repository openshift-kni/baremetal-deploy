package namespace

import (
	. "github.com/onsi/gomega"

	k8sv1 "k8s.io/api/core/v1"
	k8serrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/utils/pointer"
)

// Create creates a new namespace with the given name.
// If the namespace exists, it returns.
func Create(namespace string, client *kubernetes.Clientset) {
	_, err := client.CoreV1().Namespaces().Create(&k8sv1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: namespace,
		}})

	if k8serrors.IsAlreadyExists(err) {
		return
	}

	Expect(err).ToNot(HaveOccurred())
}

// Clean cleans all dangling objects from the given namespace.
func Clean(namespace string, client *kubernetes.Clientset) {
	_, err := client.CoreV1().Namespaces().Get(namespace, metav1.GetOptions{})
	if err != nil {
		return
	}
	client.CoreV1().Pods(namespace).DeleteCollection(&metav1.DeleteOptions{
		GracePeriodSeconds: pointer.Int64Ptr(0),
	}, metav1.ListOptions{})
}
