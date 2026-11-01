//go:build windows

// SPDX-License-Identifier: MIT
package speed

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

func TestWindowsLockChild(t *testing.T) {
	cache := os.Getenv("MODELPLAN_WINDOWS_LOCK_CHILD")
	if cache == "" { return }
	unlock, ok := lock(cache, os.Getenv("MODELPLAN_WINDOWS_LOCK_NAME"))
	if !ok { t.Fatal("child cannot lock") }
	defer unlock()
	fmt.Println("locked")
	time.Sleep(time.Hour)
}

func TestWindowsLockExcludesLiveAndReleasesKilledWriter(t *testing.T) {
	for _, name := range []string{"speed.lock", "perf.lock"} {
		t.Run(name, func(t *testing.T) {
			cache := t.TempDir()
			exe, err := os.Executable()
			if err != nil { t.Fatal(err) }
			ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
			defer cancel()
			cmd := exec.CommandContext(ctx, exe, "-test.run=^TestWindowsLockChild$")
			cmd.Env = append(os.Environ(), "MODELPLAN_WINDOWS_LOCK_CHILD="+cache, "MODELPLAN_WINDOWS_LOCK_NAME="+name)
			out, err := cmd.StdoutPipe()
			if err != nil { t.Fatal(err) }
			if err := cmd.Start(); err != nil { t.Fatal(err) }
			defer func() { if cmd.ProcessState == nil { _ = cmd.Process.Kill(); _ = cmd.Wait() } }()
			scan := bufio.NewScanner(out)
			if !scan.Scan() || scan.Text() != "locked" { t.Fatal("child did not acquire lock") }
			path := filepath.Join(cache, "observed", name)
			old := time.Now().Add(-time.Hour)
			if err := os.Chtimes(path, old, old); err != nil { t.Fatal(err) }
			if release, ok := lock(cache, name); ok { release(); t.Fatal("live lock was stolen") }
			if err := cmd.Process.Kill(); err != nil { t.Fatal(err) }
			_ = cmd.Wait()
			release, ok := lock(cache, name)
			if !ok { t.Fatal("killed process retained lock") }
			release()
			if _, err := os.Stat(path); err != nil { t.Fatal("persistent lock file removed", err) }
		})
	}
}

func TestWindowsObservationWritesLedger(t *testing.T) {
	cache := t.TempDir()
	err := observePerf(cache, time.Now(), Ingest{}, func(*PerfLedger) bool { return false })
	if err != nil { t.Fatal(err) }
	if _, err := os.Stat(PerfPath(cache)); err != nil { t.Fatal("observation failed to write", err) }
}
