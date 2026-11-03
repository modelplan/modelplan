// SPDX-License-Identifier: MIT
package appserver

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func TestRefreshDeadlinePresentForFreshRowAndMember(t *testing.T) {
	_, paths, cache, member := memberFixture(t)
	admission := consent.Capture()
	ref := member.SubscriptionRef
	projection := rows.Projection{Rows: []rows.Row{{ID: "codex", State: rows.StateFresh, Accounts: []rows.Account{{Route: rows.RouteRuntimeRPC, SubscriptionRef: &ref}}}}}
	backend := &SharedBackend{}
	backend.populateRefreshDeadlines(&projection, paths(admission), admission, []string{consent.ScopeCodexRuntimeUsage}, time.Now())
	row, account := projection.Rows[0], projection.Rows[0].Accounts[0]
	if row.NextStep != nil || row.RefreshNotBefore == nil || *row.RefreshNotBefore == nil || account.RefreshNotBefore == nil || *account.RefreshNotBefore == nil { t.Fatalf("fresh deadline missing: %+v %+v", row, account) }
	if !(**row.RefreshNotBefore).Equal(alreadyDue) { t.Fatal("due timestamp was not stable") }
	old := wire.Project(projection)
	if old.Rows[0].RefreshNotBefore != nil || old.Rows[0].Accounts[0].RefreshNotBefore != nil { t.Fatal("legacy client saw deadline") }
	current := wire.ProjectWithEvents(projection, nil, false, false, true)
	if current.Rows[0].RefreshNotBefore == nil || current.Rows[0].Accounts[0].RefreshNotBefore == nil { t.Fatal("capable client lost deadline") }
	// A suspended mode retains the property but does not invent a deadline.
	off := consent.NewAdmission(admission.State(), consent.Off)
	backend.populateRefreshDeadlines(&projection, paths(off), off, nil, time.Now())
	if projection.Rows[0].RefreshNotBefore == nil || *projection.Rows[0].RefreshNotBefore != nil { t.Fatal("suspended grant did not retain unknown deadline") }
	// A corrupt budget is present but unknown; never invent a time.
	path := filepath.Join(cache, "observed", "reader-attempts", "codex.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil { t.Fatal(err) }
	if err := os.WriteFile(path, []byte(`{"bad":true}`), 0600); err != nil { t.Fatal(err) }
	backend.populateRefreshDeadlines(&projection, paths(admission), admission, []string{consent.ScopeCodexRuntimeUsage}, time.Now())
	row = projection.Rows[0]
	if row.RefreshNotBefore == nil || *row.RefreshNotBefore != nil { t.Fatal("unknown budget was not represented as null") }
	encoded, err := json.Marshal(row)
	if err != nil { t.Fatal(err) }
	var object map[string]json.RawMessage
	if err := json.Unmarshal(encoded, &object); err != nil || string(object["refreshNotBefore"]) != "null" { t.Fatalf("unknown deadline not present: %s %v", encoded, err) }
}
