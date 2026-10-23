package speed

import (
	"encoding/json"
	"sort"
	"time"
)

// Hourly uses completed-request timestamps; offsets distinguish repeated DST hours.
type Hourly struct {
	TokenKinds
	Hour                 string `json:"hour"`
	Source               string `json:"source"`
	Model                string `json:"model"`
	ObservedOutputTokens int64  `json:"observedOutputTokens"`
	ObservedRequests     int    `json:"observedRequests"`
}

func localHour(at time.Time) string {
	t := at.Local()
	return t.Add(-time.Duration(t.Minute())*time.Minute - time.Duration(t.Second())*time.Second - time.Duration(t.Nanosecond())).Format(time.RFC3339)
}
func (l *PerfLedger) addHourly(source string, q request, _ time.Time) {
	if q.end.IsZero() {
		return
	}
	h := localHour(q.end)
	for i := range l.Hourly {
		r := &l.Hourly[i]
		if r.Hour == h && r.Source == source && r.Model == q.cfg.model {
			r.TokenKinds.add(q.TokenKinds, r.ObservedRequests == 0)
			r.ObservedRequests++
			r.ObservedOutputTokens += q.out
			return
		}
	}
	r := Hourly{Hour: h, Source: source, Model: q.cfg.model, ObservedRequests: 1, ObservedOutputTokens: q.out}
	r.TokenKinds.add(q.TokenKinds, true)
	l.Hourly = append(l.Hourly, r)
}
func hourlyRows(rows []Hourly, now time.Time) []Hourly {
	from, to := windowFrom(now, 2), day(now)
	out := []Hourly{}
	for _, r := range rows {
		t, err := time.Parse(time.RFC3339, r.Hour)
		if err != nil || day(t) < from || day(t) > to || t.After(now) {
			continue
		}
		out = append(out, r)
	}
	sort.Slice(out, func(i, j int) bool {
		a, _ := time.Parse(time.RFC3339, out[i].Hour)
		b, _ := time.Parse(time.RFC3339, out[j].Hour)
		if !a.Equal(b) {
			return a.After(b)
		}
		if out[i].Source != out[j].Source {
			return out[i].Source < out[j].Source
		}
		return out[i].Model < out[j].Model
	})
	counts := map[[2]string]int{}
	kept := out[:0]
	for _, r := range out {
		k := [2]string{r.Source, r.Model}
		if counts[k] >= 48 {
			continue
		}
		counts[k]++
		kept = append(kept, r)
	}
	if len(kept) > 2048 {
		kept = kept[:2048]
	}
	for len(kept) > 0 {
		b, _ := json.Marshal(kept)
		if len(b) <= 512<<10 {
			break
		}
		kept = kept[:len(kept)*9/10]
	}
	sort.Slice(kept, func(i, j int) bool {
		if kept[i].Hour != kept[j].Hour {
			return kept[i].Hour < kept[j].Hour
		}
		if kept[i].Source != kept[j].Source {
			return kept[i].Source < kept[j].Source
		}
		return kept[i].Model < kept[j].Model
	})
	return kept
}
func (l *PerfLedger) pruneHourly(now time.Time) { l.Hourly = hourlyRows(l.Hourly, now) }
func (v PerfView) Hourly() []Hourly {
	if !v.OK {
		return []Hourly{}
	}
	return hourlyRows(v.Ledger.Hourly, v.Now)
}

// TodayTotal remains source-attributed, not proof of historic subscription ownership.
type TodayTotal struct {
	Source string   `json:"source"`
	Sums   PerfSums `json:"sums"`
}

func (v PerfView) TodayTotals() []TodayTotal {
	out := []TodayTotal{}
	if !v.OK {
		return out
	}
	by := map[string]int{}
	for i := range v.Ledger.Rows {
		r := &v.Ledger.Rows[i]
		if r.Day != day(v.Now) {
			continue
		}
		j, ok := by[r.Source]
		if !ok {
			j = len(out)
			by[r.Source] = j
			out = append(out, TodayTotal{Source: r.Source})
		}
		out[j].Sums.add(r)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Source < out[j].Source })
	return out
}
