// SPDX-License-Identifier: MIT
package quota

import "github.com/modelplan/modelplan/cli/internal/consent"

func captureScope(p Paths, provider string, bridge bool) string {
	state := admissionFor(p).State()
	if bridge {
		return state.ScopeFor(provider, consent.Bridge)
	}
	class := consent.Credential
	if n := nativeReaders[provider]; n != nil && n.KeyEnv != "" {
		g, _ := p.ReaderAccessGrant(provider)
		if n.Managed == nil || !g.SavedLogin {
			class = consent.ExplicitKey
		}
	}
	return state.ScopeFor(provider, class)
}
func captureFor(p Paths, provider string, bridge bool) *consent.CaptureStamp {
	if !bridge {
		if g, ok := p.ReaderAccessGrant(provider); ok && g.Admission != nil {
			return g.Admission
		}
	}
	return admissionFor(p).State().CaptureStamp(captureScope(p, provider, bridge))
}
func captureAllowed(p Paths, provider string, stamp *consent.CaptureStamp, bridge bool) bool {
	admission := admissionFor(p)
	return admission.Mode() != consent.Off && admission.State().CaptureAllowed(stamp, captureScope(p, provider, bridge))
}
func typedCaptureAllowed(stamp *consent.CaptureStamp, scope string, check func(*consent.CaptureStamp) bool) bool {
	if check != nil {
		return check(stamp)
	}
	state, err := consent.Load(consent.Path())
	if err != nil {
		return false
	}
	return state.Effective("") != consent.Off && state.CaptureAllowed(stamp, scope)
}
