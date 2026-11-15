package snapshot

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

func ptr[T any](v T) *T { return &v }

var perfHistoryNow = time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC)

func perfHistoryRows(epoch string) []speed.PerfRow {
	return []speed.PerfRow{
		{GrantEpoch: &speed.GrantEpoch{StoreEpoch: epoch}, Day: "2026-11-04", Source: "codex", Model: "gpt-5.3",
			TokenKinds:         speed.TokenKinds{InputTokens: ptr(int64(1000)), CacheReadTokens: ptr(int64(4000)), CacheWriteTokens: ptr(int64(500))},
			ObservedRequests:   10, ObservedOutputTokens: 2000, EligibleRequests: 6, EligibleOutputTokens: 1200, GenMs: 20000},
		{GrantEpoch: &speed.GrantEpoch{StoreEpoch: epoch}, Day: "2026-10-20", Source: "codex", Model: "gpt-5.3",
			TokenKinds:         speed.TokenKinds{InputTokens: ptr(int64(500)), CacheReadTokens: ptr(int64(500))},
			ObservedRequests:   5, ObservedOutputTokens: 1000, EligibleRequests: 5, EligibleOutputTokens: 1000, GenMs: 25000},
		{GrantEpoch: &speed.GrantEpoch{StoreEpoch: epoch}, Day: "2026-11-05", Source: "claude-code", Model: "sonnet",
			TokenKinds:         speed.TokenKinds{InputTokens: ptr(int64(200))},
			ObservedRequests:   4, ObservedOutputTokens: 500, EligibleRequests: 4, EligibleOutputTokens: 400, GenMs: 8000},
		{GrantEpoch: &speed.GrantEpoch{StoreEpoch: epoch}, Day: "2026-11-03", Source: "claude-code", Model: "opus",
			TokenKinds:         speed.TokenKinds{InputTokens: ptr(int64(100)), CacheReadTokens: ptr(int64(900)), CacheWriteTokens: ptr(int64(100))},
			ObservedRequests:   3, ObservedOutputTokens: 300, EligibleRequests: 2, EligibleOutputTokens: 200, GenMs: 10000},
	}
}

func perfHistoryView(rows []speed.PerfRow) *speed.PerfView {
	v := speed.PerfView{Ledger: speed.PerfLedger{Since: time.Date(2026, 10, 6, 0, 0, 0, 0, time.UTC), Rows: rows}, OK: true, Recording: true, Now: perfHistoryNow}
	return &v
}

func TestSourceBindingsNeedOneFreshVerifiedAccount(t *testing.T) {
	old := time.Local
	time.Local = time.UTC
	t.Cleanup(func() { time.Local = old })
	ref := "0123456789abcdef"
	bound := quota.Account{Source: "codex", Subscription: &quota.Binding{Ref: ref, Status: "verified", ObservedAt: perfHistoryNow.Add(-30 * time.Minute)}}
	if got := SourceBindings([]quota.Account{bound}, perfHistoryNow); got["codex"] != ref {
		t.Fatalf("unambiguous binding lost: %v", got)
	}
	cases := map[string][]quota.Account{
		"two verified accounts": {bound, {Source: "codex", Subscription: &quota.Binding{Ref: "fedcba9876543210", Status: "verified", ObservedAt: perfHistoryNow.Add(-time.Minute)}}},
		"unverified account":    {bound, {Source: "codex"}},
		"stale account":         {{Source: "codex", Stale: true, Subscription: &quota.Binding{Ref: ref, Status: "verified", ObservedAt: perfHistoryNow.Add(-time.Minute)}}},
		"short observation":     {{Source: "codex", Subscription: &quota.Binding{Ref: ref, Status: "verified", ObservedAt: perfHistoryNow.Add(-2 * time.Hour)}}},
		"future observation":    {{Source: "codex", Subscription: &quota.Binding{Ref: ref, Status: "verified", ObservedAt: perfHistoryNow.Add(time.Minute)}}},
		"bad reference":         {{Source: "codex", Subscription: &quota.Binding{Ref: "not-a-ref", Status: "verified", ObservedAt: perfHistoryNow}}},
	}
	for name, accounts := range cases {
		if got := SourceBindings(accounts, perfHistoryNow); len(got) != 0 {
			t.Fatalf("%s was attributed: %v", name, got)
		}
	}
}

func TestBuildPerfHistoryBindsAndDerives(t *testing.T) {
	old := time.Local
	time.Local = time.UTC
	t.Cleanup(func() { time.Local = old })
	refA, refB := "0123456789abcdef", "fedcba9876543210"
	accounts := []quota.Account{
		{Source: "codex", Subscription: &quota.Binding{Ref: refA, Status: "verified", ObservedAt: perfHistoryNow.Add(-30 * time.Minute)}},
		{Source: "claude-code", Subscription: &quota.Binding{Ref: refB, Status: "verified", ObservedAt: perfHistoryNow.Add(-30 * time.Minute)}},
	}
	h := BuildPerfHistory(perfHistoryView(perfHistoryRows("epoch")), accounts, map[string]bool{"codex": true, "claude-code": true}, perfHistoryNow)
	if h.Coverage != "local-history" || h.RecordingSince == nil || !h.RecordingSince.Equal(time.Date(2026, 10, 6, 0, 0, 0, 0, time.UTC)) {
		t.Fatalf("coverage: %+v", h)
	}
	if len(h.Subscriptions) != 2 || h.Subscriptions[0].SubscriptionRef != refA || h.Subscriptions[1].SubscriptionRef != refB {
		t.Fatalf("subscriptions: %+v", h.Subscriptions)
	}
	codex := h.Subscriptions[0].Sources
	if len(codex) != 1 || codex[0].Source != "codex" || codex[0].BindingBasis != BindingSourceWideCurrent {
		t.Fatalf("codex binding: %+v", codex)
	}
	w7, w30 := codex[0].Recent7d, codex[0].Recent30d
	if *w7.InputTokens != 1000 || *w7.CacheReadTokens != 4000 || *w7.CacheWriteTokens != 500 || w7.OutputTokens != 2000 || w7.ObservedRequests != 10 || w7.EligibleRequests != 6 {
		t.Fatalf("codex 7d sums: %+v", w7)
	}
	if w7.CacheHitRatio == nil || *w7.CacheHitRatio != 0.8 || w7.GenerationTps == nil || *w7.GenerationTps != 60 {
		t.Fatalf("codex 7d derived: %+v", w7)
	}
	if *w30.InputTokens != 1500 || *w30.CacheReadTokens != 4500 || w30.CacheWriteTokens != nil || w30.OutputTokens != 3000 || w30.ObservedRequests != 15 {
		t.Fatalf("codex 30d sums: %+v", w30)
	}
	if w30.CacheHitRatio == nil || *w30.CacheHitRatio != 0.75 || w30.GenerationTps == nil || *w30.GenerationTps != 48.9 {
		t.Fatalf("codex 30d derived: %+v", w30)
	}
	// Unknown stays unknown in JSON: claude-code's cache sums never become zero.
	b, err := json.Marshal(h.Subscriptions[1].Sources[0].Recent7d)
	if err != nil {
		t.Fatal(err)
	}
	if want := `{"inputTokens":300,"outputTokens":800,"cacheReadTokens":null,"cacheWriteTokens":null,"cacheHitRatio":null,"generationTps":33.3,"observedRequests":7,"eligibleRequests":6}`; string(b) != want {
		t.Fatalf("claude-code 7d JSON = %s", b)
	}
	if h.Models.Recent7d.Entities != 3 || h.Tools.Recent7d.Entities != 2 || h.Tools.Recent7d.Top[0].Name != "codex" {
		t.Fatalf("rankings: %+v", h.Tools.Recent7d)
	}
}

func TestBuildPerfHistoryCoversOffUnreadableAndUnallowed(t *testing.T) {
	old := time.Local
	time.Local = time.UTC
	t.Cleanup(func() { time.Local = old })
	ref := "0123456789abcdef"
	accounts := []quota.Account{{Source: "codex", Subscription: &quota.Binding{Ref: ref, Status: "verified", ObservedAt: perfHistoryNow}}}
	rows := perfHistoryRows("epoch")
	cases := []struct {
		name    string
		perf    *speed.PerfView
		allowed map[string]bool
		cover   string
	}{
		{"nil view", nil, map[string]bool{"codex": true}, "unavailable"},
		{"unreadable ledger", func() *speed.PerfView { v := perfHistoryView(rows); v.OK = false; return v }(), map[string]bool{"codex": true}, "unavailable"},
		{"recording off", func() *speed.PerfView { v := perfHistoryView(rows); v.Recording = false; return v }(), map[string]bool{"codex": true}, "recording-off"},
		{"no allowed source", perfHistoryView(rows), map[string]bool{}, "unavailable"},
	}
	for _, c := range cases {
		h := BuildPerfHistory(c.perf, accounts, c.allowed, perfHistoryNow)
		if h.Coverage != c.cover || len(h.Subscriptions) != 0 || h.Models.Recent7d.Entities != 0 || h.Tools.Recent7d.Entities != 0 {
			t.Fatalf("%s: %+v", c.name, h)
		}
		if h.Models.Recent7d.Top == nil || h.Tools.Recent7d.Top == nil || h.Subscriptions == nil {
			t.Fatalf("%s: lists must be empty, not nil", c.name)
		}
	}
	// An allowed source without a binding keeps its figures out of every subscription; the
	// rankings still show the unattributed observation.
	h := BuildPerfHistory(perfHistoryView(rows), nil, map[string]bool{"codex": true}, perfHistoryNow)
	if len(h.Subscriptions) != 0 || h.Tools.Recent7d.Top[0].Name != "codex" || h.Tools.Recent7d.Top[0].ObservedOutputTokens != 2000 || h.Tools.Recent30d.Top[0].ObservedOutputTokens != 3000 {
		t.Fatalf("unbound source: %+v", h.Tools)
	}
}
