package localusage

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/tokenacct"
)

var acctNow = time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)

// copyTree copies the shared tokenacct fixtures (redacted, real-shaped) under root.
func copyTree(t *testing.T, from, root string) {
	t.Helper()
	err := filepath.Walk(from, func(path string, fi os.FileInfo, err error) error {
		if err != nil || fi.IsDir() {
			return err
		}
		b, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(from, path)
		fixtureFile(t, filepath.Join(root, rel), string(b))
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

func localUTC(t *testing.T) {
	old := time.Local
	time.Local = time.UTC
	t.Cleanup(func() { time.Local = old })
}

func checkWindow(t *testing.T, name string, got tokenacct.Buckets, input, read, output, reasoning, total int64) {
	t.Helper()
	if got.Input != input || got.CacheRead != read || got.CacheWrite != 0 || got.Output != output || got.Reasoning != reasoning || got.Total != total {
		t.Fatalf("%s = %+v", name, got)
	}
}

// The Gemini report carries ccusage's accounting beside the native rows. Hand-checked numbers:
// see tokenacct.TestGeminiMatchesCcusage. A chats folder outside tmp/ is native-only, as
// ccusage reads only ~/.gemini/tmp.
func TestGeminiReportCarriesCcusageAccounting(t *testing.T) {
	localUTC(t)
	home, root := setup(t)
	copyTree(t, "../tokenacct/testdata/gemini", root)
	fixtureFile(t, filepath.Join(root, "outside", "chats", "session-x.json"), sessionJSON(strings.ReplaceAll(messageOne, "2026-10-23", "2026-11-16")))
	r := ReadGemini(home, acctNow)
	if r.Status != "ok" || r.Accounting == nil {
		t.Fatalf("%+v", r)
	}
	a := r.Accounting
	checkWindow(t, "today", a.Today, 24208, 12126, 603, 1039, 37976)
	checkWindow(t, "7d", a.Last7d, 27208, 12126, 703, 1039, 41076)
	if a.Last30d != a.Last7d || a.Entries != 4 || a.Reference != tokenacct.Reference {
		t.Fatalf("%+v", a)
	}
	b, _ := json.Marshal(r)
	for _, leak := range []string{"redacted-session", "redacted-project-hash", "[redacted]", "PRIVATE"} {
		if strings.Contains(string(b), leak) {
			t.Fatalf("%q in report", leak)
		}
	}
}

// Qwen: see tokenacct.TestQwenMatchesCcusage. The resumed copy of q-a1 counts once.
func TestQwenReportCarriesCcusageAccounting(t *testing.T) {
	localUTC(t)
	home, root := setupQwen(t)
	copyTree(t, "../tokenacct/testdata/qwen", root)
	r := ReadQwen(home, acctNow)
	if r.Accounting == nil {
		t.Fatalf("%+v", r)
	}
	checkWindow(t, "today", r.Accounting.Today, 12500, 8000, 340, 10, 20850)
	checkWindow(t, "7d", r.Accounting.Last7d, 12500, 8000, 661, 10, 21171)
}

// Without countable usage the report keeps its earlier shape.
func TestNoAccountingWithoutUsage(t *testing.T) {
	home, _ := setup(t)
	if r := ReadGemini(home, acctNow); r.Accounting != nil {
		t.Fatalf("%+v", r.Accounting)
	}
}
