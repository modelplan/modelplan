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
	rows := map[string]bool{}
	for _, row := range view.Projection.Rows {
		rows[row.ID] = true
	}
	for _, peak := range advise.Peaks(published, view.QuotaReport, now, cockpitPeakHorizon) {
		id := "declared:" + url.PathEscape(peak.Plan)
		if !rows[id] || len(out) == 32 {
			continue
		}
		entry := wire.CockpitPeak{RowID: id, StartsAt: peak.StartsAt.UTC(), EndsAt: peak.EndsAt, Status: strings.ToLower(peak.Status)}
		if entry.Status != "confirmed" {
			entry.Status = "tentative"
		}
		out = append(out, entry)
	}
	return out
}
