// SPDX-License-Identifier: MIT
package detect

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func report(detected ...string) Report {
	r := Report{SchemaVersion: 1}
	on := map[string]bool{}
	for _, id := range detected {
		on[id] = true
	}
	for _, id := range []string{"claude", "codex", "cursor", "kimi"} {
		r.Tools = append(r.Tools, Tool{Entry: Entry{ProviderID: id}, Detected: on[id]})
	}
	return r
}

// D238: presence flips between two reports are events; a tool that stays put is not.
func TestD238DiffReportsAppearedAndDisappearedTools(t *testing.T) {
	got := Diff(report("claude", "kimi"), report("claude", "cursor"))
	want := []Change{{ProviderID: "cursor", Kind: ChangeAppeared}, {ProviderID: "kimi", Kind: ChangeDisappeared}}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("diff = %+v, want %+v", got, want)
	}
	if got := Diff(report("claude"), report("claude")); len(got) != 0 {
		t.Fatalf("no change must give no events, got %+v", got)
	}
	if got := Diff(Report{}, report("codex")); !reflect.DeepEqual(got, []Change{{ProviderID: "codex", Kind: ChangeAppeared}}) {
		t.Fatalf("first report: %+v", got)
	}
}

// D238: the tools present when ModelPlan first looks are the first-run baseline; a tool that
// appears afterwards is "installed later" and stays so across restarts, uninstall and reinstall.
func TestD238SeenLedgerMarksToolsInstalledAfterTheBaseline(t *testing.T) {
	path := filepath.Join(t.TempDir(), "detected-tools.json")
	ledger := NewSeenLedger(path, false)
	if later := ledger.Observe(report("claude")); len(later) != 0 {
		t.Fatalf("baseline tools are not installed later: %v", later)
	}
	if later := ledger.Observe(report("claude", "cursor")); !reflect.DeepEqual(later, map[string]bool{"cursor": true}) {
		t.Fatalf("new tool after the baseline: %v", later)
	}
	// A new process (app relaunch, wake) reads the same ledger.
	again := NewSeenLedger(path, false)
	if later := again.Observe(report("claude", "cursor", "kimi")); !reflect.DeepEqual(later, map[string]bool{"cursor": true, "kimi": true}) {
		t.Fatalf("after restart: %v", later)
	}
	// Uninstalled: not offered. Reinstalled: offered again.
	if later := again.Observe(report("claude", "kimi")); !reflect.DeepEqual(later, map[string]bool{"kimi": true}) {
		t.Fatalf("after uninstall: %v", later)
	}
	if later := again.Observe(report("claude", "cursor", "kimi")); !later["cursor"] {
		t.Fatalf("after reinstall: %v", later)
	}
	// A baseline tool that is removed and reinstalled is still a baseline tool.
	again.Observe(report("cursor"))
	if later := again.Observe(report("claude", "cursor")); later["claude"] {
		t.Fatalf("baseline tool turned later: %v", later)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	// Logical tool ids only: no paths, home, user names or signal values.
	if s := string(data); strings.Contains(s, "/") || !strings.Contains(s, `"cursor"`) {
		t.Fatalf("ledger content: %s", s)
	}
	if info, err := os.Stat(path); err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("ledger mode: %v %v", info.Mode(), err)
	}
}

// A read-only engine never writes the ledger; it still answers from memory. A corrupt
// ledger is replaced by a new baseline instead of offering every tool as new.
func TestD238SeenLedgerReadOnlyAndCorrupt(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "detected-tools.json")
	ro := NewSeenLedger(path, true)
	ro.Observe(report("claude"))
	if later := ro.Observe(report("claude", "cursor")); !later["cursor"] {
		t.Fatalf("read-only in memory: %v", later)
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatalf("read-only engine wrote the ledger: %v", err)
	}
	if err := os.WriteFile(path, []byte("{not json"), 0o600); err != nil {
		t.Fatal(err)
	}
	if later := NewSeenLedger(path, false).Observe(report("claude", "cursor")); len(later) != 0 {
		t.Fatalf("corrupt ledger must rebaseline, got %v", later)
	}
}
