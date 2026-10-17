package history

import (
	"os"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

var now = time.Date(2026, 10, 14, 10, 0, 0, 0, time.UTC)

func reading(source, model, effort, tier string, used float64, at, reset time.Time) quota.Report {
	return quota.Report{Accounts: []quota.Account{{Source: source, Harness: &quota.Harness{Model: model, Effort: effort, ServiceTier: tier},
		Windows: []quota.Window{{Kind: "weekly", UsedPercent: &used, WindowMinutes: 10080, ResetsAt: &reset, ObservedAt: at}}}}}
}

func TestRisesGoToTheConfigurationThatSawThem(t *testing.T) {
	cache, reset := t.TempDir(), now.Add(72*time.Hour)
	steps := []struct {
		effort, tier string
		used         float64
		at           time.Duration
	}{
		{"medium", "", 12, 0},                 // first reading: 12 points before we watched
		{"medium", "", 20, time.Hour},         // +8 Med
		{"xhigh", "", 35, 2 * time.Hour},      // +15 XHigh
		{"xhigh", "", 35, 3 * time.Hour},      // no move
		{"medium", "", 30, 4 * time.Hour},     // the meter never goes down: ignored
		{"medium", "fast", 41, 5 * time.Hour}, // +6 Med Fast
		{"medium", "", 44, 90 * time.Minute},  // older than the last reading: ignored
	}
	for _, s := range steps {
		if err := Observe(cache, reading("codex", "gpt-6-sol", s.effort, s.tier, s.used, now.Add(s.at), reset), now.Add(s.at)); err != nil {
			t.Fatal(err)
		}
	}
	l := Load(cache)
	if len(l.Cycles) != 1 {
		t.Fatalf("cycles = %+v", l.Cycles)
	}
	c := l.Cycles[0]
	if c.FirstUsed != 12 || c.LastUsed != 41 || c.HitLimit || len(c.Spent) != 3 ||
		c.Spent[0] != (Share{Model: "gpt-6-sol", Effort: "medium", Points: 8}) || c.Spent[1].Points != 15 || !c.Spent[2].Fast || c.Spent[2].Points != 6 {
		t.Fatalf("cycle = %+v", c)
	}

	// The next cycle is its own entry; a reading of the old one after the reset adds nothing.
	next := reset.Add(7 * 24 * time.Hour)
	Observe(cache, reading("codex", "gpt-6-sol", "medium", "", 100, reset.Add(time.Hour), next), reset.Add(time.Hour))
	l = Load(cache)
	if len(l.Cycles) != 2 || !l.Cycles[0].Done(reset.Add(time.Hour)) || !l.Cycles[1].HitLimit {
		t.Fatalf("after reset = %+v", l.Cycles)
	}
}

func TestOffLockedAndPrivate(t *testing.T) {
	cache, reset := t.TempDir(), now.Add(time.Hour)
	t.Setenv("MODELPLAN_HISTORY", "off")
	Observe(cache, reading("claude-code", "claude-opus-5-5", "high", "", 20, now, reset), now)
	if _, err := os.Stat(Path(cache)); err == nil {
		t.Fatal("recorded while off")
	}
	t.Setenv("MODELPLAN_HISTORY", "")
	// Another process holds the ledger: skip, and the next reading counts the same rise.
	unlock, _ := lock(cache)
	Observe(cache, reading("claude-code", "claude-opus-5-5", "high", "", 20, now, reset), now)
	unlock()
	if len(Load(cache).Cycles) != 0 {
		t.Fatal("wrote while locked")
	}
	r := reading("claude-code", "claude-opus-5-5", "high", "", 20, now, reset)
	r.Accounts = append(r.Accounts, quota.Account{Source: "codexbar:cursor", Windows: r.Accounts[0].Windows}, quota.Account{Source: "user", Plan: "zhipu", Windows: r.Accounts[0].Windows})
	Observe(cache, r, now)
	b, _ := os.ReadFile(Path(cache))
	if l := Load(cache); len(l.Cycles) != 1 || l.Cycles[0].Source != "claude-code" {
		t.Fatalf("only harness windows are kept: %s", b)
	}
	if fi, _ := os.Stat(Path(cache)); fi.Mode().Perm() != 0o600 {
		t.Fatalf("mode = %v", fi.Mode())
	}
	for _, leak := range []string{"session", "prompt", "cwd"} {
		if strings.Contains(string(b), leak) {
			t.Fatalf("%q in the ledger:\n%s", leak, b)
		}
	}
}

func TestOldCyclesArePruned(t *testing.T) {
	l := Ledger{SchemaVersion: 1, Cycles: []Cycle{
		{Kind: "five_hour", ResetsAt: now.Add(-29 * 24 * time.Hour)}, {Kind: "five_hour", ResetsAt: now.Add(-27 * 24 * time.Hour)},
		{Kind: "weekly", ResetsAt: now.Add(-85 * 24 * time.Hour)}, {Kind: "weekly", ResetsAt: now.Add(-83 * 24 * time.Hour)},
	}}
	l.prune(now)
	if len(l.Cycles) != 2 || l.Cycles[0].Kind != "weekly" || l.Cycles[1].Kind != "five_hour" {
		t.Fatalf("kept = %+v", l.Cycles)
	}
}
