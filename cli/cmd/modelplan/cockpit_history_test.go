// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/queries"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// historyLedger: the same synthetic ledger as the snapshot tests, stamped for the fresh store.
func historyLedger(t *testing.T, epoch string, now time.Time) speed.PerfLedger {
	i := func(n int64) *int64 { return &n }
	return speed.PerfLedger{SchemaVersion: 1, Since: now.Add(-30 * 24 * time.Hour), Rows: []speed.PerfRow{
		{GrantEpoch: &speed.GrantEpoch{StoreEpoch: epoch}, Day: now.Add(-24 * time.Hour).Format("2006-01-02"), Source: "codex", Model: "gpt-5.3",
			TokenKinds:       speed.TokenKinds{InputTokens: i(1000), CacheReadTokens: i(4000), CacheWriteTokens: i(500)},
			ObservedRequests: 10, ObservedOutputTokens: 2000, EligibleRequests: 6, EligibleOutputTokens: 1200, GenMs: 20000},
		{GrantEpoch: &speed.GrantEpoch{StoreEpoch: epoch}, Day: now.Add(-16 * 24 * time.Hour).Format("2006-01-02"), Source: "codex", Model: "gpt-5.3",
			TokenKinds:       speed.TokenKinds{InputTokens: i(500), CacheReadTokens: i(500)},
			ObservedRequests: 5, ObservedOutputTokens: 1000, EligibleRequests: 5, EligibleOutputTokens: 1000, GenMs: 25000},
		{GrantEpoch: &speed.GrantEpoch{StoreEpoch: epoch}, Day: now.Format("2006-01-02"), Source: "claude-code", Model: "sonnet",
			TokenKinds:       speed.TokenKinds{InputTokens: i(200)},
			ObservedRequests: 4, ObservedOutputTokens: 500, EligibleRequests: 4, EligibleOutputTokens: 400, GenMs: 8000},
		{GrantEpoch: &speed.GrantEpoch{StoreEpoch: epoch}, Day: now.Add(-2 * 24 * time.Hour).Format("2006-01-02"), Source: "claude-code", Model: "opus",
			TokenKinds:       speed.TokenKinds{InputTokens: i(100), CacheReadTokens: i(900), CacheWriteTokens: i(100)},
			ObservedRequests: 3, ObservedOutputTokens: 300, EligibleRequests: 2, EligibleOutputTokens: 200, GenMs: 10000},
	}}
}

func writeHistoryLedger(t *testing.T, cache string, ledger speed.PerfLedger) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(speed.PerfPath(cache)), 0o700); err != nil {
		t.Fatal(err)
	}
	payload, err := json.Marshal(ledger)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(speed.PerfPath(cache), payload, 0o600); err != nil {
		t.Fatal(err)
	}
}

func TestCockpitHistoryBindsWindowsAndRanks(t *testing.T) {
	oldLocal, oldNow := time.Local, cockpitHistoryNow
	time.Local, cockpitHistoryNow = time.UTC, func() time.Time { return time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC) }
	t.Cleanup(func() { time.Local, cockpitHistoryNow = oldLocal, oldNow })
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_HISTORY", "")
	state, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	now := cockpitHistoryNow()
	cache := t.TempDir()
	writeHistoryLedger(t, cache, historyLedger(t, state.StoreEpoch, now))
	refA, refB := "0123456789abcdef", "fedcba9876543210"
	view := appserver.View{PublicModels: []digest.Model{{ID: "gpt-5.3"}, {ID: "sonnet"}, {ID: "opus"}}, QuotaReport: quota.Report{Accounts: []quota.Account{
		{Source: "codex", Subscription: &quota.Binding{Ref: refA, Status: "verified", ObservedAt: now.Add(-30 * time.Minute)}},
		{Source: "claude-code", Subscription: &quota.Binding{Ref: refB, Status: "verified", ObservedAt: now.Add(-30 * time.Minute)}},
	}}}
	stamp := appserver.Stamp{Epoch: state.StoreEpoch, Generation: state.Generation}
	admission := queries.CockpitAdmission{Stamp: stamp, Scopes: []string{consent.ScopeClaudeLocalHistory, consent.ScopeCodexLocalHistory}}
	groups := map[string][]wire.CockpitAccount{refA: {}, refB: {}}
	data, err := (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), view, admission, groups)
	if err != nil {
		t.Fatal(err)
	}
	if data.Version != 1 || data.Coverage != "local-history" || !strings.Contains(strings.Join(data.Sources, ","), "local-history") {
		t.Fatalf("header: %+v", data)
	}
	if len(data.Subscriptions) != 2 || data.Subscriptions[0].SubscriptionRef != refA || len(data.Subscriptions[0].Sources) != 1 {
		t.Fatalf("subscriptions: %+v", data.Subscriptions)
	}
	codex := data.Subscriptions[0].Sources[0]
	if codex.Source != "codex" || codex.BindingBasis != "source-wide-current-binding" {
		t.Fatalf("binding basis: %+v", codex)
	}
	w7, w30 := codex.Recent7d, codex.Recent30d
	if *w7.InputTokens != 1000 || *w7.CacheReadTokens != 4000 || w7.OutputTokens != 2000 || *w7.CacheHitRatio != 0.8 || *w7.GenerationTps != 60 {
		t.Fatalf("codex 7d: %+v", w7)
	}
	if w30.CacheWriteTokens != nil || *w30.CacheReadTokens != 4500 || *w30.CacheHitRatio != 0.75 || *w30.GenerationTps != 48.9 {
		t.Fatalf("codex 30d keeps unknown cache write: %+v", w30)
	}
	// claude-code's unknown cache sums stay null on the wire, never zero.
	b, _ := json.Marshal(data.Subscriptions[1].Sources[0].Recent7d)
	if !strings.Contains(string(b), `"cacheReadTokens":null`) || !strings.Contains(string(b), `"cacheHitRatio":null`) || strings.Contains(string(b), `"cacheReadTokens":0`) {
		t.Fatalf("claude-code 7d: %s", b)
	}
	if data.Models.Recent7d.Entities != 3 || data.Models.Recent7d.Top[0].Name != "gpt-5.3" || data.Models.Recent7d.Top[0].ObservedOutputTokens != 2000 {
		t.Fatalf("model ranking: %+v", data.Models.Recent7d)
	}
	if data.Tools.Recent7d.Entities != 2 || data.Tools.Recent7d.Top[0].Name != "codex" || data.Tools.Recent7d.Top[0].Share != 0.714 {
		t.Fatalf("tool ranking: %+v", data.Tools.Recent7d)
	}

	// An ambiguous binding withholds the subscription windows; rankings stay unattributed.
	view.QuotaReport.Accounts = append(view.QuotaReport.Accounts, quota.Account{Source: "claude-code",
		Subscription: &quota.Binding{Ref: "1111111111111111", Status: "verified", ObservedAt: now.Add(-30 * time.Minute)}})
	data, err = (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), view, admission, groups)
	if err != nil || len(data.Subscriptions) != 1 || len(data.Subscriptions[0].Sources) != 1 || data.Subscriptions[0].Sources[0].Source != "codex" {
		t.Fatalf("ambiguous source attributed: %+v, %v", data.Subscriptions, err)
	}
	// A source whose scope the client did not grant contributes nowhere.
	data, err = (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), view, queries.CockpitAdmission{Stamp: stamp, Scopes: []string{consent.ScopeCodexLocalHistory}}, groups)
	if err != nil || len(data.Subscriptions) != 1 || data.Tools.Recent7d.Entities != 1 || data.Tools.Recent7d.Top[0].Name != "codex" {
		t.Fatalf("unconsented source leaked: %+v, %v", data.Tools, err)
	}
	// The stale fence is rejected.
	stale := admission
	stale.Stamp.Generation++
	if _, err := (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), view, stale, groups); err == nil {
		t.Fatal("stale fence accepted")
	}
}

func TestCockpitHistoryWithoutLedgerOrRecording(t *testing.T) {
	oldLocal, oldNow := time.Local, cockpitHistoryNow
	time.Local, cockpitHistoryNow = time.UTC, func() time.Time { return time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC) }
	t.Cleanup(func() { time.Local, cockpitHistoryNow = oldLocal, oldNow })
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_HISTORY", "")
	state, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	now := cockpitHistoryNow()
	stamp := appserver.Stamp{Epoch: state.StoreEpoch, Generation: state.Generation}
	admission := queries.CockpitAdmission{Stamp: stamp, Scopes: []string{consent.ScopeCodexLocalHistory}}
	missing, err := (sharedCockpit{cache: t.TempDir()}).cockpitHistory(context.Background(), appserver.View{}, admission, nil)
	if err != nil || missing.Coverage != "unavailable" || len(missing.Subscriptions) != 0 || missing.Models.Recent7d.Entities != 0 {
		t.Fatalf("missing ledger: %+v, %v", missing, err)
	}
	cache := t.TempDir()
	writeHistoryLedger(t, cache, speed.PerfLedger{SchemaVersion: 1, Rows: []speed.PerfRow{}})
	unstarted, err := (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), appserver.View{}, admission, nil)
	if err != nil || unstarted.Coverage != "unavailable" {
		t.Fatalf("ledger without since: %+v, %v", unstarted, err)
	}
	writeHistoryLedger(t, cache, speed.PerfLedger{SchemaVersion: 1, Since: now, Rows: []speed.PerfRow{}})
	empty, err := (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), appserver.View{}, admission, nil)
	if err != nil || empty.Coverage != "local-history" || len(empty.Subscriptions) != 0 || len(empty.Sources) != 1 {
		t.Fatalf("empty ledger: %+v, %v", empty, err)
	}
}

func TestCockpitHistoryRecordingOff(t *testing.T) {
	oldLocal, oldNow := time.Local, cockpitHistoryNow
	time.Local, cockpitHistoryNow = time.UTC, func() time.Time { return time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC) }
	t.Cleanup(func() { time.Local, cockpitHistoryNow = oldLocal, oldNow })
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_HISTORY", "off")
	state, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	now := cockpitHistoryNow()
	cache := t.TempDir()
	writeHistoryLedger(t, cache, historyLedger(t, state.StoreEpoch, now))
	admission := queries.CockpitAdmission{Stamp: appserver.Stamp{Epoch: state.StoreEpoch, Generation: state.Generation}, Scopes: []string{consent.ScopeCodexLocalHistory}}
	data, err := (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), appserver.View{}, admission, nil)
	if err != nil || data.Coverage != "recording-off" || len(data.Subscriptions) != 0 || data.Models.Recent7d.Entities != 0 || data.Tools.Recent7d.Entities != 0 {
		t.Fatalf("recording off: %+v, %v", data, err)
	}
}

func TestReadCockpitOmitsHistoryWithoutNegotiation(t *testing.T) {
	oldLocal, oldNow := time.Local, cockpitHistoryNow
	time.Local, cockpitHistoryNow = time.UTC, func() time.Time { return time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC) }
	t.Cleanup(func() { time.Local, cockpitHistoryNow = oldLocal, oldNow })
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_HISTORY", "")
	state, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	now := cockpitHistoryNow()
	cache := t.TempDir()
	writeHistoryLedger(t, cache, historyLedger(t, state.StoreEpoch, now))
	ref := "0123456789abcdef"
	view := appserver.View{Stamp: appserver.Stamp{Epoch: state.StoreEpoch, Generation: state.Generation}, Scopes: []string{consent.ScopeCodexLocalHistory},
		QuotaReport: quota.Report{Accounts: []quota.Account{{Source: "codex", Subscription: &quota.Binding{Ref: ref, Status: "verified", ObservedAt: now.Add(-30 * time.Minute)}}}}}
	source := sharedCockpit{backend: cockpitViewBackend{view: view}, cache: cache}
	admission, err := source.AdmitCockpit(context.Background(), view.Stamp)
	if err != nil {
		t.Fatal(err)
	}
	data, err := source.ReadCockpit(context.Background(), admission)
	if err != nil {
		t.Fatal(err)
	}
	b, _ := json.Marshal(data)
	if strings.Contains(string(b), `"history"`) {
		t.Fatal("client without cockpitHistoryV1 received history")
	}
}
