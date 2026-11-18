package quota

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/testenv"
)

func seedAccountingLedger(t *testing.T, cache string, raw string) string {
	t.Helper()
	path := filepath.Join(cache, "observed", "accounting.json.gz")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	var b bytes.Buffer
	z := gzip.NewWriter(&b)
	z.Write([]byte(raw))
	z.Close()
	if err := os.WriteFile(path, b.Bytes(), 0600); err != nil {
		t.Fatal(err)
	}
	return path
}

func accountingSources(t *testing.T, path string) map[string]string {
	t.Helper()
	f, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	z, err := gzip.NewReader(f)
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := io.ReadAll(z)
	var l struct {
		Files map[string]struct {
			Source string `json:"source"`
		} `json:"files"`
	}
	if err := json.Unmarshal(raw, &l); err != nil {
		t.Fatal(err)
	}
	out := map[string]string{}
	for k, v := range l.Files {
		out[k] = v.Source
	}
	return out
}

// Forget reports the tool's cached readings deleted, so the per-response accounting ledger must
// lose that tool's records (and only that tool's) before it returns success.
func TestForgetToolErasesAccountingHistory(t *testing.T) {
	for _, tool := range []string{"codex", "claude"} {
		t.Run(tool, func(t *testing.T) {
			testenv.IsolateHome(t)
			cache := t.TempDir()
			path := seedAccountingLedger(t, cache, `{"version":1,"files":{"c":{"source":"codex"},"c2":{"source":"codex"},"k":{"source":"claude-code"}}}`)
			if err := ForgetTool(Paths{Cache: cache}, tool); err != nil {
				t.Fatal(err)
			}
			got := accountingSources(t, path)
			other := map[string]string{"codex": "claude-code", "claude": "codex"}[tool]
			for k, src := range got {
				if src != other {
					t.Fatalf("%s accounting kept after Forget: %s=%s", tool, k, src)
				}
			}
			if len(got) == 0 {
				t.Fatal("the other tool's accounting was erased")
			}
		})
	}
}

// An unreadable ledger cannot be shown clean: Forget must fail rather than report success.
func TestForgetToolFailsWhenAccountingUnreadable(t *testing.T) {
	testenv.IsolateHome(t)
	cache := t.TempDir()
	path := filepath.Join(cache, "observed", "accounting.json.gz")
	os.MkdirAll(filepath.Dir(path), 0700)
	os.WriteFile(path, []byte("not gzip"), 0600)
	if err := ForgetTool(Paths{Cache: cache}, "codex"); err == nil {
		t.Fatal("Forget reported success with an unreadable accounting ledger")
	}
}
