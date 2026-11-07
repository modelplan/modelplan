// SPDX-License-Identifier: MIT
package appserver

import (
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"testing"
	"time"
)

func TestAccountTodayUsesOnlyUniqueCurrentSourceBinding(t *testing.T) {
	now := time.Date(2026, 11, 4, 12, 0, 0, 0, time.Local)
	ref, other := "0123456789abcdef", "fedcba9876543210"
	report := []quota.Account{{Source: "codex", Subscription: &quota.Binding{Ref: ref, Status: "verified", ObservedAt: now}}}
	p := rows.Projection{Rows: []rows.Row{{ID: "codex", Accounts: []rows.Account{{SubscriptionRef: &ref, ValueState: rows.ValueStateCurrent}}}}}
	perf := speed.PerfView{OK: true, Recording: true, Now: now, Ledger: speed.PerfLedger{Rows: []speed.PerfRow{{Day: now.Format("2006-01-02"), Source: "codex", ObservedRequests: 5, ObservedOutputTokens: 120, EligibleRequests: 5, EligibleOutputTokens: 100, GenMs: 2000}}}}
	attachAccountToday(&p, report, perf)
	got := p.Rows[0].Accounts[0].Today
	if got == nil || got.ObservedOutputTokens == nil || *got.ObservedOutputTokens != 120 || got.GenerationTps == nil || *got.GenerationTps != 50 || got.BindingBasis != "source-wide-current-binding" || got.RunningSessions != nil {
		t.Fatalf("today: %+v", got)
	}
	report = append(report, quota.Account{Source: "codex", Subscription: &quota.Binding{Ref: other, Status: "verified", ObservedAt: now}})
	p.Rows[0].Accounts[0].Today = nil
	attachAccountToday(&p, report, perf)
	if p.Rows[0].Accounts[0].Today != nil {
		t.Fatal("ambiguous source assigned to account")
	}
}

func TestAccountTodayRunningSessionsRequireBoundLiveEvidence(t *testing.T) {
	now := time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)
	ref := "0123456789abcdef"
	p := rows.Projection{Rows: []rows.Row{{ID: "codex", Accounts: []rows.Account{{SubscriptionRef: &ref, ValueState: rows.ValueStateCurrent}}}}}
	perf := speed.PerfView{OK: true, Recording: true, Now: now, Ledger: speed.PerfLedger{Live: []speed.LiveRecord{{Source: "codex", SubscriptionRef: ref, LastAt: now.Add(-time.Second), Running: true}}}}
	attachAccountToday(&p, nil, perf)
	got := p.Rows[0].Accounts[0].Today
	if got == nil || got.RunningSessions == nil || *got.RunningSessions != 1 || got.ObservedOutputTokens != nil || got.BindingBasis != "session-binding" {
		t.Fatalf("bound running session: %+v", got)
	}
	perf.Ledger.Live = append(perf.Ledger.Live, speed.LiveRecord{Source: "codex", LastAt: now.Add(-time.Second), Running: true})
	p.Rows[0].Accounts[0].Today = nil
	attachAccountToday(&p, nil, perf)
	if p.Rows[0].Accounts[0].Today != nil {
		t.Fatal("unbound running session was counted as known")
	}
	perf.Recording = false
	p.Rows[0].Accounts[0].Today = nil
	attachAccountToday(&p, nil, perf)
	if p.Rows[0].Accounts[0].Today != nil {
		t.Fatal("recording-off data leaked")
	}
}
