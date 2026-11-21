// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/queries"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

type cockpitViewBackend struct {
	appserver.UnavailableBackend
	view appserver.View
}

func (b cockpitViewBackend) Get(ctx context.Context) (appserver.View, error) {
	return b.view, ctx.Err()
}
func TestSharedCockpitGroupsVerifiedBindingsWithoutChangingRows(t *testing.T) {
	ref := "0123456789abcdef"
	a := rows.Account{SubscriptionRef: &ref, Plan: rows.Plan{ID: "known"}}
	unbound := rows.Account{Plan: rows.Plan{ID: "known"}}
	view := appserver.View{Stamp: appserver.Stamp{Epoch: "synthetic", Generation: 9}, Scopes: []string{"codex.runtime_usage", "claude.account_usage.saved_login"}, Projection: rows.Projection{RowsVersion: rows.Version, Rows: []rows.Row{{ID: "claude", Accounts: []rows.Account{a, unbound}}, {ID: "codex", Accounts: []rows.Account{a}}}}}
	before, _ := json.Marshal(view.Projection)
	source := sharedCockpit{backend: cockpitViewBackend{view: view}}
	admission, err := source.AdmitCockpit(context.Background(), view.Stamp)
	if err != nil {
		t.Fatal(err)
	}
	display, err := source.ReadCockpit(context.Background(), admission)
	if err != nil {
		t.Fatal(err)
	}
	if b, _ := json.Marshal(display); strings.Contains(string(b), `"details"`) {
		t.Fatal("old client received details")
	}
	if len(display.Subscriptions) != 1 || display.Subscriptions[0].SubscriptionRef != ref || len(display.Subscriptions[0].Accounts) != 2 {
		t.Fatal("Go subscription grouping missing or unverified plan inferred")
	}
	if display.Subscriptions[0].Accounts[0].Tool != "claude" || display.Subscriptions[0].Accounts[1].Tool != "codex" {
		t.Fatal("stable tool IDs lost")
	}
	after, _ := json.Marshal(view.Projection)
	if string(before) != string(after) {
		t.Fatal("cockpit changed backend rows")
	}
	admission.Stamp.Generation--
	if _, err := source.ReadCockpit(context.Background(), admission); err == nil {
		t.Fatal("stale cockpit source admission accepted")
	}
}

// countingCockpitBackend counts the views built and answers the current consent fence on its own.
type countingCockpitBackend struct {
	cockpitViewBackend
	gets    *int
	current *appserver.Stamp
}

func (b countingCockpitBackend) Get(ctx context.Context) (appserver.View, error) {
	*b.gets++
	return b.view, ctx.Err()
}
func (b countingCockpitBackend) CurrentStamp(ctx context.Context) (appserver.Stamp, error) {
	return *b.current, ctx.Err()
}

// WP-17 (Fable perf plan 5.1 row 1): a cockpit query builds one engine view, not three or four.
// The admission, the read and the late-revocation check all use it; the check after the read
// asks the consent fence alone, so a revocation during the read still refuses the reply.
func TestCockpitQueryBuildsOneViewAndStillRefusesALateRevocation(t *testing.T) {
	ref := "0123456789abcdef"
	stamp := appserver.Stamp{Epoch: "synthetic", Generation: 9}
	view := appserver.View{Stamp: stamp, Scopes: []string{"codex.runtime_usage"}, Projection: rows.Projection{RowsVersion: rows.Version, Rows: []rows.Row{{ID: "codex", Accounts: []rows.Account{{SubscriptionRef: &ref}}}}}}
	gets, current := 0, stamp
	backend := countingCockpitBackend{cockpitViewBackend: cockpitViewBackend{view: view}, gets: &gets, current: &current}
	handler, err := queries.CockpitHandler(queries.CockpitConfig{State: backend, Source: sharedCockpit{backend: backend}})
	if err != nil {
		t.Fatal(err)
	}
	reply, err := handler.Handle(context.Background(), json.RawMessage(`{}`), stamp)
	if err != nil || reply.Stamp != stamp || len(reply.Scopes) != 1 {
		t.Fatalf("cockpit query: %+v %v", reply, err)
	}
	if gets != 1 {
		t.Fatalf("a cockpit query built %d views, want 1", gets)
	}
	gets = 0
	current = appserver.Stamp{Epoch: "synthetic", Generation: 10} // revoked while the cockpit read
	if _, err := handler.Handle(context.Background(), json.RawMessage(`{}`), stamp); err == nil {
		t.Fatal("a reply read before a revocation was returned after it")
	} else if code, ok := err.(appserver.ProtocolError); !ok || code.Code != wire.CodeConsentChanged {
		t.Fatalf("late revocation: %v", err)
	}
}
