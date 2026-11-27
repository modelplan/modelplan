// SPDX-License-Identifier: MIT
package quota

import "github.com/modelplan/modelplan/cli/internal/consent"

// zaiMembership keeps only proof that each scope previously produced a quota
// reading. It carries no account reference, timestamps of readings or values.
// Older installs can recover the proof from a still-admitted last-good capture.
func zaiMembership(cache string, snap *nativeSnap, state consent.State) map[string]*consent.CaptureStamp {
	result := map[string]*consent.CaptureStamp{}
	if snap != nil {
		for _, stamp := range snap.ZaiMembership {
			addZaiMembership(result, stamp, state)
		}
		for i := range snap.Providers {
			if e := &snap.Providers[i]; e.Provider == "zai" {
				rememberZaiMembership(result, e, state)
			}
		}
	}
	if len(result) == 0 {
		rememberZaiMembership(result, loadZaiConfigState(cache).Good, state)
	}
	return result
}

func rememberZaiMembership(result map[string]*consent.CaptureStamp, e *codexbarEntry, state consent.State) {
	if e == nil || e.ObservedAt.IsZero() {
		return
	}
	for _, window := range e.Windows {
		// Historical readings may expire after establishing the ring. A
		// window already expired when observed was never usable.
		if window.ResetsAt != nil && !window.ResetsAt.After(e.ObservedAt) {
			continue
		}
		if window.UsedPercent != nil || window.RemainingPercent != nil {
			addZaiMembership(result, e.Admission, state)
			return
		}
	}
}

func addZaiMembership(result map[string]*consent.CaptureStamp, stamp *consent.CaptureStamp, state consent.State) {
	if stamp == nil || !zaiAccountScope(stamp.Scope) || !state.AllowsScope(stamp.Scope, consent.Automatic) ||
		!state.CaptureAllowed(stamp, stamp.Scope) {
		return
	}
	if previous := result[stamp.Scope]; previous == nil || previous.Generation < stamp.Generation {
		result[stamp.Scope] = stamp
	}
}
