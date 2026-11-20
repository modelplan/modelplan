package speed

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"math"
	"sort"
	"time"

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
	liveFirst := v.liveFirstDays()
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

// liveFirstDays: each source's first local day the live ledgers hold.
func (v PerfView) liveFirstDays() map[string]string {
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
	return liveFirst
}

// ImportedProjects are the imported per-day project sums a ranking may count: only those under the
// source's current grant (as ImportedRows), and only before the source's first live day.
func (v PerfView) ImportedProjects(imp ImportLedger, a consent.Admission) []ImportProject {
	liveFirst := v.liveFirstDays()
	var out []ImportProject
	for _, p := range imp.Projects {
		epoch := currentEpoch(a, p.Source)
		if epoch == nil || !sameEpoch(p.GrantEpoch, epoch) {
			continue
		}
		if first, ok := liveFirst[p.Source]; ok && p.Day >= first {
			continue
		}
		out = append(out, p)
	}
	return out
}

// WithImportedProjects adds imported project days to a ranking, by folder name: a project the live
// sessions already label with the same name takes the tokens, any other becomes a project of its own.
// Shares are over the window's total, which now includes the imported tokens. cache names the
// ledger whose key makes the reference of a project known only from import. Projects outside the
// live ranking's top ten are not matched by name.
func (r ProjectRanking) WithImportedProjects(cache string, now time.Time, ps []ImportProject) ProjectRanking {
	if len(ps) == 0 {
		return r
	}
	r.Recent7d = r.Recent7d.withImported(cache, windowFrom(now, 7), ps)
	r.Recent30d = r.Recent30d.withImported(cache, windowFrom(now, 30), ps)
	return r
}

func (w ProjectWindow) withImported(cache, from string, ps []ImportProject) ProjectWindow {
	type sum struct {
		tokens int64
		last   string
	}
	by := map[string]*sum{}
	var names []string
	for _, p := range ps {
		if p.Day < from || p.ObservedOutputTokens <= 0 || p.Name == "" {
			continue
		}
		s := by[p.Name]
		if s == nil {
			s = &sum{}
			by[p.Name] = s
			names = append(names, p.Name)
		}
		s.tokens += p.ObservedOutputTokens
		if p.Day > s.last {
			s.last = p.Day
		}
		w.TotalObservedOutputTokens += p.ObservedOutputTokens
	}
	if len(names) == 0 {
		return w
	}
	sort.Strings(names)
	top := append([]RankedProject{}, w.Top...)
	for _, name := range names {
		s := by[name]
		matched := false
		for i := range top {
			if top[i].Label != nil && *top[i].Label == name {
				top[i].ObservedOutputTokens += s.tokens
				matched = true
				break
			}
		}
		if matched {
			continue
		}
		key := projectKey(cache)
		if key == nil {
			w.UnattributedOutputTokens += s.tokens // no reference can be made: counted, not ranked
			continue
		}
		label := name
		last, _ := time.ParseInLocation("2006-01-02", s.last, time.Local)
		top = append(top, RankedProject{Ref: importedProjectRef(key, name), Label: &label, SubscriptionRefs: []string{},
			LastAt: last, ObservedOutputTokens: s.tokens, Configs: []SessionConfig{}})
		w.Projects++
	}
	sort.SliceStable(top, func(i, j int) bool {
		if top[i].ObservedOutputTokens != top[j].ObservedOutputTokens {
			return top[i].ObservedOutputTokens > top[j].ObservedOutputTokens
		}
		return top[i].LastAt.After(top[j].LastAt)
	})
	if len(top) > rankedProjects {
		top = top[:rankedProjects]
	}
	for i := range top {
		top[i].Share = math.Round(float64(top[i].ObservedOutputTokens)/float64(w.TotalObservedOutputTokens)*1000) / 1000
	}
	w.Top = top
	return w
}

// importedProjectRef: the reference of a project known only from imported history, keyed like the
// live ones so it says nothing about the path.
func importedProjectRef(key []byte, name string) string {
	m := hmac.New(sha256.New, key)
	m.Write([]byte("import:" + name))
	return hex.EncodeToString(m.Sum(nil)[:16])
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
