// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver"
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
