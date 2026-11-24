package speed

import (
	"encoding/json"
	"sort"
	"time"
)

// Hourly uses completed-request timestamps; offsets distinguish repeated DST hours.
type Hourly struct {
	GrantEpoch *GrantEpoch `json:"grantEpoch,omitempty"`
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
	epoch := currentEpoch(l.admission, source)
	for i := range l.Hourly {
		r := &l.Hourly[i]
		if r.Hour == h && r.Source == source && r.Model == q.cfg.model && sameEpoch(r.GrantEpoch, epoch) {
			r.TokenKinds.add(q.TokenKinds, r.ObservedRequests == 0)
			r.ObservedRequests++
			r.ObservedOutputTokens += q.out
			return
		}
	}
	r := Hourly{GrantEpoch: epoch, Hour: h, Source: source, Model: q.cfg.model, ObservedRequests: 1, ObservedOutputTokens: q.out}
	r.TokenKinds.add(q.TokenKinds, true)
	l.Hourly = append(l.Hourly, r)
}

// costHours is the rolling window of the hourly ≈cost (WP-06): an hour starting after now−48h.
const costHours = 48 * time.Hour

// HourlyKeepDays is how many local days (today included) of hourly rows the ledger retains (D402). The rows
// are aggregate counts per hour, source and model, added as each request is counted; nothing is rescanned for them.
const HourlyKeepDays = 30

const (
	hourlyPerKey = HourlyKeepDays*24 + 48 // one source and model: every hour of the window plus a repeated DST hour
	hourlyTotal  = 8192
)

// hourlyRows is the hourly view: today and yesterday by local date.
func hourlyRows(rows []Hourly, now time.Time) []Hourly {
	return hourlyDays(rows, now, 2)
}

func hourlyDays(rows []Hourly, now time.Time, days int) []Hourly {
	from, to := windowFrom(now, days), day(now)
	return hourlyWhere(rows, now, func(t time.Time) bool { return day(t) >= from && day(t) <= to })
}

// hourlyKept is what the ledger retains: the last HourlyKeepDays local days, and every hour still inside
// the rolling 48 hours of the ≈cost.
func hourlyKept(rows []Hourly, now time.Time) []Hourly {
	from, to := windowFrom(now, HourlyKeepDays), day(now)
	return hourlyWhere(rows, now, func(t time.Time) bool {
		return (day(t) >= from && day(t) <= to) || t.After(now.Add(-costHours))
	})
}

// costHourly is the hourly ≈cost window: hours starting after now−48h and not after now.
func (v PerfView) costHourly() []Hourly {
	if !v.OK {
		return []Hourly{}
	}
	return hourlyWhere(v.Ledger.Hourly, v.Now, func(t time.Time) bool { return t.After(v.Now.Add(-costHours)) })
}

func hourlyWhere(rows []Hourly, now time.Time, keep func(time.Time) bool) []Hourly {
	out := []Hourly{}
	for _, r := range rows {
		t, err := time.Parse(time.RFC3339, r.Hour)
		if err != nil || t.After(now) || !keep(t) {
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
		if counts[k] >= hourlyPerKey {
			continue
		}
		counts[k]++
		kept = append(kept, r)
	}
	if len(kept) > hourlyTotal {
		kept = kept[:hourlyTotal]
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
func (l *PerfLedger) pruneHourly(now time.Time) { l.Hourly = hourlyKept(l.Hourly, now) }
func (v PerfView) Hourly() []Hourly {
	if !v.OK {
		return []Hourly{}
	}
	return hourlyRows(v.Ledger.Hourly, v.Now)
}

// HourlyDays is the hourly view over the last n local days (today included), n between 1 and HourlyKeepDays.
func (v PerfView) HourlyDays(n int) []Hourly {
	if !v.OK {
		return []Hourly{}
	}
	return hourlyDays(v.Ledger.Hourly, v.Now, min(max(n, 1), HourlyKeepDays))
}

// TodayTotal remains source-attributed, not proof of historic subscription ownership.
type TodayTotal struct {
	Source string   `json:"source"`
	Sums   PerfSums `json:"sums"`
}

func (v PerfView) TodayTotals() []TodayTotal {
	v = v.accounted()
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
