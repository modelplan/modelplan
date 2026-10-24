package qwenusage

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

var now = time.Date(2026, 10, 23, 12, 0, 0, 0, time.UTC)

func fixture(t *testing.T) []byte {
	t.Helper()
	b, e := os.ReadFile("testdata/day.json")
	if e != nil {
		t.Fatal(e)
	}
	return b
}
func put(t *testing.T, p string, b []byte) {
	t.Helper()
	if e := os.WriteFile(p, b, 0600); e != nil {
		t.Fatal(e)
	}
}

func TestExportAndUnknown(t *testing.T) {
	b := fixture(t)
	p, ok := parse(b, now)
	if !ok || p.Stale || len(p.Models) != 1 || *p.Totals.InputTokens != 1200 || *p.Models[0].TotalTokens != 1500 {
		t.Fatalf("%+v, %v", p, ok)
	}
	// Missing is unknown; an explicit zero is known. Do not infer cache/input or
	// thought/output relationships from totals, and discard unrelated private fields.
	b = []byte(`{"period":"month","value":"2026-10","generatedAt":"2026-10-20T12:00:00Z","totals":{"outputTokens":0,"inputTokens":-1},"byModel":[{"key":"qwen/model","outputTokens":0}],"byAuthType":[{"key":"secret-identity"}],"prompt":"secret-prompt"}`)
	p, ok = parse(b, now)
	out, _ := json.Marshal(p)
	if !ok || !p.Stale || p.Totals.InputTokens != nil || p.Totals.CachedTokens != nil || p.Totals.OutputTokens == nil || *p.Totals.OutputTokens != 0 || strings.Contains(string(out), "secret") {
		t.Fatalf("%s, %v", out, ok)
	}
	for _, bad := range []string{
		`{}`, `{"period":"day","value":"2026-02-30","generatedAt":"2026-10-20T12:00:00Z","totals":{},"byModel":[]}`,
		strings.Replace(string(fixture(t)), "2026-10-23T10:00:00Z", "2026-10-24T10:00:00Z", 1),
		strings.Replace(string(fixture(t)), `"day"`, `"weekly"`, 1),
		strings.Replace(string(fixture(t)), `"qwen3-coder"`, `"bad\nmodel"`, 2),
		`{"schemaVersion":1,"sessionId":"not-an-export","inputTokens":12}`,
	} {
		if _, ok := parse([]byte(bad), now); ok {
			t.Errorf("accepted %s", bad)
		}
	}
}

func TestReadOptInBoundsAndReplacement(t *testing.T) {
	if r := Read("", now); r.Status != "off" || len(r.Periods) != 0 {
		t.Fatal(r)
	}
	dir := t.TempDir()
	b := fixture(t)
	p := filepath.Join(dir, "qwen-token-usage-day-2026-10-22.json")
	put(t, p, b)
	put(t, filepath.Join(dir, "qwen-token-usage-repeat.json"), []byte(strings.Replace(string(b), "2026-10-23T10:00:00Z", "2026-10-23T11:00:00Z", 1)))
	put(t, filepath.Join(dir, "oauth_creds.json"), []byte(`not JSON; must not be opened`))
	r := Read(dir, now)
	if r.Status != "ok" || len(r.Periods) != 1 || r.Periods[0].GeneratedAt.Hour() != 11 {
		t.Fatal(r)
	}
	after, _ := os.ReadFile(p)
	if string(after) != string(b) {
		t.Fatal("rewrote export")
	}
	// Keep day and month buckets separately rather than double-counting a total.
	put(t, filepath.Join(dir, "qwen-token-usage-month-2026-10.json"), []byte(strings.Replace(strings.Replace(string(b), `"day"`, `"month"`, 1), `"2026-10-22"`, `"2026-10"`, 1)))
	if r = Read(dir, now); len(r.Periods) != 2 {
		t.Fatal(r)
	}
	link := filepath.Join(dir, "qwen-token-usage-symlink.json")
	if e := os.Symlink(p, link); e != nil {
		t.Fatal(e)
	}
	if r = Read(link, now); r.Status != "invalid" || r.Reason != "unsafe-export" {
		t.Fatal(r)
	}
	if r = Read(dir, now); r.Status != "partial" || len(r.Periods) != 2 {
		t.Fatal(r)
	}
	put(t, filepath.Join(dir, "oversize.json"), []byte(strings.Repeat(" ", maxFile+1)))
	if r = Read(filepath.Join(dir, "oversize.json"), now); r.Reason != "oversized-export" {
		t.Fatal(r)
	}
	if r = Read(filepath.Join(dir, "missing"), now); r.Status != "missing" {
		t.Fatal(r)
	}
}
