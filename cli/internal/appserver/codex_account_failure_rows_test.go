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
