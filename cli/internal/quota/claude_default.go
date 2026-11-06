// SPDX-License-Identifier: MIT
package quota

import (
	"strconv"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
)

// defaultClaudeGrant: Claude Code's own saved login is a standard reader, on by default
// (owner decision D27, 2026-11-06, G3-19) for a user who has made no ModelPlan decision
// about Claude Code. It admits the same native saved-login reader an explicit grant would,
// for local profiles only. The Keychain keeps its own recorded choice: without one the
// reader never touches the Keychain and reports its next step instead, so no macOS prompt
// appears by default. A recorded Claude decision (allow, deny, other backend, environment
// key) always takes precedence and goes through the ordinary grant loop.
func defaultClaudeGrant(state consent.State, mode, version string, routes map[string]detect.Entry) (ReaderGrant, bool) {
	const id = "claude"
	scope := consent.ScopeClaudeAccountUsageSavedLogin
	if _, decided := state.Tools[id]; decided || mode != consent.Automatic || !state.AllowsScope(scope, mode) {
		return ReaderGrant{}, false
	}
	n := nativeReaders[id]
	if n == nil || n.Managed == nil {
		return ReaderGrant{}, false
	}
	if route, exists := routes[id]; exists && (route.Preferred != "native" || !strings.HasPrefix(route.ReaderID, "native:") || !detect.Compatible(version, route.MinCLI)) {
		return ReaderGrant{}, false
	}
	fence := state.Fence()
	g := ReaderGrant{Admission: state.CaptureStamp(scope), CaptureAllowed: func(stamp *consent.CaptureStamp) bool { return state.CaptureAllowed(stamp, scope) },
		Generation: fence.StoreEpoch + ":" + strconv.FormatUint(state.Generation, 10),
		Publish:    func(write func() error) error { return consent.Publish(fence, write) },
		StillValid: func() bool {
			current, effective := consent.Current()
			return effective == consent.Automatic && !nativeOff() && current.Fence() == fence
		}}
	for _, profile := range n.Profiles() {
		if detect.LocalRoot(profile.Root) {
			g.Profiles = append(g.Profiles, profile)
		}
	}
	if len(g.Profiles) == 0 {
		return ReaderGrant{}, false
	}
	g.SavedLogin = true
	g.KeychainConsent = state.KeychainStatus(id, mode)
	g.Keychain = false
	g.KeychainPriorGrant = false
	return g, true
}
