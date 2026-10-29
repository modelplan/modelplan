// SPDX-License-Identifier: MIT
package consent

import "strings"

// RetryCleanup retries durable erasure obligations without replaying a mutation,
// changing permissions, or changing the original receipt returned to a client.
// The engine calls it after in-flight readers drain and on restart.
func RetryCleanup(file string, cleanup func(scope string, forget bool) error) error {
	unlock, err := lockFile(file + ".lock")
	if err != nil {
		return err
	}
	defer unlock()
	state, err := loadLocked(file)
	if err != nil {
		return err
	}
	changed := false
	for id, receipt := range state.Requests {
		pending := []string{}
		for _, scope := range receipt.PendingForget {
			forget := receipt.ForgetScopes[scope] || !strings.Contains(scope, ".")
			if cleanup == nil || cleanup(scope, forget) != nil {
				pending = append(pending, scope)
			} else {
				changed = true
			}
		}
		receipt.PendingForget = pending
		state.Requests[id] = receipt
	}
	if changed {
		return save(file, state)
	}
	return nil
}
