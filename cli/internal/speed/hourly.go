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

// Size bounds. perf.json as a whole must stay under maxFile (2 MiB) or the whole ledger is refused on load.
//   - Rows from before yesterday are compacted to one row per hour, source and consent epoch (compactHourly; it also drops the
//     token kinds, only output counts are read from those hours): 28 older days hold at most 28*24*4 sources = 2688 rows per
//     epoch, about 190 bytes each, so about 510 KiB for four sources active in every hour of every day.
//   - Yesterday, today and the rolling 48 hours keep one row per model, up to hourlyRecentBytes; beyond that they lose their model
//     names too (a pathological number of models inside two days).
//   - The whole is capped at hourlyMaxBytes (the file writer, perf.go prune, trims whole oldest hourly days again when the whole
//     file would not fit under writeLimit, before it touches anything else).
//   - The whole is capped at hourlyMaxBytes. Over it, the oldest whole local day goes, never part of a day and never yesterday,
//     today or the cost window.
const (
	hourlyMaxBytes    = 1 << 20
	hourlyRecentBytes = 512 << 10
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
// the rolling 48 hours of the ≈cost. Days before yesterday are compacted (per-model detail goes, the per hour and source
// totals and the consent epoch stay), then whole oldest days go while the stored bytes exceed hourlyMaxBytes.
func hourlyKept(rows []Hourly, now time.Time) []Hourly {
	from, to := windowFrom(now, HourlyKeepDays), day(now)
	recent := windowFrom(now, 2)
	kept := hourlyWhere(rows, now, func(t time.Time) bool {
		return (day(t) >= from && day(t) <= to) || t.After(now.Add(-costHours))
	})
	kept = compactHourly(kept, recent, now)
	protected := func(r Hourly) bool { return hourDay(r) >= recent || parsedAfter(r, now.Add(-costHours)) }
	size := func(rs []Hourly) int { b, _ := json.Marshal(rs); return len(b) }
	if n := sort.Search(len(kept), func(i int) bool { return protected(kept[i]) }); size(kept[n:]) > hourlyRecentBytes {
		kept = compactHourly(kept, "9999", now.Add(1000*costHours)) // every row, model names included
	}
	for len(kept) > 0 && size(kept) > hourlyMaxBytes {
		next, ok := dropOldestHourlyDay(kept, now)
		if !ok {
			break
		}
		kept = next
	}
	// Still over (an absurd number of consent epochs or sources inside two days): whole oldest hours go, never part of an hour.
	for len(kept) > 1 && size(kept) > hourlyMaxBytes {
		i := 1
		for i < len(kept) && kept[i].Hour == kept[0].Hour {
			i++
		}
		kept = kept[i:]
	}
	return kept
}

// dropOldestHourlyDay removes the oldest local day, whole, from rows sorted oldest first. It refuses (false) when that day
// reaches into the cost window or is yesterday or today.
func dropOldestHourlyDay(rows []Hourly, now time.Time) ([]Hourly, bool) {
	if len(rows) == 0 {
		return rows, false
	}
	recent, oldest, i := windowFrom(now, 2), hourDay(rows[0]), 0
	for i < len(rows) && hourDay(rows[i]) == oldest {
		if oldest >= recent || parsedAfter(rows[i], now.Add(-costHours)) {
			return rows, false
		}
		i++
	}
	return rows[i:], true
}

func hourDay(r Hourly) string {
	t, _ := time.Parse(time.RFC3339, r.Hour)
	return day(t)
}

func parsedAfter(r Hourly, at time.Time) bool {
	t, err := time.Parse(time.RFC3339, r.Hour)
	return err == nil && t.After(at)
}

// compactHourly merges the rows of days before keepFrom (a local date) into one row per hour, source and consent epoch,
// summing request and output counts. The model name and token kinds are dropped from those rows: nothing reads a model from an hour older than
// yesterday, and the cockpit sums models anyway. The input is sorted oldest first; so is the result.
func compactHourly(rows []Hourly, keepFrom string, now time.Time) []Hourly {
	out := make([]Hourly, 0, len(rows))
	at := map[[2]string][]int{}
	for _, r := range rows {
		if hourDay(r) >= keepFrom || parsedAfter(r, now.Add(-costHours)) {
			out = append(out, r)
			continue
		}
		k := [2]string{r.Hour, r.Source}
		merged := false
		for _, i := range at[k] {
			if sameEpoch(out[i].GrantEpoch, r.GrantEpoch) {
				out[i].ObservedRequests += r.ObservedRequests
				out[i].ObservedOutputTokens += r.ObservedOutputTokens
				merged = true
				break
			}
		}
		if !merged {
			r.Model, r.TokenKinds = "", TokenKinds{}
			at[k] = append(at[k], len(out))
			out = append(out, r)
		}
	}
	return out
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
	kept := out
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

// Encode prunes the ledger as it is when saved and returns the perf.json content.
func (l *PerfLedger) Encode(now time.Time) []byte { return l.prune(now) }
