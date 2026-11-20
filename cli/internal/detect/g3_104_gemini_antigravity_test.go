// SPDX-License-Identifier: MIT
package detect

import (
	"os"
	"path/filepath"
	"testing"
)

// G3-104 (owner build 14e): Settings said "Gemini CLI · detected" on a Mac with only Google
// Antigravity, which keeps its own data under ~/.gemini/antigravity (and global rules in
// ~/.gemini/GEMINI.md). A bare ~/.gemini is shared, so it is no Gemini CLI signal; the
// gemini command, the Gemini CLI's sign-in file or its chat history is. Synthetic homes only.
func TestG3104AntigravityHomeIsNotGeminiCLI(t *testing.T) {
	gemini := func(t *testing.T, home string) Tool {
		t.Helper()
		for _, tool := range Run(Fallback(), Env{Home: home, Path: filepath.Join(home, "bin"), OS: "darwin"}, "1.0.0", "built-in").Tools {
			if tool.ProviderID == "gemini" {
				return tool
			}
		}
		t.Fatal("no Gemini CLI detector")
		return Tool{}
	}
	write := func(t *testing.T, home, rel string, mode os.FileMode) {
		t.Helper()
		p := filepath.Join(home, filepath.FromSlash(rel))
		if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte("synthetic\n"), mode); err != nil {
			t.Fatal(err)
		}
	}
	antigravity := t.TempDir()
	write(t, antigravity, ".gemini/antigravity/brain/synthetic.pb", 0o600)
	write(t, antigravity, ".gemini/GEMINI.md", 0o600)
	if tool := gemini(t, antigravity); tool.Detected {
		t.Fatalf("Antigravity's ~/.gemini reads as Gemini CLI: %s", tool.Status)
	}
	signedIn := t.TempDir()
	write(t, signedIn, ".gemini/oauth_creds.json", 0o600)
	if tool := gemini(t, signedIn); !tool.Detected {
		t.Fatalf("a Gemini CLI sign-in is not detected: %s", tool.Status)
	}
	history := t.TempDir()
	write(t, history, ".gemini/tmp/synthetic/chats/session-synthetic.json", 0o600)
	if tool := gemini(t, history); !tool.Detected {
		t.Fatalf("Gemini CLI history is not detected: %s", tool.Status)
	}
	installed := t.TempDir()
	write(t, installed, "bin/gemini", 0o700)
	if tool := gemini(t, installed); !tool.Detected {
		t.Fatalf("the gemini command is not detected: %s", tool.Status)
	}
}
