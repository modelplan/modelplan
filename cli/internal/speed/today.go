package speed

import "sort"

// TodayTotal is a source's workload, not an account measurement. Bind sources to subscriptions
// only when the mapping is unambiguous; simultaneous requests add their generation time.
type TodayTotal struct {
	Source        string   `json:"source"`
	Attribution   string   `json:"attribution"`
	Sums          PerfSums `json:"sums"`
	GenerationTps Metric   `json:"generationTps"`
}

func (v PerfView) TodayTotals() []TodayTotal {
	out := []TodayTotal{}
	if !v.OK {
		return out
	}
	by := map[string]*acc{}
	for i := range v.Ledger.Rows {
		r := &v.Ledger.Rows[i]
		if r.Day != day(v.Now) {
			continue
		}
		if by[r.Source] == nil {
			by[r.Source] = &acc{}
		}
		by[r.Source].add(r)
	}
	keys := make([]string, 0, len(by))
	for k := range by {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		a := by[k]
		out = append(out, TodayTotal{Source: k, Attribution: "unattributed", Sums: a.sums, GenerationTps: v.window(a, a.lastAt).Metrics.GenerationTps})
	}
	return out
}
