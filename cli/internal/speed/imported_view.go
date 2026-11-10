package speed

import (
	"sort"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// ImportedRows are the admitted imported rows a history view may count next to the live ones.
// Three guards keep one turn from being counted twice or shown without consent:
//   - only rows stamped with the source's current grant epoch count (as Admitted does for live rows);
//   - only rows tagged origin "import" count, whatever else a file holds;
//   - a source's imported day on or after that source's first live day is dropped, so a day the
//     live ledgers cover is never counted from both. The importer already stops at the live
//     ledger's start; this holds even when a file was written by another version.
//
// The rows' timing fields are cleared: the history windows' generation rate stays a live
// reading, and an imported row only adds counts.
func (v PerfView) ImportedRows(imp ImportLedger, a consent.Admission) []PerfRow {
	if len(imp.Rows) == 0 {
		return nil
	}
	admitted := PerfView{Ledger: PerfLedger{Rows: imp.Rows}, OK: true}.Admitted(a).Ledger.Rows
	liveFirst := map[string]string{}
	note := func(source, day string) {
		if first, ok := liveFirst[source]; !ok || day < first {
			liveFirst[source] = day
		}
	}
	if v.OK {
		for i := range v.Ledger.Rows {
			if r := &v.Ledger.Rows[i]; r.Origin != OriginImport {
				note(r.Source, r.Day)
			}
		}
	}
	if v.LongOK {
		for _, r := range v.Long.Rows {
			note(r.Source, r.Day)
		}
	}
	var out []PerfRow
	for _, r := range admitted {
		if r.Origin != OriginImport {
			continue
		}
		if first, ok := liveFirst[r.Source]; ok && r.Day >= first {
			continue
		}
		r.EligibleRequests, r.EligibleOutputTokens, r.GenMs = 0, 0, 0
		r.TTFTMs, r.TurnMsHist, r.TurnTokensHist = nil, nil, nil
		out = append(out, r)
	}
	return out
}

// WithImported returns the view with the imported rows added to the live ledger's, for the 7- and
// 30-day windows and rankings. Rows stay tagged with their origin. Use ImportedDaily for the
// per-day series, which keeps the two origins apart.
func (v PerfView) WithImported(rows []PerfRow) PerfView {
	if len(rows) == 0 {
		return v
	}
	merged := make([]PerfRow, 0, len(v.Ledger.Rows)+len(rows))
	merged = append(merged, v.Ledger.Rows...)
	merged = append(merged, rows...)
	v.Ledger.Rows = merged
	return v
}

// ImportedDaily sums imported rows per local day, source and model from day `from` on.
func ImportedDaily(rows []PerfRow, from string) []Daily { return rollup(rows, from) }

// ImportedFirstDay is the earliest local day among the rows ("" for none).
func ImportedFirstDay(rows []PerfRow) string {
	days := make([]string, 0, len(rows))
	for _, r := range rows {
		days = append(days, r.Day)
	}
	if len(days) == 0 {
		return ""
	}
	sort.Strings(days)
	return days[0]
}
