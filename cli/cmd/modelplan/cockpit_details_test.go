// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/queries"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

func TestCockpitDetailsReserveThresholdAndFence(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_HISTORY", "off")
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	a := consent.Capture()
	stamp := appserver.Stamp{Epoch: a.Fence().StoreEpoch, Generation: a.Fence().Generation}
	now := time.Now().UTC()
	ref := "0123456789abcdef"
	zero, remaining, balance := 0, 25.0, 0.0
	until := now.Add(time.Hour)
	expired := now.Add(-time.Hour)
	view := appserver.View{QuotaReport: quota.Report{Accounts: []quota.Account{{Source: "codex", Subscription: &quota.Binding{Ref: ref, Status: "verified"}, Cards: []quota.Card{{Kind: "full", Count: &zero}, {Kind: "full", Count: &zero, ExpiresAt: &expired}}, Credits: &quota.Credits{Balance: &balance, ObservedAt: now}}}}, Projection: rows.Projection{Rows: []rows.Row{{ID: "codex", Accounts: []rows.Account{{SubscriptionRef: &ref, ValueState: rows.ValueStateCurrent, Windows: []rows.Window{{ID: "weekly", Current: true, ValidUntil: &until, RemainingPercent: &remaining}}}}}}}}
	data, err := (sharedCockpit{}).cockpitDetails(context.Background(), view, queries.CockpitAdmission{Stamp: stamp}, map[string][]wire.CockpitAccount{ref: {}})
	if err != nil {
		t.Fatal(err)
	}
	if len(data.Subscriptions) != 1 || len(data.Subscriptions[0].ResetCounts) != 1 || data.Subscriptions[0].ResetCounts[0].Count == nil || *data.Subscriptions[0].ResetCounts[0].Count != 0 || data.Subscriptions[0].Credits == nil || *data.Subscriptions[0].Credits.Balance != 0 {
		t.Fatalf("known zero lost: %#v", data)
	}
	if len(data.Alerts) != 1 || data.Alerts[0].Severity != "critical" || data.SessionCoverage != "recording-off" {
		t.Fatalf("wrong facts: %#v", data)
	}
	data, err = (sharedCockpit{}).cockpitDetails(context.Background(), view, queries.CockpitAdmission{Stamp: stamp, RedBelow: 10}, map[string][]wire.CockpitAccount{ref: {}})
	if err != nil || len(data.Alerts) != 1 || data.Alerts[0].Severity != "warning" {
		t.Fatalf("committed red threshold not used: %#v, %v", data.Alerts, err)
	}
	if slices.Contains(data.Sources, "reset-events") {
		t.Fatal("unavailable publication reported as an empty available source")
	}
	emptyEvents := []rows.ResetEvent{}
	view.ResetEvents = &emptyEvents
	data, err = (sharedCockpit{}).cockpitDetails(context.Background(), view, queries.CockpitAdmission{Stamp: stamp}, map[string][]wire.CockpitAccount{ref: {}})
	if err != nil || !slices.Contains(data.Sources, "reset-events") || len(data.ResetEvents) != 0 {
		t.Fatalf("empty verified reset source lost: %#v, %v", data, err)
	}
	stamp.Generation++
	if _, err := (sharedCockpit{}).cockpitDetails(context.Background(), view, queries.CockpitAdmission{Stamp: stamp}, nil); err == nil {
		t.Fatal("stale fence accepted")
	}
}

func TestCockpitLabelRejectsPathsAndControlCharacters(t *testing.T) {
	for _, s := range []string{"secret/path", "secret\\path", "line\nbreak", ""} {
		if safeCockpitLabel(s) {
			t.Fatalf("unsafe label %q", s)
		}
	}
	if !safeCockpitLabel("Synthetic project") {
		t.Fatal("safe label rejected")
	}
}

func TestCockpitCoverageDistinguishesMissingAndEmptyLedger(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_HISTORY", "")
	if _, err := consent.EnsureStore(consent.Path()); err != nil { t.Fatal(err) }
	a := consent.Capture()
	stamp := appserver.Stamp{Epoch: a.Fence().StoreEpoch, Generation: a.Fence().Generation}
	cache := t.TempDir()
	admission := queries.CockpitAdmission{Stamp: stamp, Scopes: []string{consent.ScopeCodexLocalHistory}}
	source := sharedCockpit{cache: cache}
	missing, err := source.cockpitDetails(context.Background(), appserver.View{}, admission, nil)
	if err != nil || missing.SessionCoverage != "unavailable" || slices.Contains(missing.Sources, "local-history") { t.Fatalf("missing ledger: %#v, %v", missing, err) }
	if err := os.MkdirAll(filepath.Dir(speed.PerfPath(cache)), 0700); err != nil { t.Fatal(err) }
	payload, err := json.Marshal(speed.PerfLedger{SchemaVersion: 1, Since: time.Now().UTC(), Rows: []speed.PerfRow{}})
	if err != nil { t.Fatal(err) }
	if err := os.WriteFile(speed.PerfPath(cache), payload, 0600); err != nil { t.Fatal(err) }
	empty, err := source.cockpitDetails(context.Background(), appserver.View{}, admission, nil)
	if err != nil || empty.SessionCoverage != "local-last-seen" || !slices.Contains(empty.Sources, "local-history") || len(empty.Sessions) != 0 { t.Fatalf("empty ledger: %#v, %v", empty, err) }
}
