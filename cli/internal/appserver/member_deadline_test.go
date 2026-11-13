// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func TestMixedRoutesDeadlineRequiresMatchingLiveGrant(t *testing.T) {
	backend, paths, _, member := memberFixture(t)
	admission := consent.Capture()
	ref := member.SubscriptionRef
	localRef := "fedcba9876543210"
	projection := rows.Projection{Rows: []rows.Row{{ID: "codex", State: rows.StateFresh, Accounts: []rows.Account{
		{Route: rows.RouteRuntimeRPC, SubscriptionRef: &ref},
		{Route: rows.RouteLocalLog, SubscriptionRef: &localRef},
	}}}}
	shared := &SharedBackend{}
	shared.populateRefreshDeadlines(&projection, paths(admission), admission, []string{consent.ScopeCodexRuntimeUsage}, time.Now())
	live, local := projection.Rows[0].Accounts[0], projection.Rows[0].Accounts[1]
	if live.RefreshNotBefore == nil || *live.RefreshNotBefore == nil || local.RefreshNotBefore != nil {
		t.Fatalf("incorrect route eligibility: live=%+v local=%+v", live.RefreshNotBefore, local.RefreshNotBefore)
	}
	projected := wire.ProjectWithEvents(projection, nil, false, false, true)
	encoded, err := json.Marshal(projected.Rows[0].Accounts[1])
	if err != nil {
		t.Fatal(err)
	}
	var object map[string]json.RawMessage
	if err := json.Unmarshal(encoded, &object); err != nil {
		t.Fatal(err)
	}
	if _, ok := object["refreshNotBefore"]; ok {
		t.Fatalf("ungranted route serialized deadline: %s", encoded)
	}
	old := wire.Project(projection)
	if old.Rows[0].Accounts[0].RefreshNotBefore != nil || old.Rows[0].Accounts[1].RefreshNotBefore != nil {
		t.Fatal("legacy client received deadline")
	}
	backend.view.Projection = projection
	scheduler := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths})
	defer scheduler.Close()
	result, _, err := scheduler.RequestMember(context.Background(), wire.RefreshMember{RowID: "codex", Route: rows.RouteLocalLog, SubscriptionRef: localRef})
	if err != nil || result.Reason == nil || *result.Reason != wire.MemberRefreshNotGranted {
		t.Fatalf("local member accepted: %+v %v", result, err)
	}
	projection.Rows[0].Accounts[0].SubscriptionRef = nil
	projection.Rows[0].Accounts[1].SubscriptionRef = nil
	shared.populateRefreshDeadlines(&projection, paths(admission), admission, []string{consent.ScopeCodexRuntimeUsage}, time.Now())
	if value := projection.Rows[0].Accounts[0].RefreshNotBefore; value == nil || *value != nil {
		t.Fatal("unknown granted binding must serialize null")
	}
	if projection.Rows[0].Accounts[1].RefreshNotBefore != nil {
		t.Fatal("unknown ungranted binding must stay omitted")
	}
	projected = wire.ProjectWithEvents(projection, nil, false, false, true)
	encoded, err = json.Marshal(projected.Rows[0].Accounts[0])
	if err != nil {
		t.Fatal(err)
	}
	object = nil
	if err := json.Unmarshal(encoded, &object); err != nil || string(object["refreshNotBefore"]) != "null" {
		t.Fatalf("unknown granted binding must serialize null: %s %v", encoded, err)
	}
}

func TestRefreshDeadlinePresentForFreshRowAndMember(t *testing.T) {
	_, paths, cache, member := memberFixture(t)
	admission := consent.Capture()
	ref := member.SubscriptionRef
	projection := rows.Projection{Rows: []rows.Row{{ID: "codex", State: rows.StateFresh, Accounts: []rows.Account{{Route: rows.RouteRuntimeRPC, SubscriptionRef: &ref}}}}}
	backend := &SharedBackend{}
	backend.populateRefreshDeadlines(&projection, paths(admission), admission, []string{consent.ScopeCodexRuntimeUsage}, time.Now())
	row, account := projection.Rows[0], projection.Rows[0].Accounts[0]
	if row.NextStep != nil || row.RefreshNotBefore == nil || *row.RefreshNotBefore == nil || account.RefreshNotBefore == nil || *account.RefreshNotBefore == nil {
		t.Fatalf("fresh deadline missing: %+v %+v", row, account)
	}
	if !(**row.RefreshNotBefore).Equal(alreadyDue) {
		t.Fatal("due timestamp was not stable")
	}
	old := wire.Project(projection)
	if old.Rows[0].RefreshNotBefore != nil || old.Rows[0].Accounts[0].RefreshNotBefore != nil {
		t.Fatal("legacy client saw deadline")
	}
	current := wire.ProjectWithEvents(projection, nil, false, false, true)
	if current.Rows[0].RefreshNotBefore == nil || current.Rows[0].Accounts[0].RefreshNotBefore == nil {
		t.Fatal("capable client lost deadline")
	}
	// A suspended mode retains the property but does not invent a deadline.
	off := consent.NewAdmission(admission.State(), consent.Off)
	backend.populateRefreshDeadlines(&projection, paths(off), off, nil, time.Now())
	if projection.Rows[0].RefreshNotBefore == nil || *projection.Rows[0].RefreshNotBefore != nil {
		t.Fatal("suspended grant did not retain unknown deadline")
	}
	// A corrupt budget is present but unknown; never invent a time.
	path := filepath.Join(cache, "observed", "reader-attempts", "codex.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(`{"bad":true}`), 0600); err != nil {
		t.Fatal(err)
	}
	backend.populateRefreshDeadlines(&projection, paths(admission), admission, []string{consent.ScopeCodexRuntimeUsage}, time.Now())
	row = projection.Rows[0]
	if row.RefreshNotBefore == nil || *row.RefreshNotBefore != nil {
		t.Fatal("unknown budget was not represented as null")
	}
	encoded, err := json.Marshal(row)
	if err != nil {
		t.Fatal(err)
	}
	var object map[string]json.RawMessage
	if err := json.Unmarshal(encoded, &object); err != nil || string(object["refreshNotBefore"]) != "null" {
		t.Fatalf("unknown deadline not present: %s %v", encoded, err)
	}
}
