package v1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const (
	// TunedDefaultResourceName is the name of the Node Tuning Operator's default custom tuned resource
	TunedDefaultResourceName = "default"

	// TunedRenderedResourceName is the name of the Node Tuning Operator's tuned resource combined out of
	// all the other custom tuned resources
	TunedRenderedResourceName = "rendered"

	// TunedClusterOperatorResourceName is the name of the clusteroperator resource
	// that reflects the node tuning operator status.
	TunedClusterOperatorResourceName = "node-tuning"
)

/////////////////////////////////////////////////////////////////////////////////
// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// Tuned is a collection of rules that allows cluster-wide deployment
// of node-level sysctls and more flexibility to add custom tuning
// specified by user needs.  These rules are translated and passed to all
// containerized tuned daemons running in the cluster in the format that
// the daemons understand. The responsibility for applying the node-level
// tuning then lies with the containerized tuned daemons. More info:
// https://github.com/openshift/cluster-node-tuning-operator
type Tuned struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	// spec is the specification of the desired behavior of Tuned. More info:
	// https://git.k8s.io/community/contributors/devel/api-conventions.md#spec-and-status
	Spec   TunedSpec   `json:"spec,omitempty"`
	Status TunedStatus `json:"status,omitempty"`
}

type TunedSpec struct {
	// Tuned profiles.
	Profile []TunedProfile `json:"profile"`
	// Selection logic for all tuned profiles.
	Recommend []TunedRecommend `json:"recommend"`
}

// A tuned profile.
type TunedProfile struct {
	// Name of the tuned profile to be used in the recommend section.
	Name *string `json:"name"`
	// Specification of the tuned profile to be consumed by the tuned daemon.
	Data *string `json:"data"`
}

// Selection logic for a single tuned profile.
type TunedRecommend struct {
	// Name of the tuned profile to recommend.
	Profile *string `json:"profile"`

	// Tuned profile priority. Highest priority is 0.
	// +kubebuilder:validation:Minimum=0
	Priority *uint64 `json:"priority"`
	// Rules governing application of a tuned profile connected by logical OR operator.
	Match []TunedMatch `json:"match,omitempty"`
}

// Rules governing application of a tuned profile.
type TunedMatch struct {
	// Node or Pod label name.
	Label *string `json:"label"`
	// Node or Pod label value. If omitted, the presence of label name is enough to match.
	Value *string `json:"value,omitempty"`
	// Match type: [node/pod]. If omitted, "node" is assumed.
	// +kubebuilder:validation:Enum={"node","pod"}
	Type *string `json:"type,omitempty"`

	// Additional rules governing application of the tuned profile connected by logical AND operator.
	// +kubebuilder:pruning:PreserveUnknownFields
	Match []TunedMatch `json:"match,omitempty"`
}

// TunedStatus is the status for a Tuned resource
type TunedStatus struct {
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// TunedList is a list of Tuned resources
type TunedList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Tuned `json:"items"`
}

/////////////////////////////////////////////////////////////////////////////////
// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// Profile is a specification for a Profile resource
type Profile struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   ProfileSpec   `json:"spec,omitempty"`
	Status ProfileStatus `json:"status,omitempty"`
}

type ProfileSpec struct {
	Config ProfileConfig `json:"config"`
}

type ProfileConfig struct {
	TunedProfile string `json:"tunedProfile"`
}

// ProfileStatus is the status for a Profile resource
type ProfileStatus struct {
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
// ProfileList is a list of Profile resources
type ProfileList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Profile `json:"items"`
}
