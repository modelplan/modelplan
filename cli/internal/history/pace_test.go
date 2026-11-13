package history

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

func fiveHour(source, effort string, used float64, at, reset time.Time) quota.Report {
	return quota.Report{Accounts: []quota.Account{{Source: source, Plan: "pro", Harness: &quota.Harness{Model: "m", Effort: effort},
		Windows: []quota.Window{{Kind: "five_hour", UsedPercent: &used, WindowMinutes: 300, ResetsAt: &reset, ObservedAt: at}}}}}
}

func paceOf(t *testing.T, cache string, at time.Time) PaceHistory {
	t.Helper()
	l, ok := LoadPace(cache)
	return PaceView{Ledger: l, OK: ok, Recording: true, Now: at}.History()
}

func TestPaceSegmentsGapsAndRate(t *testing.T) {
	cache := t.TempDir()
	reset := now.Add(5 * time.Hour)
	steps := []struct {
		effort string
		used   float64
		at     time.Duration
	}{
		{"high", 10, 0},
		{"high", 10, time.Minute},                // unchanged, within two minutes: not a reading
		{"high", 18, 20 * time.Minute},           // +8 High
		{"low", 22, 40 * time.Minute},            // +4 Low
		{"low", 30, 3 * time.Hour},               // after a 140-minute silence: +8 of unknown configuration
		{"low", 5, 3*time.Hour + 5*time.Minute},  // a reset card: a drop, a new segment
		{"low", 9, 3*time.Hour + 30*time.Minute}, // +4 Low from the new value
	}
	for _, s := range steps {
		if err := Observe(cache, fiveHour("codex", s.effort, s.used, now.Add(s.at), reset), now.Add(s.at)); err != nil {
			t.Fatal(err)
		}
	}
	h := paceOf(t, cache, now.Add(4*time.Hour))
	if len(h.Groups) != 1 || h.Status != "ok" || h.Since == nil || !h.Since.Equal(now) || h.GapLimitMinutes["five_hour"] != 60 {
		t.Fatalf("pace = %+v", h)
	}
	c := h.Groups[0].Cycles[0]
	if c.Closed || c.Readings != 6 || c.Points != 24 || c.GapPoints != 8 || c.GapCount != 1 || c.MaxGapMinutes != 140 || c.Drops != 1 || !c.HadDrop ||
		c.SpanMinutes != 210 || c.Coverage == nil || *c.Coverage != 0.7 || c.SpentBasis != "reading-time-heuristic" {
		t.Errorf("cycle = %+v", c)
	}
	spent := map[string]float64{}
	for _, s := range c.Spent {
		spent[s.Effort] = s.Points
	}
	if spent["high"] != 8 || spent["low"] != 8 {
		t.Errorf("spent = %+v", c.Spent)
	}
	if l := Load(cache); len(l.Cycles) != 1 || l.Cycles[0].LastUsed != 30 {
		t.Errorf("cycles.json keeps its high-water mark: %+v", l.Cycles)
	}
	if g := h.Groups[0]; g.Status != "insufficient" || g.ObservedIntervalRatePerHour != nil || g.ClosedCycles != 0 {
		t.Errorf("an open cycle gives no rate: %+v", g)
	}
}

func TestPaceRateOverClosedCycles(t *testing.T) {
	cache := t.TempDir()
	// Three cycles: 20 points over 2 h, 10 over 1 h, and one with a drop, which is left out.
	for i, c := range []struct{ from, to float64 }{{10, 30}, {0, 10}, {50, 40}} {
		start, reset := now.Add(time.Duration(i)*5*time.Hour), now.Add(time.Duration(i+1)*5*time.Hour)
		span := time.Duration(2-i%2) * time.Hour
		Observe(cache, fiveHour("claude-code", "high", c.from, start, reset), start)
		Observe(cache, fiveHour("claude-code", "high", (c.from+c.to)/2, start.Add(span/2), reset), start.Add(span/2))
		Observe(cache, fiveHour("claude-code", "high", c.to, start.Add(span), reset), start.Add(span))
	}
	h := paceOf(t, cache, now.Add(16*time.Hour))
	g := h.Groups[0]
	if g.ClosedCycles != 3 || g.ValidCycles != 2 || g.Status != "ok" || *g.ObservedIntervalRatePerHour != 10 || g.Attribution != "unattributed" || g.Cycles[0].ResetsAt != now.Add(15*time.Hour) {
		t.Errorf("group = %+v (30 points over 3 observed hours)", g)
	}
	if c := g.Cycles[0]; c.Coverage == nil || c.Spent == nil {
		t.Errorf("Claude Code's five_hour field names its length: %+v", c)
	}
}

func TestPaceBoundaries(t *testing.T) {
	cache := t.TempDir()
	used, reset := 10.0, now.Add(time.Hour)
	// A window whose length no source gives: no coverage is made up.
	r := quota.Report{Accounts: []quota.Account{{Source: "claude-code", Windows: []quota.Window{{Kind: "monthly", UsedPercent: &used, ResetsAt: &reset, ObservedAt: now}}}}}
	Observe(cache, r, now)
	h := paceOf(t, cache, now)
	if c := h.Groups[0].Cycles[0]; c.Coverage != nil {
		t.Errorf("coverage without a known length: %v", *c.Coverage)
	}
	if bs := (PaceView{Ledger: mustPace(t, cache), OK: true, Now: now}).Boundaries(); len(bs) != 1 || !bs[0].Equal(reset) {
		t.Errorf("boundaries = %v", bs)
	}

	// A reading taken before the ledger started is not counted.
	old := t.TempDir()
	Observe(old, fiveHour("codex", "high", 10, now.Add(-time.Hour), now.Add(time.Hour)), now)
	if l := mustPace(t, old); len(l.Cycles) != 0 || !l.Since.Equal(now) {
		t.Errorf("before since: %+v", l)
	}

	// An unreadable ledger is left as it is and reported.
	bad := t.TempDir()
	os.MkdirAll(filepath.Join(bad, "observed"), 0o700)
	junk := []byte("{not json")
	os.WriteFile(PacePath(bad), junk, 0o600)
	Observe(bad, fiveHour("codex", "high", 10, now, now.Add(time.Hour)), now)
	if b, _ := os.ReadFile(PacePath(bad)); !bytes.Equal(b, junk) {
		t.Error("rewrote an unreadable pace ledger")
	}
	if h := paceOf(t, bad, now); h.Status != "unavailable" || h.Reason != "ledger-unreadable" || len(h.Groups) != 0 {
		t.Errorf("unreadable = %+v", h)
	}
	if len(Load(bad).Cycles) != 1 {
		t.Error("cycles.json goes on")
	}

	// Recording off: nothing written, status off.
	t.Setenv("MODELPLAN_HISTORY", "off")
	off := t.TempDir()
	Observe(off, fiveHour("codex", "high", 10, now, now.Add(time.Hour)), now)
	if _, err := os.Stat(PacePath(off)); !os.IsNotExist(err) {
		t.Error("pace written with recording off")
	}
	if h := (PaceView{OK: true, Now: now}).History(); h.Status != "off" {
		t.Errorf("off = %+v", h)
	}
}

func mustPace(t *testing.T, cache string) PaceLedger {
	t.Helper()
	l, ok := LoadPace(cache)
	if !ok {
		t.Fatal("unreadable")
	}
	return l
}

// Two accounts on the same plan are not told apart: their cycles share one unattributed group.
func TestPaceSamePlanTwoAccounts(t *testing.T) {
	cache := t.TempDir()
	Observe(cache, fiveHour("codex", "high", 10, now, now.Add(2*time.Hour)), now)
	Observe(cache, fiveHour("codex", "high", 40, now.Add(time.Minute), now.Add(4*time.Hour)), now.Add(time.Minute))
	h := paceOf(t, cache, now.Add(time.Minute))
	if len(h.Groups) != 1 || len(h.Groups[0].Cycles) != 2 || h.Groups[0].Attribution != "unattributed" {
		t.Errorf("groups = %+v", h.Groups)
	}
}
