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
