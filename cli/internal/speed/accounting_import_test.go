// SPDX-License-Identifier: MIT
package speed

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func accountingImportLog(t *testing.T, f *fixture, source string, offsets ...float64) (string, int64) {
	t.Helper()
	if source == "codex" {
		return f.codexLog("rollout-window.jsonl", offsets...), 300
	}
	return f.claudeLog("window.jsonl", offsets...), 400
}
func accountingImportedOutput(t *testing.T, f *fixture, source string) int64 {
	t.Helper()
	l, ok := LoadPerf(f.cache)
	if !ok {
		t.Fatal("unreadable perf")
	}
	v := (PerfView{Ledger: l, OK: true, Recording: true, Now: f.now}).Admitted(*both())
	for _, w := range v.HistoryWindows() {
		if w.Source == source {
			return w.Recent30d.ObservedOutputTokens
		}
	}
	return 0
}
func TestAccountingImportRespectsRequestedInterval(t *testing.T) {
	for _, source := range []string{"codex", "claude-code"} {
		t.Run(source, func(t *testing.T) {
			f := newFixture(t)
			_, out := accountingImportLog(t, f, source, -20, -1)
			seedPerf(t, f.cache, t0)
			f.run(7, both())
			if got := accountingImportedOutput(t, f, source); got != out {
				t.Fatalf("7-day import included out-of-range response: output %d want %d", got, out)
			}
		})
	}
}
func TestAccountingPartialRetryKeepsPriorIntervals(t *testing.T) {
	for _, source := range []string{"codex", "claude-code"} {
		t.Run(source, func(t *testing.T) {
			f := newFixture(t)
			path, out := accountingImportLog(t, f, source, -20, -1)
			seedPerf(t, f.cache, t0)
			f.run(30, both())
			// A newly appended response is outside the retry interval. Coverage is already
			// complete: this run owes only the explicit retry, not every record in its file.
			if source == "codex" {
				writeLines(t, path, cxTurnLines(-10*dayS, high, 30, req{out: 300, gen: 10, ttft: 1})...)
			} else {
				writeLines(t, path, claudeTurnAt(-10*dayS, "outside-retry", "claude-fixture")...)
			}
			imp, _ := LoadImported(f.cache)
			coverage := imp.Coverage[source]
			coverage.Retry = []RetryFile{{Key: RetryKey(path), Spans: []Span{{From: t0.AddDate(0, 0, -21), Through: t0.AddDate(0, 0, -19)}}}}
			imp.Coverage[source] = coverage
			if err := writeImported(f.cache, imp); err != nil {
				t.Fatal(err)
			}
			f.run(30, both())
			if got := accountingImportedOutput(t, f, source); got != 2*out {
				t.Fatalf("partial retry lost prior usage or admitted extra usage: output %d want %d", got, 2*out)
			}
		})
	}
}
func TestAccountingRemoveImportOnlyOnFirstLiveDay(t *testing.T) {
	for _, source := range []string{"codex", "claude-code"} {
		t.Run(source, func(t *testing.T) {
			f := newFixture(t)
			_, out := accountingImportLog(t, f, source, -0.1)
			seedPerf(t, f.cache, t0)
			f.run(7, both())
			if got := accountingImportedOutput(t, f, source); got != out {
				t.Fatalf("import missing: %d", got)
			}
			if err := RemoveImportedUnder(f.cache, *both()); err != nil {
				t.Fatal(err)
			}
			if got := accountingImportedOutput(t, f, source); got != 0 {
				t.Fatalf("import-only first-day response survived removal: %d", got)
			}
		})
	}
}
func TestAccountingImportAndLiveOwnership(t *testing.T) {
	for _, source := range []string{"codex", "claude-code"} {
		for _, liveFirst := range []bool{false, true} {
			name := source + "/import-first"
			if liveFirst {
				name = source + "/live-first"
			}
			t.Run(name, func(t *testing.T) {
				f := newFixture(t)
				home := t.TempDir()
				t.Setenv("HOME", home)
				t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, "config"))
				t.Setenv("MODELPLAN_READERS", "")
				raw, _ := json.Marshal(both().State())
				if err := os.MkdirAll(filepath.Dir(consent.Path()), 0700); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(consent.Path(), raw, 0600); err != nil {
					t.Fatal(err)
				}
				path, out := accountingImportLog(t, f, source, -0.1, 0.1)
				seedPerf(t, f.cache, t0)
				observe := func() {
					t.Helper()
					var err error
					if source == "codex" {
						err = ObserveCodex(f.cache, []string{path}, func(string) bool { return false }, Ingest{}, f.now)
					} else {
						err = ObserveClaude(f.cache, path, false, Ingest{}, f.now)
					}
					if err != nil {
						t.Fatal(err)
					}
				}
				if liveFirst {
					observe()
				}
				f.run(7, both())
				if !liveFirst {
					observe()
				}
				if got := accountingImportedOutput(t, f, source); got != 2*out {
					t.Fatalf("overlap double-counted or import blocked live observation: %d want %d", got, 2*out)
				}
				if err := RemoveImportedUnder(f.cache, *both()); err != nil {
					t.Fatal(err)
				}
				if got := accountingImportedOutput(t, f, source); got != 2*out {
					t.Fatalf("live-owned responses lost on import removal: %d want %d", got, 2*out)
				}
				// Force a live refresh after a write: it must preserve ownership and totals.
				if err := os.Chtimes(path, f.now, f.now.Add(time.Second)); err != nil {
					t.Fatal(err)
				}
				observe()
				if got := accountingImportedOutput(t, f, source); got != 2*out {
					t.Fatalf("live refresh changed total: %d", got)
				}
			})
		}
	}
}

func TestAccountingRemoveUnprovenPreviewOwnership(t *testing.T) {
	cache := t.TempDir()
	os.MkdirAll(filepath.Dir(accountingPath(cache)), 0700)
	// Older pre-release caches marked first-day imports as live from their date.
	// Without evidence of a live scan, that flag must not defeat explicit removal.
	l := accountingLedger{Version: 1, Files: map[string]usageFile{"preview": {Source: "codex", Records: []usageRecord{{Key: "first-day", At: t0, usageBuckets: usageBuckets{Output: 300}}}}}}
	if err := saveAccounting(cache, l); err != nil {
		t.Fatal(err)
	}
	if err := removeImportedAccountingLocked(cache); err != nil {
		t.Fatal(err)
	}
	rows, _ := accountingRows(cache)
	if len(rows) != 0 {
		t.Fatal("unproven preview ownership retained imported usage")
	}
}

// After Forget (clear boundary, then accounting erase) a later history import or live scan of
// the same logs must not bring the forgotten responses back.
func TestAccountingForgetThenImportDoesNotRecreate(t *testing.T) {
	for _, source := range []string{"codex", "claude-code"} {
		t.Run(source, func(t *testing.T) {
			f := newFixture(t)
			_, out := accountingImportLog(t, f, source, -0.1)
			seedPerf(t, f.cache, t0)
			f.run(7, both())
			if got := accountingImportedOutput(t, f, source); got != out {
				t.Fatalf("import missing: %d", got)
			}
			if err := MarkCleared(f.cache, sourceTool(source), f.now); err != nil {
				t.Fatal(err)
			}
			unlock, ok := LockLedgersForCleanup(f.cache)
			if !ok {
				t.Fatal("ledgers busy")
			}
			err := ForgetAccountingLocked(f.cache, sourceTool(source))
			unlock()
			if err != nil {
				t.Fatal(err)
			}
			if got := accountingImportedOutput(t, f, source); got != 0 {
				t.Fatalf("Forget kept accounting: %d", got)
			}
			os.Remove(ImportPath(f.cache)) // Forget drops the coverage, so the import runs again
			f.run(7, both())
			if got := accountingImportedOutput(t, f, source); got != 0 {
				t.Fatalf("later import re-created forgotten accounting: %d", got)
			}
		})
	}
}
