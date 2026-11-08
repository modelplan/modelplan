package advise

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestOtherPlanWithRoom(t *testing.T) {
	now := time.Date(2026, 11, 8, 12, 0, 0, 0, time.UTC)
	win := func(kind string, left float64, observed time.Time, reset time.Duration) quota.Window {
		r := now.Add(reset)
		in := int(reset / time.Minute)
		return quota.Window{Kind: kind, RemainingPercent: &left, ResetsAt: &r, ResetsInMinutes: &in, ObservedAt: observed}
	}
	acct := func(source, headroom string, ws ...quota.Window) quota.Account {
		return quota.Account{Source: source, Headroom: headroom, Windows: ws}
	}
	report := func(as ...quota.Account) quota.Report { return quota.Report{Accounts: as} }

	// The plan counts by its least-remaining fresh window; the most-left plan wins.
	r := report(
		acct("claude-code", "normal", win("weekly", 95, now, 24*time.Hour)), // the harness's own plan
		acct("codex", "normal", win("five_hour", 90, now, time.Hour), win("weekly", 60, now, 48*time.Hour)),
		acct("native:zai", "normal", win("five_hour", 45, now, 2*time.Hour)),
	)
	got := OtherPlanWithRoom(r, "claude-code", now)
	if got == nil || got.Name != "Codex" || got.Window != "weekly" || got.Remaining != 60 || got.ResetsIn != 48*60 {
		t.Fatalf("pick: %+v", got)
	}
	// From Codex, Claude is the other plan, and Codex itself never counts.
	if got := OtherPlanWithRoom(r, "codex", now); got == nil || got.Name != "Claude" {
		t.Fatalf("codex side: %+v", got)
	}

	for _, tc := range []struct {
		name string
		a    quota.Account
	}{
		{"below 30%", acct("codex", "normal", win("weekly", 29, now, time.Hour))},
		{"tight", acct("codex", "conserve", win("weekly", 80, now, time.Hour))},
		{"exhausted", acct("codex", "exhausted", win("weekly", 80, now, time.Hour))},
		{"stale account", func() quota.Account { a := acct("codex", "normal", win("weekly", 80, now, time.Hour)); a.Stale = true; return a }()},
		{"old reading", acct("codex", "normal", win("weekly", 80, now.Add(-61*time.Minute), time.Hour))},
		{"reset passed", acct("codex", "normal", win("weekly", 80, now.Add(-time.Minute), -time.Minute))},
		{"no windows", acct("codex", "unknown")},
		{"hand-entered", acct("user", "normal", win("monthly", 80, now, time.Hour))},
		{"own plan by another reader", acct("native:claude", "normal", win("weekly", 80, now, time.Hour))},
	} {
		if got := OtherPlanWithRoom(report(tc.a), "claude-code", now); got != nil {
			t.Errorf("%s counted as room: %+v", tc.name, got)
		}
	}
	// One stale window does not hide a plan's other fresh one, but a fresh low window decides.
	stale := win("five_hour", 5, now, time.Hour)
	stale.Stale = true
	if got := OtherPlanWithRoom(report(acct("codex", "normal", stale, win("weekly", 70, now, time.Hour))), "claude-code", now); got == nil || got.Remaining != 70 {
		t.Fatalf("stale window decided: %+v", got)
	}
	if got := OtherPlanWithRoom(report(acct("codex", "normal", win("five_hour", 10, now, time.Hour), win("weekly", 70, now, time.Hour))), "claude-code", now); got != nil {
		t.Fatalf("low 5-hour window ignored: %+v", got)
	}
}
