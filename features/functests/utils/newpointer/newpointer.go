package newpointer

import (
	k8sv1 "k8s.io/api/core/v1"
)

// Bool returns a bool pointer from the given bool
func Bool(x bool) *bool {
	return &x
}

// Int returns a Int pointer from the given Int
func Int(x int) *int {
	return &x
}

// Int64 returns a Int64 pointer from the given Int64
func Int64(x int64) *int64 {
	return &x
}

// HostPath returns a HostPath pointer from the given HostPath
func HostPath(x k8sv1.HostPathType) *k8sv1.HostPathType {
	return &x
}
