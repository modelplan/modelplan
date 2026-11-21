// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// Replacing the GLM key in Claude Code's settings.json changes the route's login
// generation, so a held "sign-in rejected" state is released (audit C, P2).
func TestZaiClaudeCodeGenerationFollowsSettings(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	settings := filepath.Join(home, ".claude", "settings.json")
	if err := os.MkdirAll(filepath.Dir(settings), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(settings, []byte(`{"env":{"ANTHROPIC_AUTH_TOKEN":"old"}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	writeLegacyConsent(t, `"zai":{"allowed":true,`+legacyAt+`,"readerId":"native:zai","backend":"native","profiles":["claude-code"]}`)
	generation := func() string {
		p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
		g, ok := p.ReaderAccessGrant("zai")
		if !ok || g.ConfigSource == nil || g.ConfigSource.Tool != "claude-code" {
			t.Fatalf("claude-code GLM route not admitted: %+v %v", g, ok)
		}
		return g.Generation
	}
	before := generation()
	if again := generation(); again != before {
		t.Fatalf("generation unstable: %q vs %q", before, again)
	}
	if err := os.WriteFile(settings, []byte(`{"env":{"ANTHROPIC_AUTH_TOKEN":"corrected-key"}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	later := time.Now().Add(time.Minute)
	_ = os.Chtimes(settings, later, later)
	if after := generation(); after == before {
		t.Fatal("corrected key kept the old login generation")
	}
}
