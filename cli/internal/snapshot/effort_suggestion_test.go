// SPDX-License-Identifier: MIT
package snapshot_test

import (
	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/history"
	"github.com/modelplan/modelplan/cli/internal/snapshot"
	"testing"
	"time"
)

func TestEffortSuggestionClockAndPreferences(t *testing.T) {
	d, _ := contracttest.Public()
	at := contracttest.Now
	v := history.SuggestEffort(contracttest.EffortLedger(at, "medium", false, 40, 45, 50), d, at)
	in := snapshot.Input{Digest: d, Now: at, Recording: true, EffortSuggestion: v, EffortSuggestionRevision: "synthetic-observed-inputs", Boundaries: []time.Time{v.ExpiresAt}}
	a := snapshot.Build(in)
	if a.EffortSuggestion == nil || a.ValidUntil == nil || !a.ValidUntil.Equal(v.ExpiresAt) {
		t.Fatal("missing suggestion/expiry")
	}
	in.Now = v.ExpiresAt
	in.EffortSuggestion = nil
	b := snapshot.Build(in)
	if b.EffortSuggestion != nil || a.DataRevision != b.DataRevision {
		t.Fatal("clock changed observed revision")
	}
	in.EffortSuggestionRevision = "synthetic-dismissed"
	if snapshot.Build(in).DataRevision == a.DataRevision {
		t.Fatal("preferences did not change revision")
	}
	in.EffortSuggestion = v
	in.Recording = false
	if snapshot.Build(in).EffortSuggestion != nil {
		t.Fatal("recording off still shows suggestion")
	}
}
