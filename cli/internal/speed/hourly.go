package speed

import (
	"sort"
	"time"
)

// Hourly is by completion hour (ISO 8601 with local UTC offset, keeping the DST fold distinct).
// Only today and yesterday survive, and at most 48 nonempty buckets per source/model.
type Hourly struct {
	Hour                 string `json:"hour"`
	Source               string `json:"source"`
	Model                string `json:"model"`
	ObservedOutputTokens int64  `json:"observedOutputTokens"`
	ObservedRequests     int    `json:"observedRequests"`
	InputTokens          *int64 `json:"inputTokens"`
	CacheReadTokens      *int64 `json:"cacheReadTokens"`
	CacheWriteTokens     *int64 `json:"cacheWriteTokens"`
}

func (l *PerfLedger) addHourly(source string, q request) {
	if q.end.IsZero() {
		return
	}
	t := q.end.Local()
	// Use the observed offset explicitly: a DST transition may be only 30 minutes.
	// Subtracting wall-clock minutes across that transition can produce a :30 bucket.
	_, offset := t.Zone()
	h := time.Date(t.Year(), t.Month(), t.Day(), t.Hour(), 0, 0, 0, time.FixedZone("", offset)).Format(time.RFC3339)
	i := 0
	for i < len(l.Hourly) {
		x := l.Hourly[i]
		if x.Hour == h && x.Source == source && x.Model == q.cfg.model {
			break
		}
		i++
	}
	if i == len(l.Hourly) {
		l.Hourly = append(l.Hourly, Hourly{Hour: h, Source: source, Model: q.cfg.model})
	}
	x := &l.Hourly[i]
	x.InputTokens = sumToken(x.InputTokens, q.input, x.ObservedRequests)
	x.CacheReadTokens = sumToken(x.CacheReadTokens, q.cacheRead, x.ObservedRequests)
	x.CacheWriteTokens = sumToken(x.CacheWriteTokens, q.cacheWrite, x.ObservedRequests)
	x.ObservedOutputTokens += q.out
	x.ObservedRequests++
}
func (l *PerfLedger) pruneHourly(now time.Time) { l.Hourly = hourlyView(l.Hourly, now) }
func hourlyView(rows []Hourly, now time.Time) []Hourly {
	out := []Hourly{}
	from, to := windowFrom(now, 2), day(now)
	for _, r := range rows {
		t, e := time.Parse(time.RFC3339, r.Hour)
		if e == nil && day(t) >= from && day(t) <= to && !t.After(now) {
			out = append(out, r)
		}
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
		if counts[k] < 48 {
			kept = append(kept, r)
			counts[k]++
		}
	}
	// Chronological order, including a repeated DST hour with distinct offsets.
	sort.SliceStable(kept, func(i, j int) bool {
		a, _ := time.Parse(time.RFC3339, kept[i].Hour)
		b, _ := time.Parse(time.RFC3339, kept[j].Hour)
		return a.Before(b)
	})
	return kept
}
func (v PerfView) Hourly() []Hourly {
	if !v.OK {
		return []Hourly{}
	}
	return hourlyView(v.Ledger.Hourly, v.Now)
}
