// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
)

// defaultClaudeGrant: Claude Code's own saved login is a standard reader, on by default
// (owner decision D27, 2026-11-06, G3-19) for a user who has made no ModelPlan decision
// about Claude Code. It admits the same native saved-login reader an explicit grant would,
// for local profiles with their own saved-login file only. The Keychain keeps its own
// recorded choice: the default never includes it, so no macOS prompt appears by default.
// A recorded Claude decision (allow, deny, other backend, environment key) always takes
// precedence and goes through the ordinary grant loop.
func defaultClaudeGrant(state consent.State, mode, version string, routes map[string]detect.Entry) (ReaderGrant, bool) {
	const id = "claude"
	scope := consent.ScopeClaudeAccountUsageSavedLogin
	n, ok := claudeDefaultReader(state, mode, version, routes)
	if !ok {
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
	// Only a profile whose own saved-login file is present (stat only; it is opened at
	// read time). A login kept only in the macOS Keychain, or delivered by the app's
	// credential agent, needs the user's Keychain choice first; a default read there
	// could only fail. claudeKeychainPending reports that case without any read.
	for _, profile := range n.Profiles() {
		if !detect.LocalRoot(profile.Root) {
			continue
		}
		if fi, err := os.Lstat(filepath.Join(profile.Root, ".credentials.json")); err == nil && fi.Mode().IsRegular() {
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

// claudeDefaultReader is the admission both default outcomes share: no recorded Claude
// decision, Automatic mode, an admitted scope and no published non-native route.
func claudeDefaultReader(state consent.State, mode, version string, routes map[string]detect.Entry) (*nativeReader, bool) {
	const id = "claude"
	if _, decided := state.Tools[id]; decided || mode != consent.Automatic || !state.AllowsScope(consent.ScopeClaudeAccountUsageSavedLogin, mode) {
		return nil, false
	}
	n := nativeReaders[id]
	if n == nil || n.Managed == nil {
		return nil, false
	}
	if route, exists := routes[id]; exists && (route.Preferred != "native" || !strings.HasPrefix(route.ReaderID, "native:") || !detect.Compatible(version, route.MinCLI)) {
		return nil, false
	}
	return n, true
}

var claudeKeychainPlatform = func() bool { return runtime.GOOS == "darwin" }

// claudeKeychainPending (D41): Claude Code is present, its login can only be in the macOS
// Keychain and the user has not chosen yet. The row then asks for the Keychain permission.
// This is stat-only: no reader runs, so the Keychain is untouched and no failed attempt
// holds back the read that follows Allow. A Claude Code that is not logged in looks the
// same here; only the Keychain read can tell them apart.
func claudeKeychainPending(state consent.State, mode, version string, routes map[string]detect.Entry) bool {
	n, ok := claudeDefaultReader(state, mode, version, routes)
	if !ok || !claudeKeychainPlatform() || os.Getenv("CLAUDE_CONFIG_DIR") != "" || state.KeychainStatus("claude", mode) != "unset" {
		return false
	}
	profiles := n.Profiles()
	if len(profiles) != 1 || !detect.LocalRoot(profiles[0].Root) || claudeLoginUnsupported(profiles[0].Root) != "" {
		return false
	}
	if fi, err := os.Stat(profiles[0].Root); err != nil || !fi.IsDir() {
		return false
	}
	_, err := os.Lstat(filepath.Join(profiles[0].Root, ".credentials.json"))
	return os.IsNotExist(err)
}
