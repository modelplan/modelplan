// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// G3-20 (owner report, build 541b32b9): one ChatGPT Pro subscription, upgraded from the
// 100 USD to the 200 USD tier, appeared as two Codex accounts. Synthetic data only: the plan
// names, e-mail and reset instants below are made up.

func g320Limits(plan string, primaryReset, weeklyReset time.Time) string {
	return fmt.Sprintf(`{"rateLimitsByLimitId":{"codex":{"limitId":"codex","planType":%q,
 "primary":{"usedPercent":21,"windowDurationMins":300,"resetsAt":%d},
 "secondary":{"usedPercent":40,"windowDurationMins":10080,"resetsAt":%d}}}}`, plan, primaryReset.Unix(), weeklyReset.Unix())
}

// g320Rollout writes one Codex session log whose token_count line reports the meters.
func g320Rollout(t *testing.T, codexHome string, at time.Time, plan string, primaryReset, weeklyReset time.Time) {
	t.Helper()
	day := filepath.Join(codexHome, "sessions", at.Format("2006"), at.Format("01"), at.Format("02"))
	if err := os.MkdirAll(day, 0o700); err != nil {
		t.Fatal(err)
	}
	line := fmt.Sprintf(`{"timestamp":%q,"type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","plan_type":%q,"primary":{"used_percent":18,"window_minutes":300,"resets_at":%d},"secondary":{"used_percent":37,"window_minutes":10080,"resets_at":%d}}}}`+"\n",
		at.UTC().Format(time.RFC3339), plan, primaryReset.Unix(), weeklyReset.Unix())
	p := filepath.Join(day, "rollout-"+at.UTC().Format("2006-01-02T15-04-05")+"-g320.jsonl")
	if err := os.WriteFile(p, []byte(line), 0o600); err != nil {
		t.Fatal(err)
	}
	_ = os.Chtimes(p, at, at)
}

func g320Summary(accounts []Account) string {
	out := ""
	for _, a := range accounts {
		out += fmt.Sprintf("[plan=%s via=%q bound=%t windows=%d] ", a.Plan, a.Via, a.Subscription != nil, len(a.Windows))
	}
	return out
}

func codexAccounts(r Report) []Account {
	var out []Account
	for _, a := range r.Accounts {
		if a.Source == "codex" {
			out = append(out, a)
		}
	}
	return out
}

func TestG320SessionLogsAndRuntimeOfOneAccountAreOneAccount(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	now := acctNow
	primary, weekly := now.Add(3*time.Hour), now.Add(4*24*time.Hour)
	g320Rollout(t, codexHome, now.Add(-10*time.Minute), "pro", primary, weekly)
	bin, _ := fakeCodex(t, g320Limits("pro", primary, weekly))
	if err := RefreshCodexAccount(context.Background(), cache, bin, now); err != nil {
		t.Fatal(err)
	}
	p := Paths{Cache: cache, CodexHome: codexHome}
	accounts := codexAccounts(ReadPermitted(p, now))
	if len(accounts) != 1 {
		t.Fatalf("one ChatGPT account shown as %d Codex accounts: %s", len(accounts), g320Summary(accounts))
	}
	a := accounts[0]
	if a.Via != "codex-account" || a.Subscription == nil || a.Subscription.Status != "verified" {
		t.Fatalf("log reading not bound to the runtime account: %+v", a)
	}
	if len(a.Windows) != 2 || a.Windows[0].UsedPercent == nil || *a.Windows[0].UsedPercent != 21 {
		t.Fatalf("newest (runtime) observation per window not kept: %+v", a.Windows)
	}
}

func TestG320PlanUpgradeKeepsOneAccount(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	before := acctNow.Add(-2 * time.Hour)
	oldPrimary, oldWeekly := before.Add(2*time.Hour), before.Add(3*24*time.Hour)
	// Before the upgrade: the logs and a runtime reading show the 100 USD tier.
	g320Rollout(t, codexHome, before.Add(-5*time.Minute), "pro_100", oldPrimary, oldWeekly)
	bin, _ := fakeCodex(t, g320Limits("pro_100", oldPrimary, oldWeekly))
	if err := RefreshCodexAccount(context.Background(), cache, bin, before); err != nil {
		t.Fatal(err)
	}
	ref := loadAccount(cache).SubscriptionRef
	if ref == "" {
		t.Fatal("no account reference")
	}
	// After the upgrade the same ChatGPT account reports the 200 USD tier with new cycles; no
	// Codex turn has run since, so the newest logs still carry the old tier.
	after := acctNow
	newPrimary, newWeekly := after.Add(5*time.Hour), after.Add(7*24*time.Hour)
	bin, _ = fakeCodex(t, g320Limits("pro_200", newPrimary, newWeekly))
	if err := RefreshCodexAccount(context.Background(), cache, bin, after); err != nil {
		t.Fatal(err)
	}
	if got := loadAccount(cache).SubscriptionRef; got != ref {
		t.Fatalf("plan upgrade changed the account reference: %q -> %q", ref, got)
	}
	accounts := codexAccounts(ReadPermitted(Paths{Cache: cache, CodexHome: codexHome}, after))
	if len(accounts) != 1 {
		t.Fatalf("upgraded subscription shown as %d accounts: %s", len(accounts), g320Summary(accounts))
	}
	a := accounts[0]
	if a.Plan != "pro_200" || a.Subscription == nil || a.Subscription.Ref != ref {
		t.Fatalf("upgraded account = %+v", a)
	}
	for _, w := range a.Windows {
		if w.Origin != "runtime" || w.ResetsAt == nil || (!w.ResetsAt.Equal(newPrimary) && !w.ResetsAt.Equal(newWeekly)) {
			t.Fatalf("old-tier window kept after the upgrade: %+v", w)
		}
	}
}

// Owner decision B: logs of another login (different cycles) are not a second account while
// the live reading works; only the active login is shown, with its own windows.
func TestG320LoginSwitchShowsOnlyTheActiveLogin(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	now := acctNow
	g320Rollout(t, codexHome, now.Add(-10*time.Minute), "plus", now.Add(90*time.Minute), now.Add(2*24*time.Hour))
	primary, weekly := now.Add(3*time.Hour), now.Add(4*24*time.Hour)
	bin, _ := fakeCodex(t, g320Limits("pro", primary, weekly))
	if err := RefreshCodexAccount(context.Background(), cache, bin, now); err != nil {
		t.Fatal(err)
	}
	accounts := codexAccounts(ReadPermitted(Paths{Cache: cache, CodexHome: codexHome}, now))
	if len(accounts) != 1 {
		t.Fatalf("live reading available: only the active login, got %s", g320Summary(accounts))
	}
	g320AssertLiveOnly(t, accounts[0], "pro", primary, weekly)
}

func TestG320OlderRuntimePlanNeverUndoesUpgrade(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	reset := acctNow.Add(2 * time.Hour)
	older := &accountSnap{SchemaVersion: 1, Status: "ok", ObservedAt: acctNow.Add(-time.Minute), Plan: "pro_100", SubscriptionRef: "0123456789abcdef",
		Windows: []Window{{Kind: "five_hour", WindowMinutes: 300, UsedPercent: ptr(10), ResetsAt: &reset, ObservedAt: acctNow.Add(-time.Minute)}}}
	if err := save(cache, older); err != nil {
		t.Fatal(err)
	}
	report := Report{Accounts: []Account{{Source: "codex", Plan: "pro_200", ObservedAt: acctNow,
		Subscription: &Binding{Ref: older.SubscriptionRef, Status: "verified", Basis: "codex-account", ObservedAt: acctNow},
		Windows:      []Window{{Kind: "five_hour", WindowMinutes: 300, UsedPercent: ptr(31), ResetsAt: &reset, ObservedAt: acctNow}}}}}
	applyAccount(&report, cache, acctNow)
	if len(report.Accounts) != 1 {
		t.Fatalf("same verified account split into %d accounts", len(report.Accounts))
	}
	a := report.Accounts[0]
	if a.Plan != "pro_200" {
		t.Fatalf("older runtime plan overwrote the upgraded plan: %q", a.Plan)
	}
	if len(a.Windows) != 1 || a.Windows[0].UsedPercent == nil || *a.Windows[0].UsedPercent != 31 {
		t.Fatalf("newer reading lost: %+v", a.Windows)
	}
}
