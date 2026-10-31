//go:build !darwin && !linux

package advise

// lockState: no cross-process lock where the plugins do not run.
func lockState(string) (func(), error) { return func() {}, nil }
