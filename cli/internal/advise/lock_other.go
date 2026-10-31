//go:build !darwin && !linux

package advise

import "time"

// lockState: no cross-process lock where the plugins do not run.
func lockState(string, time.Duration) (func(), error) { return func() {}, nil }
