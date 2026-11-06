// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// Regressions from the MACREV-B / MACREV2 reviews of #602 (macrevb-602-1..4, macrev2-602-1)
// against design-602-account-identity: logs join a runtime login only with evidence of which
// login was active when they were written. Synthetic e-mails, plans and instants only.

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

// g320PrimaryOnly: a supported reading with only the five-hour window (secondary: null).
func g320PrimaryOnly(plan string, reset time.Time) string {
	return fmt.Sprintf(`{"rateLimitsByLimitId":{"codex":{"limitId":"codex","planType":%q,"primary":{"usedPercent":21,"windowDurationMins":300,"resetsAt":%d},"secondary":null}}}`, plan, reset.Unix())
}

func g320PrimaryOnlyRollout(t *testing.T, codexHome string, at time.Time, plan string, reset time.Time) {
	t.Helper()
	day := filepath.Join(codexHome, "sessions", at.Format("2006"), at.Format("01"), at.Format("02"))
	if err := os.MkdirAll(day, 0o700); err != nil {
		t.Fatal(err)
	}
	line := fmt.Sprintf(`{"timestamp":%q,"type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","plan_type":%q,"primary":{"used_percent":18,"window_minutes":300,"resets_at":%d},"secondary":null}}}`+"\n",
		at.UTC().Format(time.RFC3339), plan, reset.Unix())
	p := filepath.Join(day, "rollout-"+at.UTC().Format("2006-01-02T15-04-05")+"-g320p.jsonl")
	if err := os.WriteFile(p, []byte(line), 0o600); err != nil {
		t.Fatal(err)
	}
	_ = os.Chtimes(p, at, at)
}

func g320Read(t *testing.T, cache, codexHome string, at time.Time) []Account {
	t.Helper()
	return codexAccounts(ReadPermitted(Paths{Cache: cache, CodexHome: codexHome}, at))
}

// Unobserved upgrade, one login, credential file unchanged since the old-tier log (E1): one
// account on the new plan, no old-tier window (macrevb-602-1).
func TestG320ReviewColdUpgradeKeepsOneAccount(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	g320Auth(t, codexHome, acctNow.Add(-10*24*time.Hour))
	g320Rollout(t, codexHome, acctNow.Add(-2*time.Hour), "pro_100", acctNow.Add(time.Hour), acctNow.Add(3*24*time.Hour))
	newPrimary, newWeekly := acctNow.Add(5*time.Hour), acctNow.Add(7*24*time.Hour)
	bin, _ := fakeCodex(t, g320Limits("pro_200", newPrimary, newWeekly))
	if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow); err != nil {
		t.Fatal(err)
	}
	accounts := g320Read(t, cache, codexHome, acctNow)
	if len(accounts) != 1 {
		t.Fatalf("one upgraded login, credential unchanged: %s", g320Summary(accounts))
	}
	g320AssertNewTierOnly(t, accounts[0], newPrimary, newWeekly)
}

// Unobserved upgrade without evidence (credential rewritten after the log, e.g. a refresh):
// two honest rows, nothing hidden; the next Codex turn, logged while ModelPlan reads the
// login (E2), makes it one account.
func TestG320ReviewUnprovenUpgradeIsTwoRowsUntilTheNextTurn(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	g320Rollout(t, codexHome, acctNow.Add(-2*time.Hour), "pro_100", acctNow.Add(time.Hour), acctNow.Add(3*24*time.Hour))
	g320Auth(t, codexHome, acctNow.Add(-time.Hour))
	newPrimary, newWeekly := acctNow.Add(5*time.Hour), acctNow.Add(7*24*time.Hour)
	bin, _ := fakeCodex(t, g320Limits("pro_200", newPrimary, newWeekly))
	if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow); err != nil {
		t.Fatal(err)
	}
	if accounts := g320Read(t, cache, codexHome, acctNow); len(accounts) != 2 {
		t.Fatalf("no evidence: both readings must stay visible: %s", g320Summary(accounts))
	}
	g320Rollout(t, codexHome, acctNow.Add(2*time.Minute), "pro_200", newPrimary, newWeekly)
	if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow.Add(AccountEvery)); err != nil {
		t.Fatal(err)
	}
	accounts := g320Read(t, cache, codexHome, acctNow.Add(AccountEvery))
	if len(accounts) != 1 {
		t.Fatalf("a turn logged while the login was read did not join: %s", g320Summary(accounts))
	}
	g320AssertNewTierOnly(t, accounts[0], newPrimary, newWeekly)
}

// Legacy cache (written before marks and spans existed): its reading time starts the login's
// span, so old-tier logs written after it bind (E2) after the upgrade (macrevb-602-1).
func TestG320ReviewLegacyCacheUpgradeKeepsOneAccount(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	before := acctNow.Add(-2 * time.Hour)
	oldPrimary, oldWeekly := before.Add(2*time.Hour), before.Add(3*24*time.Hour)
	bin, _ := fakeCodex(t, g320Limits("pro_100", oldPrimary, oldWeekly))
	if err := RefreshCodexAccount(context.Background(), cache, bin, before); err != nil {
		t.Fatal(err)
	}
	legacy := loadAccount(cache)
	legacy.MeterRef, legacy.Meters, legacy.Foreign, legacy.Spans = "", nil, nil, nil
	if err := save(cache, legacy); err != nil {
		t.Fatal(err)
	}
	g320Rollout(t, codexHome, before.Add(30*time.Minute), "pro_100", oldPrimary, oldWeekly)
	newPrimary, newWeekly := acctNow.Add(5*time.Hour), acctNow.Add(7*24*time.Hour)
	bin, _ = fakeCodex(t, g320Limits("pro_200", newPrimary, newWeekly))
	if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow); err != nil {
		t.Fatal(err)
	}
	accounts := g320Read(t, cache, codexHome, acctNow)
	if len(accounts) != 1 {
		t.Fatalf("legacy cache, upgraded login: %s", g320Summary(accounts))
	}
	g320AssertNewTierOnly(t, accounts[0], newPrimary, newWeekly)
}

// macrevb-602-2 / macrev2: login A's primary-only log, then login B (signing in rewrote the
// credential file) with a five-hour reset 30 s away or equal, cold cache: two accounts, A's
// log unbound.
func TestG320ReviewPrimaryOnlyCoincidenceStaysSeparate(t *testing.T) {
	for _, gap := range []time.Duration{30 * time.Second, 0} {
		t.Run(gap.String(), func(t *testing.T) {
			isolateHome(t)
			home, _ := os.UserHomeDir()
			codexHome := filepath.Join(home, ".codex")
			cache := t.TempDir()
			reset := acctNow.Add(3 * time.Hour)
			g320PrimaryOnlyRollout(t, codexHome, acctNow.Add(-time.Minute), "pro", reset)
			g320Auth(t, codexHome, acctNow.Add(-30*time.Second)) // B signs in
			if err := RefreshCodexAccount(context.Background(), cache, fakeCodexLogin(t, "beta@example.test", g320PrimaryOnly("pro", reset.Add(gap))), acctNow); err != nil {
				t.Fatal(err)
			}
			g320AssertSeparate(t, g320Read(t, cache, codexHome, acctNow))
		})
	}
}

// macrevb-602-2: both logins were read before and report the same single reset; a log of that
// cycle inside B's span is still ambiguous and binds neither.
func TestG320ReviewKnownLoginsEqualResetStaySeparate(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	reset := acctNow.Add(3 * time.Hour)
	if err := RefreshCodexAccount(context.Background(), cache, fakeCodexLogin(t, "alpha@example.test", g320PrimaryOnly("pro", reset)), acctNow.Add(-2*time.Hour)); err != nil {
		t.Fatal(err)
	}
	refA := loadAccount(cache).SubscriptionRef
	beta := fakeCodexLogin(t, "beta@example.test", g320PrimaryOnly("pro", reset))
	if err := RefreshCodexAccount(context.Background(), cache, beta, acctNow.Add(-10*time.Minute)); err != nil {
		t.Fatal(err)
	}
	g320PrimaryOnlyRollout(t, codexHome, acctNow.Add(-5*time.Minute), "pro", reset)
	if err := RefreshCodexAccount(context.Background(), cache, beta, acctNow); err != nil {
		t.Fatal(err)
	}
	if refA == "" || loadAccount(cache).SubscriptionRef == refA {
		t.Fatal("fixture must establish two different login references")
	}
	g320AssertSeparate(t, g320Read(t, cache, codexHome, acctNow))
}

// macrevb-602-2 (first round): A read earlier, A's two-window log, B with a nearby five-hour
// and a different weekly cycle.
func TestG320ReviewDistinctLoginsMayShareMeterTimes(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	primary, weekly := acctNow.Add(3*time.Hour), acctNow.Add(4*24*time.Hour)
	if err := RefreshCodexAccount(context.Background(), cache, fakeCodexLogin(t, "alpha@example.test", g320Limits("pro", primary, weekly)), acctNow.Add(-2*time.Hour)); err != nil {
		t.Fatal(err)
	}
	g320Rollout(t, codexHome, acctNow.Add(-time.Minute), "pro", primary, weekly)
	if err := RefreshCodexAccount(context.Background(), cache, fakeCodexLogin(t, "beta@example.test", g320Limits("pro", primary.Add(30*time.Second), weekly.Add(24*time.Hour))), acctNow); err != nil {
		t.Fatal(err)
	}
	g320AssertSeparate(t, g320Read(t, cache, codexHome, acctNow))
}

// The same-plan veto holds even when the credential file predates the log (an old session
// still writing A's logs after B signed in): an overlapping different cycle never binds.
func TestG320ReviewOneMatchingResetWithAConflictStaysSeparate(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	primary, weekly := acctNow.Add(3*time.Hour), acctNow.Add(4*24*time.Hour)
	g320Auth(t, codexHome, acctNow.Add(-24*time.Hour))
	g320Rollout(t, codexHome, acctNow.Add(-time.Minute), "pro", primary, weekly)
	if err := RefreshCodexAccount(context.Background(), cache, fakeCodexLogin(t, "beta@example.test", g320Limits("pro", primary.Add(30*time.Second), weekly.Add(24*time.Hour))), acctNow); err != nil {
		t.Fatal(err)
	}
	g320AssertSeparate(t, g320Read(t, cache, codexHome, acctNow))
}

// macrev2-602-1 / macrevb-602-4: cold cache, login A's fresh pro_100 reading, login B's
// pro_200 runtime, different cycles: A's reading stays visible and unbound.
func TestG320ReviewOtherPlanLogsMustNotDisappear(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	g320Rollout(t, codexHome, acctNow.Add(-time.Minute), "pro_100", acctNow.Add(time.Hour), acctNow.Add(3*24*time.Hour))
	g320Auth(t, codexHome, acctNow.Add(-30*time.Second)) // B signs in
	if err := RefreshCodexAccount(context.Background(), cache, fakeCodexLogin(t, "beta@example.test", g320Limits("pro_200", acctNow.Add(5*time.Hour), acctNow.Add(7*24*time.Hour))), acctNow); err != nil {
		t.Fatal(err)
	}
	accounts := g320Read(t, cache, codexHome, acctNow)
	g320AssertSeparate(t, accounts)
	for _, a := range accounts {
		if a.Via == "" && (a.Plan != "pro_100" || len(a.Windows) != 2) {
			t.Fatalf("login A's reading was altered: %s", g320Summary(accounts))
		}
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

func g320AssertSeparate(t *testing.T, accounts []Account) {
	t.Helper()
	if len(accounts) != 2 {
		t.Fatalf("two logins shown as %d accounts: %s", len(accounts), g320Summary(accounts))
	}
	for _, a := range accounts {
		if a.Via == "" && a.Subscription != nil {
			t.Fatalf("an unbound log account acquired a login reference: %+v", a.Subscription)
		}
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
