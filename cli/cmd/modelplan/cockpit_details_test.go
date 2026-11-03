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
	"github.com/modelplan/modelplan/cli/internal/digest"
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
	facts := &rows.ResetCards{State: rows.ResetCardComplete, Count: &zero, Sources: []rows.ResetCardSource{{Source: rows.ResetCardCodexAccount, ObservedAt: now}}}
	view.Projection.Rows[0].Accounts[0].ResetCards = facts
	data, err := (sharedCockpit{}).cockpitDetails(context.Background(), view, queries.CockpitAdmission{Stamp: stamp}, map[string][]wire.CockpitAccount{ref: {}})
	if err != nil {
		t.Fatal(err)
	}
	if len(data.Subscriptions) != 1 || data.Subscriptions[0].ResetCards != facts {
		t.Fatal("row reset facts were not delivered with cockpit details")
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
	// Legacy grouped cards can exceed the wire bound; the new facts and legacy
	// indicator must both expose truncation rather than silently implying zero.
	for i := 0; i < 65; i++ {
		view.QuotaReport.Accounts[0].Cards = append(view.QuotaReport.Accounts[0].Cards, quota.Card{Kind: "full", Count: &zero})
	}
	capped, err := (sharedCockpit{}).cockpitDetails(context.Background(), view, queries.CockpitAdmission{Stamp: stamp}, map[string][]wire.CockpitAccount{ref: {}})
	if err != nil || len(capped.Subscriptions) != 1 || len(capped.Subscriptions[0].ResetCounts) != 64 || !capped.Subscriptions[0].ResetCountsTruncated || capped.Subscriptions[0].ResetCards == nil || capped.Subscriptions[0].ResetCards.State != rows.ResetCardPartial || !capped.Subscriptions[0].ResetCards.Truncated {
		t.Fatalf("truncation not reported: %+v, %v", capped, err)
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
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	a := consent.Capture()
	stamp := appserver.Stamp{Epoch: a.Fence().StoreEpoch, Generation: a.Fence().Generation}
	cache := t.TempDir()
	admission := queries.CockpitAdmission{Stamp: stamp, Scopes: []string{consent.ScopeCodexLocalHistory}}
	source := sharedCockpit{cache: cache}
	missing, err := source.cockpitDetails(context.Background(), appserver.View{}, admission, nil)
	if err != nil || missing.SessionCoverage != "unavailable" || slices.Contains(missing.Sources, "local-history") {
		t.Fatalf("missing ledger: %#v, %v", missing, err)
	}
	if err := os.MkdirAll(filepath.Dir(speed.PerfPath(cache)), 0700); err != nil {
		t.Fatal(err)
	}
	payload, err := json.Marshal(speed.PerfLedger{SchemaVersion: 1, Since: time.Now().UTC(), Rows: []speed.PerfRow{}})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(speed.PerfPath(cache), payload, 0600); err != nil {
		t.Fatal(err)
	}
	empty, err := source.cockpitDetails(context.Background(), appserver.View{}, admission, nil)
	if err != nil || empty.SessionCoverage != "local-last-seen" || !slices.Contains(empty.Sources, "local-history") || len(empty.Sessions) != 0 {
		t.Fatalf("empty ledger: %#v, %v", empty, err)
	}
}

func TestCockpitDetailsProjectsOnlyAdmittedStampedLiveSessions(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_HISTORY", "")
	state, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	epoch := &speed.GrantEpoch{StoreEpoch: state.StoreEpoch, RevokedGeneration: 0}
	cache := t.TempDir()
	ledger := speed.PerfLedger{SchemaVersion: 1, Since: now.Add(-time.Hour), Rows: []speed.PerfRow{}, Live: []speed.LiveRecord{
		{Ref: "1111111111111111", Source: "codex", Model: "synthetic-alias", Effort: "high", ProjectRef: "p1", LastAt: now.Add(-time.Second), GrantEpoch: epoch, Running: true},
		{Ref: "2222222222222222", Source: "codex", Model: "unknown-secret", Effort: "unknown-secret", LastAt: now.Add(-2 * time.Second), GrantEpoch: epoch},
		{Ref: "3333333333333333", Source: "claude-code", Model: "synthetic-alias", LastAt: now.Add(-time.Second), GrantEpoch: epoch},
		{Ref: "4444444444444444", Source: "codex", Model: "synthetic-alias", LastAt: now.Add(-time.Second)},
	}, Sessions: []speed.PerfSession{{Ref: "1111111111111111", Source: "codex", ProjectRef: "p1", ProjectLabel: "Synthetic project", GrantEpoch: epoch}}}
	if err := os.MkdirAll(filepath.Dir(speed.PerfPath(cache)), 0700); err != nil {
		t.Fatal(err)
	}
	payload, err := json.Marshal(ledger)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(speed.PerfPath(cache), payload, 0600); err != nil {
		t.Fatal(err)
	}
	stamp := appserver.Stamp{Epoch: state.StoreEpoch, Generation: state.Generation}
	view := appserver.View{PublicModels: []digest.Model{{ID: "public-model", HarnessIDs: map[string][]string{"codex": {"synthetic-alias"}}}}}
	admission := queries.CockpitAdmission{Stamp: stamp, Scopes: []string{consent.ScopeCodexLocalHistory}}
	got, err := (sharedCockpit{cache: cache}).cockpitDetails(context.Background(), view, admission, nil)
	if err != nil || len(got.Sessions) != 2 {
		t.Fatalf("scope or epoch filter: %#v, %v", got.Sessions, err)
	}
	if got.Sessions[0].SessionRef != "1111111111111111" || got.Sessions[0].Model != "public-model" || got.Sessions[0].Effort == nil || *got.Sessions[0].Effort != "high" || got.Sessions[0].ProjectLabel == nil || *got.Sessions[0].ProjectLabel != "Synthetic project" || got.Sessions[0].SubscriptionRef != nil {
		t.Fatalf("verified live projection: %#v", got.Sessions[0])
	}
	if got.Sessions[1].Model != "unknown" || got.Sessions[1].Effort != nil || got.Sessions[1].ProjectLabel != nil {
		t.Fatalf("untrusted fields escaped: %#v", got.Sessions[1])
	}
	labelFile := speed.ProjectLabelsFile(home)
	if err := os.MkdirAll(filepath.Dir(labelFile), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(labelFile, []byte(`{"projectLabels":false}`), 0600); err != nil {
		t.Fatal(err)
	}
	got, err = (sharedCockpit{cache: cache}).cockpitDetails(context.Background(), view, admission, nil)
	if err != nil || len(got.Sessions) != 2 || got.Sessions[0].ProjectLabel != nil {
		t.Fatalf("disabled labels escaped: %#v, %v", got.Sessions, err)
	}
}

func TestCockpitDetailsWithholdsCorruptCachedSessionRate(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_HISTORY", "")
	state, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	cache := t.TempDir()
	samples := []map[string]any{}
	for i := 0; i < 5; i++ {
		samples = append(samples, map[string]any{"at": now.Add(-time.Second), "out": -10, "genMs": 100, "eligible": true})
	}
	fixture := map[string]any{"schemaVersion": 1, "since": now.Add(-time.Hour), "rows": []any{}, "live": []any{map[string]any{
		"ref": "0123456789abcdef", "source": "codex", "model": "synthetic", "lastAt": now.Add(-time.Second),
		"startedAt": now.Add(-time.Minute), "grantEpoch": speed.GrantEpoch{StoreEpoch: state.StoreEpoch}, "samples": samples,
	}}}
	if err := os.MkdirAll(filepath.Dir(speed.PerfPath(cache)), 0700); err != nil {
		t.Fatal(err)
	}
	payload, err := json.Marshal(fixture)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(speed.PerfPath(cache), payload, 0600); err != nil {
		t.Fatal(err)
	}
	stamp := appserver.Stamp{Epoch: state.StoreEpoch, Generation: state.Generation}
	admission := queries.CockpitAdmission{Stamp: stamp, Scopes: []string{consent.ScopeCodexLocalHistory}}
	got, err := (sharedCockpit{cache: cache}).cockpitDetails(context.Background(), appserver.View{}, admission, nil)
	if err != nil || len(got.Sessions) != 1 || got.Sessions[0].Rate != nil {
		t.Fatalf("corrupt rate escaped: %#v, %v", got.Sessions, err)
	}
}
