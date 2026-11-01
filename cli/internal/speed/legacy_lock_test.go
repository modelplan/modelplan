// SPDX-License-Identifier: MIT
package speed

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestFreshLegacyMarkerBlocksLedgerWrites(t *testing.T) {
	for _, name := range []string{"speed.lock", "perf.lock"} {
		t.Run(name, func(t *testing.T) {
			cache := t.TempDir()
			dir := filepath.Join(cache, "observed")
			if err := os.MkdirAll(dir, 0700); err != nil {
				t.Fatal(err)
			}
			marker := filepath.Join(dir, name)
			if err := os.WriteFile(marker, nil, 0600); err != nil {
				t.Fatal(err)
			}
			write := func() error {
				if name == "speed.lock" {
					return observe(cache, time.Now(), func(*Ledger) bool { return true })
				}
				return observePerf(cache, time.Now(), Ingest{}, func(*PerfLedger) bool { return true })
			}
			path := Path(cache)
			if name == "perf.lock" {
				path = PerfPath(cache)
			}
			if err := write(); err != nil {
				t.Fatal(err)
			}
			if _, err := os.Stat(path); !os.IsNotExist(err) {
				t.Fatalf("wrote past fresh legacy marker: %v", err)
			}
			if name == "perf.lock" && ClearProjectLabels(cache) == nil {
				t.Fatal("project-label cleanup ignored fresh marker")
			}
			if _, err := os.Stat(filepath.Join(dir, name[:len(name)-5]+".flock")); err != nil {
				t.Fatal("new lock file missing", err)
			}
			if err := os.Remove(marker); err != nil {
				t.Fatal(err)
			}
			if err := write(); err != nil {
				t.Fatal(err)
			}
			if _, err := os.Stat(path); err != nil {
				t.Fatal("writer did not resume", err)
			}
		})
	}
}

func TestOldLegacyMarkerIsNotRemoved(t *testing.T) {
	cache := t.TempDir()
	dir := filepath.Join(cache, "observed")
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	marker := filepath.Join(dir, "perf.lock")
	if err := os.WriteFile(marker, nil, 0600); err != nil {
		t.Fatal(err)
	}
	old := time.Now().Add(-time.Minute)
	if err := os.Chtimes(marker, old, old); err != nil {
		t.Fatal(err)
	}
	unlock, ok := lock(cache, "perf.lock")
	if !ok {
		t.Fatal("old marker prevented progress")
	}
	unlock()
	if _, err := os.Stat(marker); err != nil {
		t.Fatal("legacy marker was removed", err)
	}
}
