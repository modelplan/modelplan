// SPDX-License-Identifier: MIT
package appserver

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

func TestCockpitTodayTotalsRequiresUniqueCurrentBinding(t *testing.T) {
	now := time.Date(2026, 11, 1, 12, 0, 0, 0, time.Local)
	account := quota.Account{Source: "codex", Subscription: &quota.Binding{Ref: "0123456789abcdef", Status: "verified", ObservedAt: now}}
	view := speed.PerfView{OK: true, Recording: true, Now: now, Ledger: speed.PerfLedger{Rows: []speed.PerfRow{{Day: now.Format("2006-01-02"), Source: "codex", ObservedOutputTokens: 120, EligibleRequests: 5, EligibleOutputTokens: 100, GenMs: 2000}}}}
	got := CockpitTodayTotals([]quota.Account{account}, view)
	if len(got) != 1 || got[0].OutputTokens != 120 || got[0].GenerationTPS == nil || *got[0].GenerationTPS != 50 || got[0].BindingBasis != "source-wide-current-binding" {
		t.Fatalf("known totals: %#v", got)
	}
	other := account
	other.Subscription = &quota.Binding{Ref: "fedcba9876543210", Status: "verified", ObservedAt: now}
	if got := CockpitTodayTotals([]quota.Account{account, other}, view); len(got) != 0 {
		t.Fatalf("ambiguous source attributed: %#v", got)
	}
	other.Subscription = nil
	if got := CockpitTodayTotals([]quota.Account{account, other}, view); len(got) != 0 {
		t.Fatalf("unverified account attributed: %#v", got)
	}
	other = account
	other.Stale = true
	if got := CockpitTodayTotals([]quota.Account{other}, view); len(got) != 0 {
		t.Fatalf("stale account attributed: %#v", got)
	}
	view.Ledger.Rows[0].EligibleRequests = 4
	got = CockpitTodayTotals([]quota.Account{account}, view)
	if len(got) != 1 || got[0].GenerationTPS != nil {
		t.Fatalf("insufficient samples: %#v", got)
	}
	view.Recording = false
	if got := CockpitTodayTotals([]quota.Account{account}, view); len(got) != 0 {
		t.Fatalf("recording off: %#v", got)
	}
	view.Recording = true
	view.Ledger.Rows = nil
	if got := CockpitTodayTotals([]quota.Account{account}, view); len(got) != 0 {
		t.Fatalf("empty ledger: %#v", got)
	}
}
