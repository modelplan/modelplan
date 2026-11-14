// SPDX-License-Identifier: MIT
package detect

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

// One synthetic home per case: the files a tool creates, and which tools that must make
// detected. A folder that another tool also creates must not detect the wrong tool
// (G3-104: Antigravity's ~/.gemini; Kiro IDE's ~/.kiro). Detection stats paths only.
func TestEachToolIsDetectedOnlyFromItsOwnSignals(t *testing.T) {
	// Commands installed on the test host itself (fixed dirs such as /usr/local/bin) are
	// outside the synthetic home; leave those tools out of the comparison.
	host := map[string]bool{}
	for _, tool := range Run(Fallback(), Env{Home: t.TempDir(), Path: t.TempDir(), OS: "darwin"}, "1.0.0", "built-in").Tools {
		host[tool.ProviderID] = tool.Detected
	}
	for _, tc := range []struct {
		name  string
		files []string // "bin/<cmd>" is an executable; anything else a file under home
		want  []string
	}{
		{"empty home", nil, nil},
		{"Claude Code command", []string{"bin/claude"}, []string{"claude"}},
		{"Claude Code home", []string{".claude/settings.json"}, []string{"claude"}},
		{"Codex home", []string{".codex/config.toml"}, []string{"codex"}},
		{"ZCode desktop", []string{"Library/Application Support/ZCode/state"}, []string{"zai"}},
		{"Cursor home", []string{".cursor/argv.json"}, []string{"cursor"}},
		{"Copilot CLI home", []string{".copilot/config.json"}, []string{"copilot"}},
		{"Gemini CLI sign-in", []string{".gemini/oauth_creds.json"}, []string{"gemini"}},
		{"Gemini CLI history", []string{".gemini/tmp/p/chats/session-1.json"}, []string{"gemini"}},
		{"Gemini CLI command", []string{"bin/gemini"}, []string{"gemini"}},
		{"Antigravity only", []string{".gemini/antigravity/brain/x.pb", ".gemini/GEMINI.md"}, []string{"antigravity"}},
		{"Antigravity launcher", []string{"bin/antigravity"}, []string{"antigravity"}},
		{"Antigravity and Gemini CLI", []string{".gemini/antigravity/brain/x.pb", ".gemini/oauth_creds.json"}, []string{"antigravity", "gemini"}},
		{"Kimi Code", []string{".kimi-code/config.toml"}, []string{"kimi"}},
		{"Qwen Code", []string{".qwen/settings.json"}, []string{"qwen"}},
		{"OpenCode config", []string{".config/opencode/opencode.json"}, []string{"opencodego"}},
		{"OpenCode command", []string{"bin/opencode"}, []string{"opencodego"}},
		{"Kiro IDE only", []string{".kiro/settings/mcp.json"}, nil},
		{"Kiro CLI", []string{"bin/kiro-cli"}, []string{"kiro"}},
		{"Amp", []string{".local/share/amp/threads/x.json"}, []string{"amp"}},
		{"Droid", []string{".factory/settings.json"}, []string{"droid"}},
		{"Grok Build", []string{".grok/auth.json"}, []string{"grok"}},
		{"bare gemini folder", []string{".gemini/settings.json"}, nil},
	} {
		t.Run(tc.name, func(t *testing.T) {
			home := t.TempDir()
			bin := filepath.Join(home, "bin")
			if err := os.MkdirAll(bin, 0o700); err != nil {
				t.Fatal(err)
			}
			for _, f := range tc.files {
				p := filepath.Join(home, filepath.FromSlash(f))
				if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
					t.Fatal(err)
				}
				mode := os.FileMode(0o600)
				if strings.HasPrefix(f, "bin/") {
					mode = 0o700
				}
				if err := os.WriteFile(p, []byte("synthetic\n"), mode); err != nil {
					t.Fatal(err)
				}
			}
			got := []string{}
			for _, tool := range Run(Fallback(), Env{Home: home, Path: bin, OS: "darwin"}, "1.0.0", "built-in").Tools {
				if tool.Detected && !host[tool.ProviderID] {
					got = append(got, tool.ProviderID)
				}
			}
			sort.Strings(got)
			want := []string{}
			for _, id := range tc.want {
				if !host[id] {
					want = append(want, id)
				}
			}
			sort.Strings(want)
			if strings.Join(got, ",") != strings.Join(want, ",") {
				t.Fatalf("detected %v, want %v", got, want)
			}
		})
	}
}
