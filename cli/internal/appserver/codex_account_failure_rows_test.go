// SPDX-License-Identifier: MIT
package appserver

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

// Post-merge sample 11-11 (#792 finding 3): a retained Codex runtime account keeps the cause of
// the failed refresh (reported under "codex-account"), and an independent local-history account
// does not borrow it.
func TestRetainedCodexAccountKeepsItsFailureCause(t *testing.T) {
	now := time.Now().UTC()
	in := rows.Input{Now: now}
	report := quota.Report{EvaluatedAt: now,
		Sources: []quota.SourceStatus{{Source: "codex-account", Status: "stale", ErrorCode: "closed", Reason: "last refresh failed"}},
		Accounts: []quota.Account{
			{Source: "codex", Via: "codex-account", ObservedAt: now.Add(-time.Hour)},
			{Source: "codex", ObservedAt: now.Add(-time.Hour)},
		}}
	appendReportRows(&in, report, false)
	if len(in.Profiles) != 2 {
		t.Fatalf("profiles %+v", in.Profiles)
	}
	runtime, local := in.Profiles[0], in.Profiles[1]
	if runtime.LastFailure == nil || runtime.LastFailure.Code != "closed" || runtime.LatestAttempt != rows.AttemptResultFailed {
		t.Fatalf("runtime account lost its failure cause: %+v", runtime)
	}
	if local.LastFailure != nil || local.LatestAttempt != rows.AttemptResultSucceeded {
		t.Fatalf("local-history account borrowed the runtime failure: %+v", local)
	}
}

// SET-9-42: a Codex reader that failed before any account or reading exists still produces its
// own tool row (menu and Settings, no Dock ring) naming the fixed cause, so Settings can show it.
func TestAccountlessCodexFailureReachesRowsWithItsCause(t *testing.T) {
	for _, code := range []string{"closed", "rpc_error", "runtime_missing"} {
		now := time.Now().UTC()
		in := rows.Input{Now: now, ConsentGeneration: 1,
			Catalogue: []rows.CatalogueEntry{{ToolID: "codex", Detected: true, ReaderExists: true}},
			Consents:  []rows.ConsentRecord{{ToolID: "codex", State: rows.ConsentAllowed, Generation: 1}}}
		appendReportRows(&in, quota.Report{EvaluatedAt: now,
			Sources: []quota.SourceStatus{{Source: "codex-account", Status: "error", ErrorCode: code, Reason: "last refresh failed"}}}, false)
		var row *rows.Row
		out := rows.Build(in)
		for i := range out.Rows {
			if out.Rows[i].ID == "codex" {
				row = &out.Rows[i]
			}
		}
		if row == nil {
			t.Fatalf("%s: the failed Codex reader has no row at all", code)
		}
		if len(row.Accounts) != 0 || row.State != rows.StateFailed && row.State != rows.StateNeedsAction {
			t.Fatalf("%s: row state %q accounts %d", code, row.State, len(row.Accounts))
		}
		if string(row.Reason.Code) != code {
			t.Fatalf("%s: row reason %q, want the fixed cause", code, row.Reason.Code)
		}
		settings := false
		for _, s := range row.Surfaces {
			if s == rows.SurfaceDock {
				t.Fatalf("%s: an accountless failure must not draw a Dock ring", code)
			}
			settings = settings || s == rows.SurfaceSettings
		}
		if !settings {
			t.Fatalf("%s: row is missing the Settings surface: %v", code, row.Surfaces)
		}
	}
}
