// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// G3-158 (owner build 2, 11-22): the Codex column showed weekly 34% read 82 hours earlier from the
// session logs, while Codex's own account reading of a few minutes before said the week was used
// up. Once the runtime reading stopped being "live" (its refresh failed, or it aged past the
// freshness hour), the session logs won however old they were, and the plan name went with them.

const g3158Reset = int64(1792228800) // 2026-10-17 09:20 UTC: acctNow + 25h20m

func g3158RuntimeUsedUp(t *testing.T, cache string, at time.Time) {
	t.Helper()
	body := fmt.Sprintf(`{"rateLimitsByLimitId":{"codex":{"limitId":"codex","planType":"pro",
 "secondary":{"usedPercent":100,"windowDurationMins":10080,"resetsAt":%d}}}}`, g3158Reset)
	var resp rlResponse
	if err := json.Unmarshal([]byte(body), &resp); err != nil {
		t.Fatal(err)
	}
	if err := save(cache, snapFrom(&resp, at)); err != nil {
		t.Fatal(err)
	}
}

// The session-log account as readCodex builds it: a weekly reading taken 82 hours ago in the same
// weekly cycle (same reset as the runtime reading).
func g3158OldLogs() Account {
	used := 66.0
	reset := time.Unix(g3158Reset, 0).UTC()
	at := acctNow.Add(-82 * time.Hour)
	return Account{Source: "codex", Plan: "pro", ObservedAt: at, Windows: []Window{{Kind: "weekly", Limit: "codex", WindowMinutes: 10080,
		UsedPercent: &used, ResetsAt: &reset, ObservedAt: at, Origin: "local_history"}}}
}

func g3158Weekly(t *testing.T, r Report) (Account, Window) {
	t.Helper()
	var found []Account
	for _, a := range r.Accounts {
		if a.Source == "codex" {
			found = append(found, a)
		}
	}
	if len(found) != 1 {
		t.Fatalf("want one Codex account, got %+v", r.Accounts)
	}
	for _, w := range found[0].Windows {
		if w.Kind == "weekly" {
			return found[0], w
		}
	}
	t.Fatalf("no weekly window: %+v", found[0])
	return Account{}, Window{}
}

// A refresh failed ten minutes after the used-up reading: the retained runtime reading (minutes
// old) stands over the 82-hour-old logs, marked stale, with the failure named.
func TestG3158RetainedRuntimeReadingBeatsOlderSessionLogs(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	g3158RuntimeUsedUp(t, cache, acctNow)
	failedAt := acctNow.Add(10 * time.Minute)
	_ = RefreshCodexAccount(context.Background(), cache, failingCodex(t), failedAt)
	if s := loadAccount(cache); s == nil || s.Status == "ok" || s.Good == nil {
		t.Fatalf("snapshot %+v", s)
	}
	now := acctNow.Add(63 * time.Minute)
	r := Report{Accounts: []Account{g3158OldLogs()}, Sources: []SourceStatus{{Source: "codex", Status: "ok"}}}
	applyAccount(&r, cache, now)
	a, w := g3158Weekly(t, r)
	Evaluate(&a, now)
	w = a.Windows[0]
	if w.UsedPercent == nil || *w.UsedPercent != 100 || !w.ObservedAt.Equal(acctNow) || w.Origin != "runtime" {
		t.Fatalf("older session-log reading shown over the newer runtime one: %+v", w)
	}
	if a.Plan != "pro" || a.Via != "codex-account" || !a.Stale {
		t.Fatalf("account %+v", a)
	}
	if f := codexAccountFailure(r); f == nil || f.Status != "stale" {
		t.Fatalf("failure not named: %+v", r.Sources)
	}
}

// No refresh ran for an hour (the runtime reading aged past the freshness hour without a
// failure): the same holds.
func TestG3158AgedRuntimeReadingBeatsOlderSessionLogs(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	g3158RuntimeUsedUp(t, cache, acctNow)
	now := acctNow.Add(63 * time.Minute)
	if CodexRuntimeAvailable(cache, consent.Capture(), now) {
		t.Fatal("fixture: the aged reading must not count as live")
	}
	r := Report{Accounts: []Account{g3158OldLogs()}, Sources: []SourceStatus{{Source: "codex", Status: "ok"}}}
	applyAccount(&r, cache, now)
	a, w := g3158Weekly(t, r)
	if w.UsedPercent == nil || *w.UsedPercent != 100 || a.Via != "codex-account" {
		t.Fatalf("older session-log reading shown over the newer runtime one: %+v %+v", a, w)
	}
}

// Session logs at least as new as the unavailable runtime reading still win (G3-20 option B and
// the stale-runtime fallback are unchanged).
func TestG3158NewerSessionLogsStillWinOverUnavailableRuntime(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	g3158RuntimeUsedUp(t, cache, acctNow)
	now := acctNow.Add(63 * time.Minute)
	logs := g3158OldLogs()
	logs.ObservedAt = now.Add(-time.Minute)
	logs.Windows[0].ObservedAt = logs.ObservedAt
	r := Report{Accounts: []Account{logs}, Sources: []SourceStatus{{Source: "codex", Status: "ok"}}}
	applyAccount(&r, cache, now)
	a, w := g3158Weekly(t, r)
	if a.Via != "" || w.UsedPercent == nil || *w.UsedPercent != 66 {
		t.Fatalf("fresh session logs lost to an unavailable runtime reading: %+v", a)
	}
}

// Display rule (pinned, already held before G3-158): a retained Codex reading whose window has
// reset since it was read shows no value, only reset_passed; a reading inside the current cycle
// stays a stale value. The owner's 82-hour reading was of the current cycle (same reset as the
// runtime reading), so the wrong number came from choosing the older source, fixed above.
func TestG3158RetainedCodexReadingAcrossAResetIsNotCurrent(t *testing.T) {
	now := acctNow
	used := 66.0
	for _, origin := range []string{"local_history", "runtime"} {
		passed := now.Add(-time.Hour)
		w := Window{Kind: "weekly", Limit: "codex", WindowMinutes: 10080, UsedPercent: &used, ResetsAt: &passed,
			ObservedAt: now.Add(-82 * time.Hour), Origin: origin}
		evalWindow(&w, now)
		if w.UsedPercent != nil || w.RemainingPercent != nil || w.UnknownReason != "reset_passed" {
			t.Fatalf("%s: a reading from before the reset shown as current: %+v", origin, w)
		}
		ahead := now.Add(24 * time.Hour)
		w = Window{Kind: "weekly", Limit: "codex", WindowMinutes: 10080, UsedPercent: &used, ResetsAt: &ahead,
			ObservedAt: now.Add(-82 * time.Hour), Origin: origin}
		evalWindow(&w, now)
		if w.RemainingPercent == nil || *w.RemainingPercent != 34 || !w.Stale {
			t.Fatalf("%s: a reading of the current cycle lost: %+v", origin, w)
		}
	}
}

// The same through ReadPermitted (the app-server's read) with real rollout files: a runtime
// reading whose refresh then failed stands over rollouts from 82 hours before it.
func TestG3158ReadPermittedKeepsTheNewerRuntimeReading(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	cache := t.TempDir()
	primary, weekly := acctNow.Add(3*time.Hour), acctNow.Add(25*time.Hour)
	g320Rollout(t, codexHome, acctNow.Add(-82*time.Hour), "pro_100", acctNow.Add(-78*time.Hour), weekly)
	bin, _ := fakeCodex(t, g320Limits("pro_100", primary, weekly))
	if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow); err != nil {
		t.Fatal(err)
	}
	_ = RefreshCodexAccount(context.Background(), cache, failingCodex(t), acctNow.Add(10*time.Minute))
	accounts := g320Read(t, cache, codexHome, acctNow.Add(63*time.Minute))
	if len(accounts) != 1 || accounts[0].Via != "codex-account" || accounts[0].Plan != "pro_100" || !accounts[0].Stale {
		t.Fatalf("the 82-hour-old rollouts replaced the newer runtime reading: %s", g320Summary(accounts))
	}
	for _, w := range accounts[0].Windows {
		if w.Origin != "runtime" || !w.ObservedAt.Equal(acctNow) {
			t.Fatalf("window %+v", w)
		}
	}
}
