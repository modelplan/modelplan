// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// Regressions from the MACREV-B review of #602 at e2bf2134 (macrevb-602-1..3). Synthetic
// e-mails, plans and reset instants only.

// fakeCodexLogin is fakeCodex signed in with a given (synthetic) e-mail.
func fakeCodexLogin(t *testing.T, email, result string) string {
	t.Helper()
	bin, _ := fakeCodex(t, result)
	script, err := os.ReadFile(bin)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(bin, []byte(strings.ReplaceAll(string(script), "Someone@Example.com", email)), 0o700); err != nil {
		t.Fatal(err)
	}
	return bin
}

// macrevb-602-1: ModelPlan was not running before the upgrade, so no runtime reading of the
// old tier exists; the newest logs still carry the old tier. One account, the new plan, no
// old-tier window.
func TestG320ReviewColdUpgradeKeepsOneAccount(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	old := acctNow.Add(-2 * time.Hour)
	g320Rollout(t, codexHome, old, "pro_100", acctNow.Add(time.Hour), acctNow.Add(3*24*time.Hour))
	newPrimary, newWeekly := acctNow.Add(5*time.Hour), acctNow.Add(7*24*time.Hour)
	bin, _ := fakeCodex(t, g320Limits("pro_200", newPrimary, newWeekly))
	if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow); err != nil {
		t.Fatal(err)
	}
	accounts := codexAccounts(ReadPermitted(Paths{Cache: cache, CodexHome: codexHome}, acctNow))
	if len(accounts) != 1 {
		t.Fatalf("one upgraded login, cold cache: %s", g320Summary(accounts))
	}
	g320AssertNewTierOnly(t, accounts[0], newPrimary, newWeekly)
}

// macrevb-602-1, legacy cache: a runtime reading cached before the meters were recorded
// (no meterRef/meters) still binds the old-tier logs after the upgrade.
func TestG320ReviewLegacyCacheUpgradeKeepsOneAccount(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	before := acctNow.Add(-2 * time.Hour)
	oldPrimary, oldWeekly := before.Add(2*time.Hour), before.Add(3*24*time.Hour)
	g320Rollout(t, codexHome, before.Add(-5*time.Minute), "pro_100", oldPrimary, oldWeekly)
	bin, _ := fakeCodex(t, g320Limits("pro_100", oldPrimary, oldWeekly))
	if err := RefreshCodexAccount(context.Background(), cache, bin, before); err != nil {
		t.Fatal(err)
	}
	legacy := loadAccount(cache)
	legacy.MeterRef, legacy.Meters, legacy.Foreign, legacy.PlanSince = "", nil, nil, time.Time{}
	if err := save(cache, legacy); err != nil {
		t.Fatal(err)
	}
	// The logs were written after ModelPlan's last (legacy) reading, so only the meters can
	// bind them.
	g320Rollout(t, codexHome, before.Add(30*time.Minute), "pro_100", oldPrimary, oldWeekly)
	newPrimary, newWeekly := acctNow.Add(5*time.Hour), acctNow.Add(7*24*time.Hour)
	bin, _ = fakeCodex(t, g320Limits("pro_200", newPrimary, newWeekly))
	if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow); err != nil {
		t.Fatal(err)
	}
	accounts := codexAccounts(ReadPermitted(Paths{Cache: cache, CodexHome: codexHome}, acctNow))
	if len(accounts) != 1 {
		t.Fatalf("legacy cache, upgraded login: %s", g320Summary(accounts))
	}
	g320AssertNewTierOnly(t, accounts[0], newPrimary, newWeekly)
}

// macrevb-602-2: a second login whose five-hour cycle resets 30 s from the first login's
// does not take over the first login's logs (its weekly cycle differs, and the logs carry the
// first login's cycles).
func TestG320ReviewDistinctLoginsMayShareMeterTimes(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	primary, weekly := acctNow.Add(3*time.Hour), acctNow.Add(4*24*time.Hour)
	if err := RefreshCodexAccount(context.Background(), cache, fakeCodexLogin(t, "alpha@example.test", g320Limits("pro", primary, weekly)), acctNow.Add(-2*time.Hour)); err != nil {
		t.Fatal(err)
	}
	refA := loadAccount(cache).SubscriptionRef
	g320Rollout(t, codexHome, acctNow.Add(-time.Minute), "pro", primary, weekly)
	if err := RefreshCodexAccount(context.Background(), cache, fakeCodexLogin(t, "beta@example.test", g320Limits("pro", primary.Add(30*time.Second), weekly.Add(24*time.Hour))), acctNow); err != nil {
		t.Fatal(err)
	}
	refB := loadAccount(cache).SubscriptionRef
	if refA == "" || refB == "" || refA == refB {
		t.Fatal("fixture must establish two different login references")
	}
	accounts := codexAccounts(ReadPermitted(Paths{Cache: cache, CodexHome: codexHome}, acctNow))
	if len(accounts) != 2 {
		t.Fatalf("different logins joined by a reset coincidence: %s", g320Summary(accounts))
	}
	for _, a := range accounts {
		if a.Via == "" && a.Subscription != nil {
			t.Fatalf("the first login's logs acquired a login reference: %+v", a.Subscription)
		}
	}
}

// macrevb-602-2, conflicting meters alone (no earlier reading of the other login): one
// matching five-hour reset does not outweigh a weekly cycle that disagrees.
func TestG320ReviewOneMatchingResetWithAConflictStaysSeparate(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	primary, weekly := acctNow.Add(3*time.Hour), acctNow.Add(4*24*time.Hour)
	g320Rollout(t, codexHome, acctNow.Add(-time.Minute), "pro", primary, weekly)
	if err := RefreshCodexAccount(context.Background(), cache, fakeCodexLogin(t, "beta@example.test", g320Limits("pro", primary.Add(30*time.Second), weekly.Add(24*time.Hour))), acctNow); err != nil {
		t.Fatal(err)
	}
	if accounts := codexAccounts(ReadPermitted(Paths{Cache: cache, CodexHome: codexHome}, acctNow)); len(accounts) != 2 {
		t.Fatalf("a conflicting weekly cycle was ignored: %s", g320Summary(accounts))
	}
}

// macrevb-602-3: an older runtime reading of the previous plan never fills a window the
// newer plan's reading lacks.
func TestG320ReviewOlderPlanMustNotFillMissingNewPlanWindow(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	five, week := acctNow.Add(2*time.Hour), acctNow.Add(4*24*time.Hour)
	older := &accountSnap{SchemaVersion: 1, Status: "ok", ObservedAt: acctNow.Add(-time.Minute), Plan: "pro_100", SubscriptionRef: "0123456789abcdef",
		Windows: []Window{{Kind: "five_hour", WindowMinutes: 300, UsedPercent: ptr(10), ResetsAt: &five, ObservedAt: acctNow.Add(-time.Minute)},
			{Kind: "weekly", WindowMinutes: 10080, UsedPercent: ptr(90), ResetsAt: &week, ObservedAt: acctNow.Add(-time.Minute)}}}
	if err := save(cache, older); err != nil {
		t.Fatal(err)
	}
	report := Report{Accounts: []Account{{Source: "codex", Plan: "pro_200", ObservedAt: acctNow,
		Subscription: &Binding{Ref: older.SubscriptionRef, Status: "verified", Basis: "codex-account", ObservedAt: acctNow},
		Windows:      []Window{{Kind: "five_hour", WindowMinutes: 300, UsedPercent: ptr(31), ResetsAt: &five, ObservedAt: acctNow}}}}}
	applyAccount(&report, cache, acctNow)
	if len(report.Accounts) != 1 || report.Accounts[0].Plan != "pro_200" || len(report.Accounts[0].Windows) != 1 {
		t.Fatalf("older plan supplied a quota window to the newer plan: %s", g320Summary(report.Accounts))
	}
}

func g320AssertNewTierOnly(t *testing.T, a Account, primary, weekly time.Time) {
	t.Helper()
	if a.Plan != "pro_200" || a.Subscription == nil || a.Subscription.Status != "verified" {
		t.Fatalf("upgraded account = plan %q subscription %+v", a.Plan, a.Subscription)
	}
	if len(a.Windows) != 2 {
		t.Fatalf("windows = %d", len(a.Windows))
	}
	for _, w := range a.Windows {
		if w.ResetsAt == nil || (!w.ResetsAt.Equal(primary) && !w.ResetsAt.Equal(weekly)) {
			t.Fatalf("old-tier window shown under the new plan: %+v", w)
		}
	}
}
