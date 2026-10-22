package speed

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"time"
)

// The long-term daily ledger, <cache>/observed/daily-long.json, keeps what perf.json's rows add up
// to per local day, source and model for LongDays days, so a client can draw a year of activity
// after perf.json has let its older days go. It is a roll-up of perf.json and nothing else: it is
// written right after perf.json, under the same lock, and counts nothing perf.json did not count.
// It holds days, sources, model names and two sums; no prompts, replies, paths, sessions or ids.
// A day's figures in perf.json only grow (until the day is pruned), so a roll-up keeps the larger
// of the stored and the rolled-up figures: writing it again never counts a request twice, and
// perf.json letting a day go never shrinks it here. MODELPLAN_HISTORY=off stops it with perf.json;
// deleting the file clears it.

const (
	LongDays    = 371     // 53 weeks of calendar days, today included
	maxLongFile = 1 << 20 // the file stays below 1 MiB; the oldest days go first
)

// LongLedger is daily-long.json's content.
type LongLedger struct {
	SchemaVersion int `json:"schemaVersion"`
	// Since (UTC): where its coverage starts. It is perf.json's since, or the start of the first
	// local day perf.json still held whole when this file was created, whichever is later.
	Since time.Time `json:"since"`
	// TrimmedFrom: once the size limit dropped the oldest days, the first local day kept whole.
	TrimmedFrom string  `json:"trimmedFrom,omitempty"`
	Rows        []Daily `json:"rows"`
}

// LongPath is the ledger file.
func LongPath(cache string) string { return filepath.Join(cache, "observed", "daily-long.json") }

// LoadLong reads the ledger. A missing file is a new, empty ledger (zero Since). ok is false when
// the file is there but cannot be used (unreadable, too large, another schema or no Since); it is
// then left as it is.
func LoadLong(cache string) (l LongLedger, ok bool) {
	b, err := os.ReadFile(LongPath(cache))
	if errors.Is(err, os.ErrNotExist) {
		return LongLedger{SchemaVersion: 1}, true
	}
	if err != nil || len(b) > maxLongFile {
		return LongLedger{}, false
	}
	if json.Unmarshal(b, &l) != nil || l.SchemaVersion != 1 || l.Since.IsZero() {
		return LongLedger{}, false
	}
	return l, true
}

// observeLong rolls perf.json's rows (roll, taken before perf.json pruned them) into the ledger.
// The caller holds perf.lock and has just written perf.json, whose since is perfSince.
func observeLong(cache string, now, perfSince time.Time, roll []Daily) error {
	l, ok := LoadLong(cache)
	if !ok {
		return nil // not ours to overwrite
	}
	created := l.Since.IsZero()
	if created {
		// perf.json keeps whole days from PerfKeep ago; anything older it may have let go already.
		l.Since = perfSince.UTC()
		if start := dayStart(now.Add(-PerfKeep)); start.After(l.Since) {
			l.Since = start
		}
	}
	changed := l.merge(roll)
	b, dropped := l.prune(now)
	if !created && !changed && !dropped {
		return nil
	}
	return write(LongPath(cache), b)
}

// from: the first local day the ledger covers, before the LongDays window is applied.
func (l *LongLedger) from() string {
	return max(day(l.Since), l.TrimmedFrom)
}

func (l *LongLedger) merge(roll []Daily) bool {
	var changed bool
	l.Rows, changed = mergeDaily(l.Rows, roll, l.from())
	return changed
}

// prune keeps LongDays local days and less than maxLongFile bytes (dropping the oldest days whole
// and noting the first day kept whole), and returns the file's content and whether it dropped
// anything.
func (l *LongLedger) prune(now time.Time) ([]byte, bool) {
	from := windowFrom(now, LongDays)
	n := len(l.Rows)
	kept := l.Rows[:0]
	for _, r := range l.Rows {
		if r.Day >= from {
			kept = append(kept, r)
		}
	}
	sortDaily(kept)
	l.Rows = kept
	dropped := len(kept) < n
	if l.TrimmedFrom != "" && l.TrimmedFrom <= from {
		l.TrimmedFrom, dropped = "", true // the window has passed it
	}
	if l.Rows == nil {
		l.Rows = []Daily{}
	}
	b, _ := json.Marshal(l)
	for len(b)+1 > maxLongFile && len(l.Rows) > 0 {
		need := len(b) + 1 - maxLongFile + 64 // and room for trimmedFrom
		i := 0
		for i < len(l.Rows) && need > 0 {
			d := l.Rows[i].Day
			for i < len(l.Rows) && l.Rows[i].Day == d {
				x, _ := json.Marshal(l.Rows[i])
				need -= len(x) + 1
				i++
			}
			l.TrimmedFrom = nextDay(d)
		}
		l.Rows, dropped = l.Rows[i:], true
		b, _ = json.Marshal(l)
	}
	return append(b, '\n'), dropped
}

// rollup sums perf.json's rows per local day, source and model, from day `from` on, across
// efforts, speed modes and parsers.
func rollup(rows []PerfRow, from string) []Daily {
	by := map[[3]string]int{}
	out := []Daily{}
	for i := range rows {
		r := &rows[i]
		if r.Day < from {
			continue
		}
		k := [3]string{r.Day, r.Source, r.Model}
		j, ok := by[k]
		if !ok {
			j, by[k] = len(out), len(out)
			out = append(out, Daily{Day: r.Day, Source: r.Source, Model: r.Model})
		}
		out[j].ObservedOutputTokens += r.ObservedOutputTokens
		out[j].ObservedRequests += r.ObservedRequests
	}
	sortDaily(out)
	return out
}

// mergeDaily adds src's rows from day `from` on into dst, keeping the larger figures per day,
// source and model, and reports whether dst grew.
func mergeDaily(dst, src []Daily, from string) ([]Daily, bool) {
	at := make(map[[3]string]int, len(dst))
	for i, r := range dst {
		at[[3]string{r.Day, r.Source, r.Model}] = i
	}
	changed := false
	for _, r := range src {
		if r.Day < from {
			continue
		}
		k := [3]string{r.Day, r.Source, r.Model}
		i, ok := at[k]
		if !ok {
			at[k] = len(dst)
			dst = append(dst, r)
			changed = true
			continue
		}
		x := &dst[i]
		if r.ObservedOutputTokens > x.ObservedOutputTokens {
			x.ObservedOutputTokens, changed = r.ObservedOutputTokens, true
		}
		if r.ObservedRequests > x.ObservedRequests {
			x.ObservedRequests, changed = r.ObservedRequests, true
		}
	}
	return dst, changed
}

func sortDaily(ds []Daily) {
	sort.Slice(ds, func(i, j int) bool {
		a, b := ds[i], ds[j]
		if a.Day != b.Day {
			return a.Day < b.Day
		}
		if a.Source != b.Source {
			return a.Source < b.Source
		}
		return a.Model < b.Model
	})
}

// dayStart: the start of t's local day, in UTC.
func dayStart(t time.Time) time.Time {
	l := t.Local()
	return time.Date(l.Year(), l.Month(), l.Day(), 0, 0, 0, 0, time.Local).UTC()
}

// nextDay: the local day after d (YYYY-MM-DD).
func nextDay(d string) string {
	t, err := time.ParseInLocation("2006-01-02", d, time.Local)
	if err != nil {
		return d
	}
	return time.Date(t.Year(), t.Month(), t.Day()+1, 12, 0, 0, 0, time.Local).Format("2006-01-02")
}
