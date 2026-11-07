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

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// G3-20 under the owner's decision of 2026-11-06 (option B, design-602-account-identity):
// while Codex's live account reading is available it is the only Codex account; session logs
// are used only without it. Covers the MACREV-B / MACREV2 counterexamples of #602.
// Synthetic e-mails, plans and instants only.

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

// The owner's case: one login upgraded pro_100 -> pro_200 before ModelPlan ever ran; the
// newest logs still carry the old tier. One account, the new plan, only live windows.
func TestG320ReviewColdUpgradeKeepsOneAccount(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	g320Rollout(t, codexHome, acctNow.Add(-2*time.Hour), "pro_100", acctNow.Add(time.Hour), acctNow.Add(3*24*time.Hour))
	newPrimary, newWeekly := acctNow.Add(5*time.Hour), acctNow.Add(7*24*time.Hour)
	bin, _ := fakeCodex(t, g320Limits("pro_200", newPrimary, newWeekly))
	if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow); err != nil {
		t.Fatal(err)
	}
	accounts := g320Read(t, cache, codexHome, acctNow)
	if len(accounts) != 1 {
		t.Fatalf("one upgraded login: %s", g320Summary(accounts))
	}
	g320AssertLiveOnly(t, accounts[0], "pro_200", newPrimary, newWeekly)
}

// macrevb-602-2 / macrev2: login A's primary-only log, login B live with a five-hour reset
// 30 s away or equal. Only B is shown, with B's own reading; A's log never acquires B's
// reference because it is not an account while the live reading works.
func TestG320ReviewPrimaryOnlyCoincidenceShowsOnlyTheLiveLogin(t *testing.T) {
	for _, gap := range []time.Duration{30 * time.Second, 0} {
		t.Run(gap.String(), func(t *testing.T) {
			isolateHome(t)
			home, _ := os.UserHomeDir()
			codexHome := filepath.Join(home, ".codex")
			cache := t.TempDir()
			reset := acctNow.Add(3 * time.Hour)
			g320PrimaryOnlyRollout(t, codexHome, acctNow.Add(-time.Minute), "pro", reset)
			if err := RefreshCodexAccount(context.Background(), cache, fakeCodexLogin(t, "beta@example.test", g320PrimaryOnly("pro", reset.Add(gap))), acctNow); err != nil {
				t.Fatal(err)
			}
			accounts := g320Read(t, cache, codexHome, acctNow)
			if len(accounts) != 1 {
				t.Fatalf("live reading available: %s", g320Summary(accounts))
			}
			a := accounts[0]
			if len(a.Windows) != 1 || a.Windows[0].Origin != "runtime" || a.Windows[0].UsedPercent == nil || *a.Windows[0].UsedPercent != 21 || !a.Windows[0].ResetsAt.Equal(reset.Add(gap)) {
				t.Fatalf("the shown account carries log data: %+v", a.Windows)
			}
		})
	}
}

// macrevb-602-4 / macrev2-602-1: login A's fresh pro_100 log, login B live on pro_200. B only;
// nothing of A's reading is attributed to B.
func TestG320ReviewOtherPlanLogsAreNotAttributedToTheLiveLogin(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	g320Rollout(t, codexHome, acctNow.Add(-time.Minute), "pro_100", acctNow.Add(time.Hour), acctNow.Add(3*24*time.Hour))
	primary, weekly := acctNow.Add(5*time.Hour), acctNow.Add(7*24*time.Hour)
	if err := RefreshCodexAccount(context.Background(), cache, fakeCodexLogin(t, "beta@example.test", g320Limits("pro_200", primary, weekly)), acctNow); err != nil {
		t.Fatal(err)
	}
	accounts := g320Read(t, cache, codexHome, acctNow)
	if len(accounts) != 1 {
		t.Fatalf("live reading available: %s", g320Summary(accounts))
	}
	g320AssertLiveOnly(t, accounts[0], "pro_200", primary, weekly)
}

// Login switch: A was live earlier, B is live now; A's logs remain on disk. Only B.
func TestG320ReviewLoginSwitchShowsTheNewLoginOnly(t *testing.T) {
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
	bPrimary, bWeekly := primary.Add(30*time.Second), weekly.Add(24*time.Hour)
	if err := RefreshCodexAccount(context.Background(), cache, fakeCodexLogin(t, "beta@example.test", g320Limits("pro", bPrimary, bWeekly)), acctNow); err != nil {
		t.Fatal(err)
	}
	accounts := g320Read(t, cache, codexHome, acctNow)
	if len(accounts) != 1 || accounts[0].Subscription == nil || accounts[0].Subscription.Ref == refA {
		t.Fatalf("after a login switch only the new login is shown: %s", g320Summary(accounts))
	}
	g320AssertLiveOnly(t, accounts[0], "pro", bPrimary, bWeekly)
}

// Live reading unavailable (never read, failed, or older than accountKeep): the session logs
// are the Codex reading, as before, unbound.
func TestG320ReviewWithoutLiveReadingLogsAreTheFallback(t *testing.T) {
	primary, weekly := acctNow.Add(3*time.Hour), acctNow.Add(4*24*time.Hour)
	for _, tc := range []struct {
		name  string
		setup func(t *testing.T, cache string)
		at    time.Time
	}{
		{"never read", func(*testing.T, string) {}, acctNow},
		{"failed read", func(t *testing.T, cache string) {
			if err := save(cache, &accountSnap{SchemaVersion: 1, Status: "error", ObservedAt: acctNow.Add(-time.Minute)}); err != nil {
				t.Fatal(err)
			}
		}, acctNow},
		// G3-13 (#523): past the freshness interval but within the 6 h keep, the
		// runtime reading is no longer available, so the logs are the reading.
		{"reading stale", func(t *testing.T, cache string) {
			bin, _ := fakeCodex(t, g320Limits("pro", primary, weekly))
			if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow.Add(-3*time.Hour)); err != nil {
				t.Fatal(err)
			}
		}, acctNow},
		{"reading too old", func(t *testing.T, cache string) {
			bin, _ := fakeCodex(t, g320Limits("pro", primary, weekly))
			if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow.Add(-accountKeep-time.Hour)); err != nil {
				t.Fatal(err)
			}
		}, acctNow},
	} {
		t.Run(tc.name, func(t *testing.T) {
			isolateHome(t)
			home, _ := os.UserHomeDir()
			codexHome := filepath.Join(home, ".codex")
			cache := t.TempDir()
			tc.setup(t, cache)
			g320Rollout(t, codexHome, acctNow.Add(-10*time.Minute), "pro", primary, weekly)
			accounts := g320Read(t, cache, codexHome, tc.at)
			if len(accounts) != 1 || accounts[0].Via != "" || accounts[0].Subscription != nil || len(accounts[0].Windows) != 2 {
				t.Fatalf("local fallback: %s", g320Summary(accounts))
			}
			for _, w := range accounts[0].Windows {
				if w.Origin != "local_history" {
					t.Fatalf("fallback window origin %q", w.Origin)
				}
			}
		})
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

// g320AssertLiveOnly: the shown account is the live reading's, with only its windows.
func g320AssertLiveOnly(t *testing.T, a Account, plan string, primary, weekly time.Time) {
	t.Helper()
	if a.Plan != plan || a.Via != "codex-account" || a.Subscription == nil || a.Subscription.Status != "verified" {
		t.Fatalf("live account = plan %q via %q subscription %+v", a.Plan, a.Via, a.Subscription)
	}
	if len(a.Windows) != 2 {
		t.Fatalf("windows = %d", len(a.Windows))
	}
	for _, w := range a.Windows {
		if w.Origin != "runtime" || w.ResetsAt == nil || (!w.ResetsAt.Equal(primary) && !w.ResetsAt.Equal(weekly)) {
			t.Fatalf("log window shown on the live account: %+v", w)
		}
	}
}

// The live account keeps the current session's harness (model, effort, allowance pool),
// which only the logs carry; none of the logs' plan, windows or credits.
func TestG320ReviewLiveAccountKeepsTheSessionHarnessOnly(t *testing.T) {
	isolateHome(t)
	codexHome := poolHome(t, false)
	cache := t.TempDir()
	primary, weekly := poolNow.Add(4*time.Hour), poolNow.Add(5*24*time.Hour)
	bin, _ := fakeCodex(t, g320Limits("pro", primary, weekly))
	if err := RefreshCodexAccount(context.Background(), cache, bin, poolNow); err != nil {
		t.Fatal(err)
	}
	accounts := g320Read(t, cache, codexHome, poolNow)
	if len(accounts) != 1 {
		t.Fatalf("live reading available: %s", g320Summary(accounts))
	}
	a := accounts[0]
	if a.Harness == nil || a.Harness.Model != "gpt-6-sol" {
		t.Fatalf("session harness not kept on the live account: %+v", a.Harness)
	}
	g320AssertLiveOnly(t, a, "pro", primary, weekly)
}

// macrev2-602-2: a successful, recent runtime reading that the scheduler nevertheless treats as
// unavailable (runtime turned off, no windows, every window already reset) leaves the session
// logs as the Codex reading: one unbound local account with its windows, and the unusable
// runtime snapshot is not shown beside it.
func TestG320ReviewUnavailableRuntimeKeepsLocalFallback(t *testing.T) {
	primary, weekly := acctNow.Add(3*time.Hour), acctNow.Add(4*24*time.Hour)
	noWindows := `{"rateLimitsByLimitId":{"codex":{"limitId":"codex","planType":"pro","primary":null,"secondary":null}}}`
	for _, tc := range []struct {
		name, result string
		after        func(t *testing.T)
	}{
		{"runtime_disabled_after_capture", g320Limits("pro", primary, weekly), func(t *testing.T) { t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off") }},
		{"no_runtime_windows", noWindows, func(*testing.T) {}},
		{"all_runtime_windows_expired", g320Limits("pro", acctNow.Add(-time.Hour), acctNow.Add(-2*time.Hour)), func(*testing.T) {}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			isolateHome(t)
			home, _ := os.UserHomeDir()
			codexHome := filepath.Join(home, ".codex")
			cache := t.TempDir()
			bin, _ := fakeCodex(t, tc.result)
			if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow.Add(-time.Minute)); err != nil {
				t.Fatal(err)
			}
			if s := loadAccount(cache); s == nil || s.Status != "ok" {
				t.Fatalf("fixture must leave a successful recent runtime reading: %+v", s)
			}
			tc.after(t)
			if CodexRuntimeAvailable(cache, consent.Capture(), acctNow) {
				t.Fatal("fixture must make the scheduler treat the runtime as unavailable")
			}
			g320Rollout(t, codexHome, acctNow.Add(-10*time.Minute), "pro", primary, weekly)
			accounts := g320Read(t, cache, codexHome, acctNow)
			if len(accounts) != 1 || accounts[0].Via != "" || accounts[0].Subscription != nil || len(accounts[0].Windows) != 2 {
				t.Fatalf("runtime unavailable: the local fallback must be the Codex reading, got %s", g320Summary(accounts))
			}
			for _, w := range accounts[0].Windows {
				if w.Origin != "local_history" {
					t.Fatalf("fallback window origin %q", w.Origin)
				}
			}
		})
	}
}
