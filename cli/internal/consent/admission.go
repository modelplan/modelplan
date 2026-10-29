// SPDX-License-Identifier: MIT
package consent

// Admission is the immutable permission input for one snapshot attempt. Copies
// share no mutable permission state with callers. Live generation checks remain
// separate: this value never makes a revoked reader or publication valid.
type Admission struct {
	state   State
	mode    string
	cleanup map[string]bool
}

func Capture() Admission {
	state, mode := Current()
	return NewAdmission(state, mode)
}

func NewAdmission(state State, mode string) Admission {
	switch mode {
	case Automatic, Passive, Off:
	default:
		mode = Off
	}
	cleanup := map[string]bool{}
	for _, receipt := range state.Requests {
		for _, tool := range receipt.PendingForget {
			cleanup[tool] = true
		}
	}
	return Admission{state: permissionCopy(state), mode: mode, cleanup: cleanup}
}

// State returns a detached copy for projection adapters. Receipts and hints are
// intentionally excluded: they are mutation metadata, not admission facts.
func (a Admission) State() State                    { return permissionCopy(a.state) }
func (a Admission) CleanupPending(tool string) bool { return a.cleanup[tool] }
func (a Admission) Generation() uint64              { return a.state.Generation }
func (a Admission) Mode() string {
	if a.mode == "" {
		return Off
	}
	return a.mode
}
func (a Admission) Allows(tool, class string) bool {
	return a.state.Allows(tool, class, a.Mode())
}
func (a Admission) KeychainStatus(tool string) string {
	return a.state.KeychainStatus(tool, a.Mode())
}

func permissionCopy(state State) State {
	copy := State{SchemaVersion: state.SchemaVersion, Generation: state.Generation, Privacy: state.Privacy, Tools: make(map[string]Record, len(state.Tools))}
	for id, record := range state.Tools {
		record.Profiles = append([]string(nil), record.Profiles...)
		if record.DeniedSources != nil {
			denied := make(map[string]bool, len(record.DeniedSources))
			for source, value := range record.DeniedSources {
				denied[source] = value
			}
			record.DeniedSources = denied
		}
		copy.Tools[id] = record
	}
	return copy
}

// BuildStable fences the complete publication, including projections built
// after the reader report. A changed generation discards the entire result and
// retries once. The second change calls failClosed with the newest permission
// input; the caller retains only declarations and marks publication pending.
// Neither callback may print a result: only the returned value is publishable.
func BuildStable[T any](build func(Admission) T, failClosed func(Admission) T) T {
	for attempt := 0; attempt < 2; attempt++ {
		admission := Capture()
		result := build(admission)
		if CurrentGeneration(admission.Generation()) {
			return result
		}
	}
	return failClosed(Capture())
}
