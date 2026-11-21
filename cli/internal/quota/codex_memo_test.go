// SPDX-License-Identifier: MIT
package quota

import (
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// WP-17 (Fable perf plan 5.1 row 1): an unchanged Codex rollout is not read again; a changed,
// replaced or removed one is, and every caller still gets its own values.
func TestCodexRolloutMemoReadsAnUnchangedFileOnce(t *testing.T) {
	forgetCodexRollouts()
	t.Cleanup(forgetCodexRollouts)
	home := t.TempDir()
	day := filepath.Join(home, "sessions", "2026", "11", "20")
	if err := os.MkdirAll(day, 0o700); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(day, "rollout-2026-11-20T10-00-00-0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b.jsonl")
	line := func(at string, used float64) string {
		return fmt.Sprintf(`{"timestamp":%q,"type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","plan_type":"pro","primary":{"used_percent":%v,"window_minutes":300,"resets_at":1795000000},"secondary":{"used_percent":4,"window_minutes":10080,"resets_at":1795500000}}}}`, at, used) + "\n"
	}
	meta := `{"timestamp":"2026-11-20T10:00:00Z","type":"session_meta","payload":{"source":"cli"}}` + "\n"
	turn := `{"timestamp":"2026-11-20T10:00:01Z","type":"turn_context","payload":{"model":"gpt-6.1","effort":"high"}}` + "\n"
	if err := os.WriteFile(path, []byte(meta+turn+line("2026-11-20T10:00:02Z", 10)), 0o600); err != nil {
		t.Fatal(err)
	}
	settled := time.Now().Add(-time.Hour)
	settle := func() { _ = os.Chtimes(path, settled, settled) }
	settle()
	before := rolloutReads.Load()
	first, st := readCodex(home, "")
	if st.Status != "ok" || len(first) != 1 {
		t.Fatalf("first read: %+v %+v", st, first)
	}
	if got := rolloutReads.Load() - before; got != 1 {
		t.Fatalf("first read opened %d rollouts, want 1", got)
	}
	// Each caller owns its values: changing one result must not reach the next.
	*first[0].Windows[0].UsedPercent = 99
	first[0].Harness.Model = "changed"
	second, _ := readCodex(home, "")
	if got := rolloutReads.Load() - before; got != 1 {
		t.Fatalf("an unchanged rollout was read again (%d reads)", got)
	}
	if *second[0].Windows[0].UsedPercent != 10 || second[0].Harness.Model != "gpt-6.1" {
		t.Fatalf("memo shared a caller's values: %+v %+v", second[0].Windows[0], second[0].Harness)
	}
	fresh := func() []Account {
		forgetCodexRollouts()
		a, _ := readCodex(home, "")
		return a
	}
	if want := fresh(); !reflect.DeepEqual(second, want) {
		t.Fatalf("memo result differs from a fresh read:\n%+v\n%+v", second, want)
	}

	// Appended: read again, and the newer reading wins.
	before = rolloutReads.Load()
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	if err != nil {
		t.Fatal(err)
	}
	_, _ = f.WriteString(line("2026-11-20T10:05:00Z", 20))
	_ = f.Close()
	third, _ := readCodex(home, "")
	if rolloutReads.Load()-before != 1 || *third[0].Windows[0].UsedPercent != 20 {
		t.Fatalf("an appended rollout was not read again: %+v", third[0].Windows[0])
	}

	// Rewritten in place at the same size just now: file times can be too coarse to tell, so a
	// file written less than a second before its read is never reused.
	body, _ := os.ReadFile(path)
	same := strings.Replace(string(body), `"used_percent":20`, `"used_percent":25`, 1)
	if len(same) != len(body) {
		t.Fatal("setup: rewrite changes the size")
	}
	_ = os.WriteFile(path, []byte(same), 0o600)
	readCodex(home, "") // read while the write is fresh
	_ = os.WriteFile(path, []byte(strings.Replace(same, `"used_percent":25`, `"used_percent":26`, 1)), 0o600)
	if a, _ := readCodex(home, ""); *a[0].Windows[0].UsedPercent != 26 {
		t.Fatalf("a fresh same-size rewrite was served from the memo: %+v", a[0].Windows[0])
	}
	settle()

	// Replaced by another file of the same size and time (a new inode): read again.
	before = rolloutReads.Load()
	readCodex(home, "") // settled: kept
	before = rolloutReads.Load()
	info, _ := os.Stat(path)
	body, _ = os.ReadFile(path)
	replaced := strings.Replace(string(body), `"used_percent":26`, `"used_percent":30`, 1)
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, []byte(replaced), 0o600); err != nil {
		t.Fatal(err)
	}
	_ = os.Chtimes(tmp, info.ModTime(), info.ModTime())
	if err := os.Rename(tmp, path); err != nil {
		t.Fatal(err)
	}
	fourth, _ := readCodex(home, "")
	if rolloutReads.Load()-before != 1 || *fourth[0].Windows[0].UsedPercent != 30 {
		t.Fatalf("a replaced rollout was not read again: %+v", fourth[0].Windows[0])
	}

	// Removed: nothing is kept for it.
	_ = os.Remove(path)
	if a, st := readCodex(home, ""); len(a) != 0 || st.Status != "missing" {
		t.Fatalf("a removed rollout still read: %+v %+v", a, st)
	}
	if n := codexRolloutMemoSize(); n != 0 {
		t.Fatalf("memo keeps %d entries for removed rollouts", n)
	}
}

// Consent: when Codex local history is no longer admitted, the memo is dropped at the next read.
func TestCodexRolloutMemoIsDroppedWhenLocalHistoryIsNotAdmitted(t *testing.T) {
	forgetCodexRollouts()
	t.Cleanup(forgetCodexRollouts)
	home := t.TempDir()
	day := filepath.Join(home, "sessions", "2026", "11", "20")
	_ = os.MkdirAll(day, 0o700)
	path := filepath.Join(day, "rollout-2026-11-20T10-00-00-0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5c.jsonl")
	_ = os.WriteFile(path, []byte(`{"timestamp":"2026-11-20T10:00:02Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":10,"window_minutes":300}}}}`+"\n"), 0o600)
	if a, _ := readCodex(home, ""); len(a) != 1 || codexRolloutMemoSize() != 1 {
		t.Fatalf("setup: %+v", a)
	}
	state := consent.Empty()
	state.StoreEpoch = "0123456789abcdef0123456789abcdef"
	state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
	denied := consent.NewAdmission(state, consent.Automatic)
	ReadPermitted(Paths{CodexHome: home, Cache: t.TempDir(), Admission: &denied}, time.Now())
	if n := codexRolloutMemoSize(); n != 0 {
		t.Fatalf("memo kept %d rollouts while Codex local history was not admitted", n)
	}
}
