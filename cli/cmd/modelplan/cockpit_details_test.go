// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/queries"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func TestCockpitDetailsReserveThresholdAndFence(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_HISTORY", "off")
	if _, err := consent.EnsureStore(consent.Path()); err != nil { t.Fatal(err) }
	a := consent.Capture()
	stamp := appserver.Stamp{Epoch:a.Fence().StoreEpoch, Generation:a.Fence().Generation}
	now := time.Now().UTC()
	ref := "0123456789abcdef"
	zero, remaining, balance := 0, 25.0, 0.0
	until := now.Add(time.Hour)
	view := appserver.View{QuotaReport: quota.Report{Accounts: []quota.Account{{Source:"codex", Subscription:&quota.Binding{Ref:ref, Status:"verified"}, Cards:[]quota.Card{{Kind:"full", Count:&zero}}, Credits:&quota.Credits{Balance:&balance, ObservedAt:now}}}}, Projection: rows.Projection{Rows: []rows.Row{{ID:"codex", Accounts: []rows.Account{{SubscriptionRef:&ref, ValueState:rows.ValueStateCurrent, Windows: []rows.Window{{ID:"weekly", Current:true, ValidUntil:&until, RemainingPercent:&remaining}}}}}}}}
	data, err := (sharedCockpit{}).cockpitDetails(context.Background(), view, queries.CockpitAdmission{Stamp:stamp}, map[string][]wire.CockpitAccount{ref:{}})
	if err != nil { t.Fatal(err) }
	if len(data.Subscriptions) != 1 || len(data.Subscriptions[0].ResetCounts) != 1 || data.Subscriptions[0].ResetCounts[0].Count == nil || *data.Subscriptions[0].ResetCounts[0].Count != 0 || data.Subscriptions[0].Credits == nil || *data.Subscriptions[0].Credits.Balance != 0 { t.Fatalf("known zero lost: %#v", data) }
	if len(data.Alerts) != 1 || data.Alerts[0].Severity != "critical" || data.SessionCoverage != "recording-off" { t.Fatalf("wrong facts: %#v", data) }
	stamp.Generation++
	if _, err := (sharedCockpit{}).cockpitDetails(context.Background(), view, queries.CockpitAdmission{Stamp:stamp}, nil); err == nil { t.Fatal("stale fence accepted") }
}

func TestCockpitLabelRejectsPathsAndControlCharacters(t *testing.T) {
	for _, s := range []string{"secret/path", "secret\\path", "line\nbreak", ""} { if safeCockpitLabel(s) { t.Fatalf("unsafe label %q", s) } }
	if !safeCockpitLabel("Synthetic project") { t.Fatal("safe label rejected") }
}
