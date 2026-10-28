// SPDX-License-Identifier: MIT
package snapshot

import (
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"testing"
	"time"
)

func TestProductionHistoryRevisionIgnoresClockProjection(t *testing.T) {
	at := time.Date(2026, 10, 27, 12, 0, 0, 0, time.UTC)
	input := int64(10)
	r := localusage.HistoryResult{Tool: "amp", Availability: "ok", Freshness: "fresh", ObservedAt: at, NextAttemptAt: at.Add(5 * time.Minute), Rows: []localusage.HistoryRow{{Day: "2026-10-27", Model: "synthetic", HistoryCounts: localusage.HistoryCounts{Input: &input}}}}
	first := Build(Input{LocalHistory: []localusage.HistoryResult{r}, Now: at})
	r.Freshness = "stale"
	r.NextStep = "Wait"
	later := Build(Input{LocalHistory: []localusage.HistoryResult{r}, Now: at.Add(2 * time.Hour)})
	if first.DataRevision == "" || first.DataRevision != later.DataRevision {
		t.Fatal("clock-only history freshness changed data revision")
	}
	changed := int64(11)
	r.Rows[0].Input = &changed
	if Build(Input{LocalHistory: []localusage.HistoryResult{r}, Now: at}).DataRevision == first.DataRevision {
		t.Fatal("history counts omitted from data revision")
	}
}
