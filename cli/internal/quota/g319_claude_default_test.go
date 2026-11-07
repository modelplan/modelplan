// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
)

// G3-19 / D27: Claude Code's saved login is admitted by default on a fresh profile, never
// with the Keychain, and any recorded ModelPlan decision about Claude Code wins.
func TestG319ClaudeDefaultGrantYieldsToDecisions(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	if err := os.MkdirAll(filepath.Join(home, ".claude"), 0o700); err != nil {
		t.Fatal(err)
	}
	fresh := consent.Empty()
	// A Keychain-only (or credential-agent) login is not read by default.
	if _, ok := defaultClaudeGrant(fresh, consent.Automatic, "0.5.53", nil); ok {
		t.Fatal("no saved-login file, but a default grant was made")
	}
	if err := os.WriteFile(filepath.Join(home, ".claude", ".credentials.json"), []byte("{}"), 0o600); err != nil {
		t.Fatal(err)
	}
	g, ok := defaultClaudeGrant(fresh, consent.Automatic, "0.5.53", nil)
	if !ok || !g.SavedLogin || len(g.Profiles) != 1 {
		t.Fatalf("fresh profile: grant=%t savedLogin=%t profiles=%d", ok, g.SavedLogin, len(g.Profiles))
	}
	if g.Keychain || g.KeychainPriorGrant || g.KeychainConsent != "unset" {
		t.Fatalf("default grant must not include the Keychain: keychain=%t prior=%t consent=%s", g.Keychain, g.KeychainPriorGrant, g.KeychainConsent)
	}
	if _, ok := defaultClaudeGrant(fresh, consent.Passive, "0.5.53", nil); ok {
		t.Fatal("passive mode admitted a saved-login read")
	}
	denied := consent.Empty()
	denied.Tools["claude"] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
	if _, ok := defaultClaudeGrant(denied, consent.Automatic, "0.5.53", nil); ok {
		t.Fatal("a recorded Claude refusal was overridden by the default")
	}
	refused := consent.Empty()
	refused.Scopes[consent.ScopeClaudeAccountUsageSavedLogin] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
	if _, ok := defaultClaudeGrant(refused, consent.Automatic, "0.5.53", nil); ok {
		t.Fatal("a refused saved-login scope was overridden by the default")
	}
	reset := consent.Empty()
	reset.RequireConsent = true
	if _, ok := defaultClaudeGrant(reset, consent.Automatic, "0.5.53", nil); ok {
		t.Fatal("a reset store (RequireConsent) admitted the default")
	}
	routed := map[string]detect.Entry{"claude": {ProviderID: "claude", Preferred: "codexbar", ReaderID: "codexbar:claude"}}
	if _, ok := defaultClaudeGrant(fresh, consent.Automatic, "0.5.53", routed); ok {
		t.Fatal("a published non-native route admitted the native default")
	}
	if err := os.RemoveAll(filepath.Join(home, ".claude")); err != nil {
		t.Fatal(err)
	}
	if _, ok := defaultClaudeGrant(fresh, consent.Automatic, "0.5.53", nil); ok {
		t.Fatal("no Claude Code profile, but a grant was made")
	}
}

// D41: a Keychain-only login on a fresh profile reports the Keychain step without a
// reader or a Keychain access, and every recorded decision or file login ends it.
func TestD41ClaudeKeychainPending(t *testing.T) {
	isolateHome(t)
	t.Setenv("CLAUDE_CONFIG_DIR", "")
	old := claudeKeychainPlatform
	t.Cleanup(func() { claudeKeychainPlatform = old })
	claudeKeychainPlatform = func() bool { return true }
	home, _ := os.UserHomeDir()
	root := filepath.Join(home, ".claude")
	fresh := consent.Empty()
	if claudeKeychainPending(fresh, consent.Automatic, "0.5.53", nil) {
		t.Fatal("no Claude Code directory must not ask for the Keychain")
	}
	if err := os.MkdirAll(root, 0o700); err != nil {
		t.Fatal(err)
	}
	if !claudeKeychainPending(fresh, consent.Automatic, "0.5.53", nil) {
		t.Fatal("Keychain-only login was not reported")
	}
	if _, ok := defaultClaudeGrant(fresh, consent.Automatic, "0.5.53", nil); ok {
		t.Fatal("Keychain-only login gained a background reader")
	}
	if claudeKeychainPending(fresh, consent.Passive, "0.5.53", nil) {
		t.Fatal("Passive mode reported the Keychain step")
	}
	decided := consent.Empty()
	decided.Tools["claude"] = consent.Record{Allowed: false}
	if claudeKeychainPending(decided, consent.Automatic, "0.5.53", nil) {
		t.Fatal("a recorded Claude decision reported the Keychain step")
	}
	routed := map[string]detect.Entry{"claude": {Preferred: "codexbar", ReaderID: "codexbar:claude"}}
	if claudeKeychainPending(fresh, consent.Automatic, "0.5.53", routed) {
		t.Fatal("a published non-native route reported the Keychain step")
	}
	claudeKeychainPlatform = func() bool { return false }
	if claudeKeychainPending(fresh, consent.Automatic, "0.5.53", nil) {
		t.Fatal("only macOS has a Keychain step")
	}
	claudeKeychainPlatform = func() bool { return true }
	t.Setenv("CLAUDE_CONFIG_DIR", root)
	if claudeKeychainPending(fresh, consent.Automatic, "0.5.53", nil) {
		t.Fatal("a custom Claude profile has no Keychain step")
	}
	t.Setenv("CLAUDE_CONFIG_DIR", "")
	if err := os.WriteFile(filepath.Join(root, ".credentials.json"), []byte("{}"), 0o600); err != nil {
		t.Fatal(err)
	}
	if claudeKeychainPending(fresh, consent.Automatic, "0.5.53", nil) {
		t.Fatal("a saved-login file does not need the Keychain")
	}
}
