// SPDX-License-Identifier: MIT
package appserver

// Spec-data scenario R-01 (tier-1 producer half): "Granted source has a fresh 4%
// reading / Launch and source changes to 3% / App subscription shows the new 3%
// with its source observation time." The subscription must deliver the newer
// observation through rows/changed without any refresh request, carrying the new
// value and the new observation time (never the refresh request time).

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func r01Time(v time.Time) *time.Time { return &v }
func r01Int(v int64) *int64          { return &v }
func r01Float(v float64) *float64    { return &v }

func r01ScenarioInput(remaining float64, observedAt time.Time) rows.Input {
	now := observedAt.Add(time.Minute)
	return rows.Input{Now: now, ConsentGeneration: 1,
		Catalogue: []rows.CatalogueEntry{{ToolID: "claude", Detected: true, ReaderExists: true}},
		Consents:  []rows.ConsentRecord{{ToolID: "claude", Generation: 1, State: rows.ConsentAllowed}},
		Profiles: []rows.ProfileState{{ToolID: "claude", ProfileKey: "a", LatestAttempt: rows.AttemptResultSucceeded,
			AttemptedAt: r01Time(observedAt), ObservedAt: r01Time(observedAt), WithinFreshness: true, FreshUntil: r01Time(now.Add(time.Hour))}},
		Accounts: []rows.AccountInput{{ToolID: "claude", ProfileKey: "a", SubscriptionRef: ptrString("0123456789abcdef"),
			Windows: []rows.WindowInput{{Kind: "five_hour", DurationSeconds: r01Int(18000), RemainingPercent: r01Float(remaining),
				ResetMode: "fixed", ResetsAt: r01Time(now.Add(5 * time.Minute)), ObservedAt: r01Time(observedAt)}}}},
	}
}

func TestR01NewerObservationDeliveredThroughSubscription(t *testing.T) {
	backend := newMemoryBackend()
	observed4 := time.Now().Add(-time.Minute)
	backend.mu.Lock()
	backend.view.Projection = rows.Build(r01ScenarioInput(4, observed4))
	backend.mu.Unlock()
	c := startClient(t, Config{Backend: backend})
	c.readMessages()
	c.send(t, 1, "initialize", wire.InitializeParams{SessionID: "s-r01", ProtocolVersion: "1.7", AppVersion: "test", Capabilities: []string{"rows"}})
	if m := c.response(t, 1); m["error"] != nil {
		t.Fatal("initialize failed")
	}
	c.send(t, 2, "rows/subscribe", wire.Empty{})
	m := c.response(t, 2)
	var first wire.Envelope[wire.RowsSnapshot]
	if err := json.Unmarshal(m["result"], &first); err != nil {
		t.Fatal(err)
	}
	if len(first.Data.Projection.Rows) != 1 || len(first.Data.Projection.Rows[0].Accounts) != 1 {
		t.Fatalf("expected one subscribed claude account, got %+v", first.Data.Projection)
	}
	if got := first.Data.Projection.Rows[0].Accounts[0].Windows; len(got) != 1 || got[0].RemainingPercent == nil || *got[0].RemainingPercent != 4 {
		t.Fatalf("baseline fresh 4%% reading missing: %+v", got)
	}
	// The source observation changes to 3%; no refresh is requested or run.
	observed3 := time.Now()
	backend.mu.Lock()
	backend.view.Projection = rows.Build(r01ScenarioInput(3, observed3))
	backend.mu.Unlock()
	select {
	case backend.changed <- struct{}{}:
	default:
	}
	m = c.next(t, func(m map[string]json.RawMessage) bool { return string(m["method"]) == `"rows/changed"` })
	var changed wire.Envelope[wire.RowsSnapshot]
	if err := json.Unmarshal(m["params"], &changed); err != nil {
		t.Fatal(err)
	}
	if changed.Data.Sequence <= first.Data.Sequence {
		t.Fatal("delivered snapshot must advance the subscription sequence")
	}
	if len(changed.Data.Projection.Rows) != 1 || len(changed.Data.Projection.Rows[0].Accounts) != 1 {
		t.Fatalf("subscription lost the account: %+v", changed.Data.Projection)
	}
	account := changed.Data.Projection.Rows[0].Accounts[0]
	if len(account.Windows) != 1 || account.Windows[0].RemainingPercent == nil || *account.Windows[0].RemainingPercent != 3 {
		t.Fatalf("subscription must show the new 3%% reading, got %+v", account.Windows)
	}
	if account.ObservedAt == nil || !account.ObservedAt.Equal(observed3) {
		t.Fatalf("source · age must use the actual observation time, got %+v want %v", account.ObservedAt, observed3)
	}
	c.send(t, 3, "shutdown", wire.Empty{})
	if m := c.response(t, 3); m["error"] != nil {
		t.Fatal("shutdown failed")
	}
	select {
	case <-c.done:
	case <-time.After(time.Second):
		t.Fatal("shutdown did not exit")
	}
}
