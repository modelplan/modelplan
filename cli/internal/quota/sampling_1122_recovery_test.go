// SPDX-License-Identifier: MIT
package quota

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestSampling1122TransientProviderFileReadFailureNotMemoized(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	writeZCodeProviders(t, home, zcodeStaleProviderFiles["no_selection"])

	file := ZCodeProviderConfig(home)
	if err := os.Chmod(file, 0o000); err != nil {
		t.Fatal(err)
	}
	if zcodeProviderFileKeyless(file) {
		t.Fatal("fixture: the unreadable file classified as keyless")
	}
	if err := os.Chmod(file, 0o600); err != nil {
		t.Fatal(err)
	}
	if !zcodeProviderFileKeyless(file) {
		t.Fatal("a transient read failure stuck: the restored file still classifies as keyed")
	}
}

func TestSampling1122ErrorBodyRejectsInvalidPercentages(t *testing.T) {
	primary := fmt.Sprintf(`{"used_percent":40,"limit_window_seconds":18000,"reset_at":%d}`, acctNow.Add(time.Hour).Unix())
	if snap := rateLimitsFromErrorBody(g3158DecodeErrorMessage(
		`{"plan_type":"pro","rate_limit":{"primary_window":{"used_percent":-25,"limit_window_seconds":18000,"reset_at":`+
			fmt.Sprint(acctNow.Add(time.Hour).Unix())+`}}}`), acctNow); snap != nil {
		t.Fatalf("a negative primary percentage became a reading: %+v", snap)
	}
	snap := rateLimitsFromErrorBody(g3158DecodeErrorMessage(
		`{"plan_type":"pro","rate_limit":{"primary_window":`+primary+
			`,"secondary_window":{"used_percent":125,"limit_window_seconds":604800,"reset_at":`+
			fmt.Sprint(acctNow.Add(25*time.Hour).Unix())+`}}}`), acctNow)
	if snap == nil || snap.Primary == nil || *snap.Primary.UsedPercent != 40 {
		t.Fatalf("valid primary window lost: %+v", snap)
	}
	if snap.Secondary != nil {
		t.Fatalf("an out-of-range weekly window was kept: %+v", snap.Secondary)
	}
}

func TestSampling1122NewerFiveHourEventKeepsUsedUpWeekly(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	g3158RuntimeUsedUp(t, cache, acctNow)
	now := acctNow.Add(63 * time.Minute)
	logs := g3158OldLogs()
	fiveHourAt := now.Add(-5 * time.Minute)
	used := 12.0
	reset := time.Unix(g3158Reset, 0).UTC()
	logs.Windows = append([]Window{{Kind: "five_hour", Limit: "codex", WindowMinutes: 300,
		UsedPercent: &used, ResetsAt: &reset, ObservedAt: fiveHourAt, Origin: "local_history"}}, logs.Windows...)
	logs.ObservedAt = fiveHourAt // mergeCodex advances the account stamp with the newer event
	r := Report{Accounts: []Account{logs}, Sources: []SourceStatus{{Source: "codex", Status: "ok"}}}
	applyAccount(&r, cache, now)
	a, w := g3158Weekly(t, r)
	if w.UsedPercent == nil || *w.UsedPercent != 100 || a.Via != "codex-account" {
		t.Fatalf("an older weekly window rode a newer five-hour event past the runtime reading: %+v %+v", a, w)
	}
}

// 1155-D (the other side): once the logs carry a weekly observation at least as recent as the
// retained runtime window, they stand in again.
func TestSampling1122FreshWeeklyLogStillWins(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	g3158RuntimeUsedUp(t, cache, acctNow)
	now := acctNow.Add(63 * time.Minute)
	logs := g3158OldLogs()
	fresh := now.Add(-5 * time.Minute)
	logs.ObservedAt = fresh
	logs.Windows[0].ObservedAt = fresh
	r := Report{Accounts: []Account{logs}, Sources: []SourceStatus{{Source: "codex", Status: "ok"}}}
	applyAccount(&r, cache, now)
	a, w := g3158Weekly(t, r)
	if a.Via != "" || w.UsedPercent == nil || *w.UsedPercent != 66 {
		t.Fatalf("fresh weekly logs lost to a retained runtime reading: %+v %+v", a, w)
	}
}

func TestSampling1122RolloutFiveHourDoesNotReviveOldWeek(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	codexHome, cache := filepath.Join(home, ".codex"), t.TempDir()
	now := acctNow.Add(63 * time.Minute)
	dir := filepath.Join(codexHome, "sessions", now.Format("2006"), now.Format("01"), now.Format("02"))
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	line := func(at time.Time, limits string) string {
		return fmt.Sprintf(`{"timestamp":%q,"type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","plan_type":"pro",%s}}}`+"\n", at.UTC().Format(time.RFC3339), limits)
	}
	old := line(acctNow.Add(-82*time.Hour), fmt.Sprintf(`"secondary":{"used_percent":66,"window_minutes":10080,"resets_at":%d}`, g3158Reset))
	newer := line(now.Add(-5*time.Minute), fmt.Sprintf(`"primary":{"used_percent":12,"window_minutes":300,"resets_at":%d}`, now.Add(2*time.Hour).Unix()))
	path := filepath.Join(dir, "rollout-sampling.jsonl")
	if err := os.WriteFile(path, []byte(old+newer), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(path, now, now); err != nil {
		t.Fatal(err)
	}
	g3158RuntimeUsedUp(t, cache, acctNow)
	accounts := g320Read(t, cache, codexHome, now)
	a, w := g3158Weekly(t, Report{Accounts: accounts})
	if a.Via != "codex-account" || w.UsedPercent == nil || *w.UsedPercent != 100 {
		t.Fatalf("new five-hour event revived the old week: %+v", a)
	}
}
