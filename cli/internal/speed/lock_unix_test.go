//go:build darwin || linux

// SPDX-License-Identifier: MIT
package speed

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestLedgerWriterLockNeverStealsAgedLiveHolder(t *testing.T) {
	for _, name := range []string{"speed.lock", "perf.lock"} {
		t.Run(name, func(t *testing.T) {
			cache := t.TempDir()
			unlock, ok := lock(cache, name)
			if !ok { t.Fatal("initial writer lock failed") }
			path := filepath.Join(cache, "observed", name)
			inode, err := os.Stat(path)
			if err != nil { unlock(); t.Fatal(err) }
			old := time.Now().Add(-time.Hour)
			if err := os.Chtimes(path, old, old); err != nil { unlock(); t.Fatal(err) }
			if other, ok := lock(cache, name); ok { other(); unlock(); t.Fatal("aged live writer lock was stolen") }
			after, err := os.Stat(path)
			if err != nil || !os.SameFile(inode, after) { unlock(); t.Fatal("lock inode changed", err) }
			unlock()
			next, ok := lock(cache, name)
			if !ok { t.Fatal("released lock remained busy") }
			next()
			after, err = os.Stat(path)
			if err != nil || !os.SameFile(inode, after) { t.Fatal("lock file was removed or replaced", err) }
		})
	}
}
