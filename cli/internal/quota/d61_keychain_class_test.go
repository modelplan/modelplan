// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// D61 (owner 2026-11-08, #718): before the first-run Done, readers that never prompt may read
// (D27), while any reader that can show a macOS Keychain prompt reads only after the user ticked
// it. The test goes through real admission on a fresh store and a synthetic HOME: the grants the
// production constructor builds must follow the scope's access class (ScopeDefinition.Keychain),
// never a vendor list.
func TestD61KeychainClassWaitsForTheFirstRunChoice(t *testing.T) {
	isolateHome(t)
	t.Setenv("CLAUDE_CONFIG_DIR", "")
	old := claudeKeychainPlatform
	t.Cleanup(func() { claudeKeychainPlatform = old })
	claudeKeychainPlatform = func() bool { return true }
	home, _ := os.UserHomeDir()
	if _, err := os.Stat(consent.Path()); !os.IsNotExist(err) {
		t.Fatal("fixture must start without consent decisions")
	}
	keychainTool, plainTool := map[string]bool{}, map[string]bool{}
	for _, d := range consent.Definitions() {
		if d.Keychain {
			keychainTool[d.Tool] = true
		} else if d.DefaultCheck {
			plainTool[d.Tool] = true
		}
	}
	if !keychainTool["claude"] || !plainTool["zai"] {
		t.Fatalf("expected Claude saved login (prompting) and ZCode key (plain) in the compiled policy: %v %v", keychainTool, plainTool)
	}
	root := filepath.Join(home, ".claude")
	if err := os.MkdirAll(root, 0o700); err != nil {
		t.Fatal(err)
	}
	writeZCodeProviders(t, home, zcodeTemplateProvider)

	// A Keychain-only Claude Code login: nothing prompting is admitted, the Keychain step is
	// pending, and the plain ZCode key route is admitted without any click.
	p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
	if _, ok := p.ReaderAccessGrant("claude"); ok {
		t.Fatal("a Keychain-only Claude Code login was admitted before the first-run choice")
	}
	if !p.ClaudeKeychainPending {
		t.Fatal("the Keychain step is not pending on a fresh profile")
	}
	if g, ok := p.ReaderAccessGrant("zai"); !ok || g.ConfigSource == nil || g.ConfigSource.Tool != "zcode" {
		t.Fatal("a reader that never prompts is not admitted by default (D27)")
	}

	// A Claude Code login kept in its own file needs no Keychain, so it is admitted, but no
	// grant of a prompting scope may carry Keychain access before a choice.
	if err := os.WriteFile(filepath.Join(root, ".credentials.json"), []byte("{}"), 0o600); err != nil {
		t.Fatal(err)
	}
	p = ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
	if g, ok := p.ReaderAccessGrant("claude"); !ok || !g.SavedLogin {
		t.Fatal("a file login on a fresh profile is not admitted")
	}
	for id, g := range p.ReaderAccess.Grants {
		if keychainTool[strings.SplitN(id, ".", 2)[0]] && (g.Keychain || g.KeychainPriorGrant || g.KeychainConsent == "allowed") {
			t.Fatalf("%s can prompt for the Keychain but its grant includes it before any choice: %+v", id, g)
		}
	}
}
