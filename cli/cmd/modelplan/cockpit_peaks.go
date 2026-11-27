// SPDX-License-Identifier: MIT
package main

import (
	"net/url"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/advise"
	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

const cockpitPeakHorizon = 24 * time.Hour

// cockpitPeaks passes the advice's time-of-day windows to the cockpit: for each declared plan that has a row in
// this projection, its current or next raised-rate window within 24 hours. Only the verified client publication
// is read; a plan without published windows, or with an unknown rate, has no entry.
func cockpitPeaks(published *digest.Digest, view appserver.View, now time.Time) []wire.CockpitPeak {
	out := []wire.CockpitPeak{}
	if published == nil || published.Source != digest.ComponentClient {
		return out
	}
	rowIDs := map[string]bool{}
	for _, row := range view.Projection.Rows {
		rowIDs[row.ID] = true
	}
	for _, peak := range advise.Peaks(published, view.QuotaReport, now, cockpitPeakHorizon) {
		id := "declared:" + url.PathEscape(peak.Plan)
		if !rowIDs[id] || len(out) == 32 {
			continue
		}
		entry := wire.CockpitPeak{RowID: id, StartsAt: peak.StartsAt.UTC(), EndsAt: peak.EndsAt, Status: strings.ToLower(peak.Status)}
		if entry.Status != "confirmed" {
			entry.Status = "tentative"
		}
		out = append(out, entry)
	}
	// A subscription the tool read itself (ZCode by QR sign-in or key) has a tool row, not a declared one: the
	// provider's plan-wide windows apply to it, tentatively (D328).
	for i := range view.QuotaReport.Accounts {
		a := &view.QuotaReport.Accounts[i]
		if a.Source == "user" || rows.CanonicalTool(a.Source) != "zai" || !rowIDs["zai"] || len(out) == 32 {
			continue
		}
		if peak, ok := advise.ProviderPeaks(published, "zai", now, cockpitPeakHorizon); ok {
			out = append(out, wire.CockpitPeak{RowID: "zai", StartsAt: peak.StartsAt, EndsAt: peak.EndsAt, Status: "tentative"})
		}
		break
	}
	return out
}
