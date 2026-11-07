package speed

import (
	"math"
	"sort"
)

// SourceHistory is one source's observed sums over the recent 7 and 30 local calendar days, as
// TodayTotals is for today: what the harnesses on this machine produced, summed across their
// configurations. Unattributed: the rows carry no subscription identity.
type SourceHistory struct {
	Source    string    `json:"source"`
	Recent7d  PerfSums  `json:"recent7d"`
	Recent30d PerfSums  `json:"recent30d"`
}

// HistoryWindows: per source, the sums of the recent 7 and 30 local days. A missing token kind
// in any counted row leaves that sum unknown, never zero. Sources with no counted row in either
// window are left out, like TodayTotals leaves out a source with nothing today.
func (v PerfView) HistoryWindows() []SourceHistory {
	out := []SourceHistory{}
	if !v.OK {
		return out
	}
	from7, from30 := windowFrom(v.Now, 7), windowFrom(v.Now, 30)
	by := map[string]int{}
	for i := range v.Ledger.Rows {
		r := &v.Ledger.Rows[i]
		j, ok := by[r.Source]
		if !ok {
			j = len(out)
			by[r.Source] = j
			out = append(out, SourceHistory{Source: r.Source})
		}
		if r.Day >= from30 {
			out[j].Recent30d.add(r)
		}
		if r.Day >= from7 {
			out[j].Recent7d.add(r)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Source < out[j].Source })
	return out
}

// RankedEntity is one model, across every source that ran it, or one tool (the ledger's source),
// in a history ranking. Its figures are what this CLI observed, not any plan's or account's use.
type RankedEntity struct {
	Name                 string  `json:"name"`
	ObservedRequests     int     `json:"observedRequests"`
	ObservedOutputTokens int64   `json:"observedOutputTokens"`
	Share                float64 `json:"share"` // of the window's observed output tokens
}

// EntityWindow: every entity with a counted row in the window, ranked by observed output tokens.
type EntityWindow struct {
	Entities                  int             `json:"entities"`
	TotalObservedOutputTokens int64           `json:"totalObservedOutputTokens"`
	Top                       []RankedEntity  `json:"top"`
}

// EntityRanking ranks models or tools by observed output tokens over the recent 7 and 30 local
// days. Attribution is "unattributed": the ledger cannot split a source's history between the
// accounts that used it.
type EntityRanking struct {
	Measure     string        `json:"measure"`     // observed-output-tokens
	Attribution string        `json:"attribution"` // unattributed
	Recent7d    EntityWindow  `json:"recent7d"`
	Recent30d   EntityWindow  `json:"recent30d"`
}

// HistoryRankings holds the two rankings. Only rows of the given sources are counted (nil or
// empty: every source); shares are of the counted total, so an unconsented source never dilutes
// another's share.
type HistoryRankings struct {
	Models EntityRanking `json:"models"`
	Tools  EntityRanking `json:"tools"`
}

const rankedEntities = 10

func (v PerfView) HistoryRankings(sources map[string]bool) HistoryRankings {
	counts := func(source string) bool {
		if len(sources) == 0 {
			return true
		}
		return sources[source]
	}
	rank := func(nameOf func(*PerfRow) string, measure string) EntityRanking {
		r7, r30 := v.rankEntities(nameOf, counts, windowFrom(v.Now, 7)), v.rankEntities(nameOf, counts, windowFrom(v.Now, 30))
		return EntityRanking{Measure: measure, Attribution: "unattributed", Recent7d: r7, Recent30d: r30}
	}
	return HistoryRankings{
		Models: rank(func(r *PerfRow) string { return r.Model }, "observed-output-tokens"),
		Tools:  rank(func(r *PerfRow) string { return r.Source }, "observed-output-tokens"),
	}
}

func (v PerfView) rankEntities(nameOf func(*PerfRow) string, countSource func(string) bool, from string) EntityWindow {
	w := EntityWindow{Top: []RankedEntity{}}
	if !v.OK {
		return w
	}
	by := map[string]*RankedEntity{}
	var names []string
	for i := range v.Ledger.Rows {
		r := &v.Ledger.Rows[i]
		if r.Day < from || !countSource(r.Source) {
			continue
		}
		name := nameOf(r)
		if name == "" {
			continue
		}
		e := by[name]
		if e == nil {
			e = &RankedEntity{Name: name}
			by[name] = e
			names = append(names, name)
		}
		e.ObservedRequests += r.ObservedRequests
		e.ObservedOutputTokens += r.ObservedOutputTokens
		w.TotalObservedOutputTokens += r.ObservedOutputTokens
	}
	w.Entities = len(names)
	all := make([]RankedEntity, 0, len(names))
	for _, name := range names {
		all = append(all, *by[name])
	}
	sort.SliceStable(all, func(i, j int) bool {
		if all[i].ObservedOutputTokens != all[j].ObservedOutputTokens {
			return all[i].ObservedOutputTokens > all[j].ObservedOutputTokens
		}
		return all[i].Name < all[j].Name
	})
	for i := range all {
		if i == rankedEntities {
			break
		}
		if w.TotalObservedOutputTokens > 0 {
			all[i].Share = math.Round(float64(all[i].ObservedOutputTokens)/float64(w.TotalObservedOutputTokens)*1000) / 1000
		}
		w.Top = append(w.Top, all[i])
	}
	return w
}
