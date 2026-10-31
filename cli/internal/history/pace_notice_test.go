// SPDX-License-Identifier: MIT
package history_test

import (
	"github.com/modelplan/modelplan/cli/internal/history"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestPaceWarningConcurrentClaimAndOptOut(t *testing.T) {
	t.Setenv("MODELPLAN_HISTORY", "")
	cache := t.TempDir()
	now := time.Date(2026, 10, 31, 12, 0, 0, 0, time.UTC)
	reset := now.Add(7 * 24 * time.Hour)
	var wg sync.WaitGroup
	var count atomic.Int32
	for i := 0; i < 12; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if history.ClaimPaceWarning(cache, "claude-code|weekly|reset", reset, now) {
				count.Add(1)
			}
		}()
	}
	wg.Wait()
	if count.Load() != 1 {
		t.Fatal("concurrent user notices", count.Load())
	}
	if history.ClaimPaceWarning(cache, "claude-code|weekly|reset", reset, now.Add(time.Hour)) {
		t.Fatal("repeated same window")
	}
	if !history.ClaimPaceWarning(cache, "codex|weekly|reset", reset, now) {
		t.Fatal("another tool suppressed")
	}
	if !history.ClaimPaceWarning(cache, "claude-code|weekly|next-reset", reset.Add(7*24*time.Hour), reset) {
		t.Fatal("new window suppressed")
	}
	info, err := os.Stat(filepath.Join(cache, "observed", "pace-warning.json"))
	if err != nil || info.Mode().Perm() != 0600 {
		t.Fatal("notice state permissions", err)
	}
	t.Setenv("MODELPLAN_HISTORY", "off")
	if history.ClaimPaceWarning(t.TempDir(), "off", reset, now) {
		t.Fatal("history off ignored")
	}
}

func TestPaceWarningResetJitterSharesClaim(t *testing.T) {
	t.Setenv("MODELPLAN_HISTORY", "")
	cache := t.TempDir()
	now := time.Date(2026, 10, 31, 12, 0, 0, 0, time.UTC)
	reset := now.Add(7 * 24 * time.Hour)
	claim := func(source string, reset, at time.Time) bool {
		return history.ClaimPaceWarning(cache, "window_pace_warning|"+source+"|plan|weekly||"+reset.Format(time.RFC3339), reset, at)
	}
	if !claim("claude-code", reset, now) {
		t.Fatal("first claim suppressed")
	}
	for _, jitter := range []time.Duration{-time.Second, time.Second, 119 * time.Second} {
		if claim("claude-code", reset.Add(jitter), now) {
			t.Fatal("same cycle repeated after reset jitter", jitter)
		}
	}
	if claim("claude-code", reset.Add(time.Minute), reset.Add(time.Second)) {
		t.Fatal("claim expired inside the reset jitter tolerance")
	}
	if !claim("codex", reset.Add(time.Second), now) || !claim("claude-code", reset.Add(7*24*time.Hour), reset.Add(time.Minute)) {
		t.Fatal("another tool or genuinely new cycle suppressed")
	}
}
