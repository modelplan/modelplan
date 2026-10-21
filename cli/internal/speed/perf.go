package speed

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"time"
)

// The performance ledger, <cache>/observed/perf.json, runs beside speed.json and never merges with
// it. Its rows also count every request the parsers saw, keep turn sums and the time of the newest
// sample, and say which parser and which validity rule produced them, so their figures are sums
// that add up across days rather than rates. It starts at Since: only turns that started at or
// after it are counted, so log content read before it can never be counted again. speed.json keeps
// being written as before, by this CLI and older ones.

const (
	PerfKeep = 35 * 24 * time.Hour // a 30-day view stays complete on any day
	// Parsers and the validity rule of a generation sample; rows of different ones never merge.
	ParserCodex   = "codex-rollout/1"
	ParserClaude  = "claude-transcript/1"
	EligibilityV1 = "gen-v1"
)

// PerfLedger is perf.json's content.
type PerfLedger struct {
	SchemaVersion int               `json:"schemaVersion"`
	Since         time.Time         `json:"since"` // UTC, when the file was created
	Rows          []PerfRow         `json:"rows"`
	Sessions      []PerfSession     `json:"sessions,omitempty"`
	Files         map[string]Cursor `json:"files,omitempty"`
}

// PerfSession is one harness session (a Claude Code transcript, a Codex thread), known only by a
// random reference. It holds no title, path or session id: Key is the log's file key, as the
// cursors use, and never leaves this file.
type PerfSession struct {
	Ref     string       `json:"ref"`
	Key     string       `json:"key"`
	Source  string       `json:"source"`
	FirstAt time.Time    `json:"firstAt"` // its first counted turn's start, to the minute
	LastAt  time.Time    `json:"lastAt"`  // its newest sample's completion, to the minute
	Days    []SessionDay `json:"days"`
}

// SessionDay: what one configuration of a session produced on one local day.
type SessionDay struct {
	Day                  string `json:"day"`
	Model                string `json:"model"`
	EffortStatus         string `json:"effortStatus"`
	Effort               string `json:"effort,omitempty"`
	Speed                string `json:"speed,omitempty"`
	ObservedRequests     int    `json:"observedRequests"`
	ObservedOutputTokens int64  `json:"observedOutputTokens"`
}

// PerfRow is one local day of one configuration, as one parser read it.
type PerfRow struct {
	Day          string `json:"day"` // local date of the turns' start, YYYY-MM-DD
	Source       string `json:"source"`
	Model        string `json:"model"`
	EffortStatus string `json:"effortStatus"`     // reported | unreported
	Effort       string `json:"effort,omitempty"` // native key; "" when unreported
	Speed        string `json:"speed,omitempty"`
	Parser       string `json:"parser"`
	Eligibility  string `json:"eligibility"`
	// Every request the parser saw in a finished turn, counted once, eligible or not.
	ObservedRequests     int   `json:"observedRequests"`
	ObservedOutputTokens int64 `json:"observedOutputTokens"`
	// The requests that pass Eligibility: the basis of the generation rate.
	EligibleRequests     int   `json:"eligibleRequests"`
	EligibleOutputTokens int64 `json:"eligibleOutputTokens"`
	GenMs                int64 `json:"genMs"`
	// Finished turns under this one configuration, tools included; a turn whose requests ran under
	// more than one configuration is only counted as excluded.
	Turns                    int   `json:"turns"`
	TurnMs                   int64 `json:"turnMs"`
	TurnOutputTokens         int64 `json:"turnOutputTokens"`
	MixedConfigTurnsExcluded int   `json:"mixedConfigTurnsExcluded"`
	TTFTMs                   Hist  `json:"ttftMs,omitempty"`
	TurnMsHist               Hist  `json:"turnMsHist,omitempty"`
	TurnTokensHist           Hist  `json:"turnTokensHist,omitempty"`
	// LastAt: when the newest sample in the row completed (UTC, to the minute).
	LastAt *time.Time `json:"lastAt,omitempty"`
}

// PerfPath is the ledger file.
func PerfPath(cache string) string { return filepath.Join(cache, "observed", "perf.json") }

// LoadPerf reads the ledger. A missing file is a new, empty ledger (zero Since). ok is false when
// the file is there but cannot be used (unreadable, too large, another schema or no Since); it is
// then left as it is and nothing is reported from it.
func LoadPerf(cache string) (l PerfLedger, ok bool) {
	b, err := os.ReadFile(PerfPath(cache))
	if errors.Is(err, os.ErrNotExist) {
		return PerfLedger{SchemaVersion: 1}, true
	}
	if err != nil || len(b) > maxFile {
		return PerfLedger{}, false
	}
	if json.Unmarshal(b, &l) != nil || l.SchemaVersion != 1 || l.Since.IsZero() {
		return PerfLedger{}, false
	}
	return l, true
}

// observePerf: as observe, for perf.json. A new ledger is written even with nothing in it yet, so
// that its Since holds.
func observePerf(cache string, now time.Time, f func(*PerfLedger) bool) error {
	if Off() {
		return nil
	}
	unlock, ok := lock(cache, "perf.lock")
	if !ok {
		return nil
	}
	defer unlock()
	l, ok := LoadPerf(cache)
	if !ok {
		return nil // not ours to overwrite
	}
	created := l.Since.IsZero()
	if created {
		l.Since = now.UTC().Truncate(time.Second)
	}
	if l.Files == nil {
		l.Files = map[string]Cursor{}
	}
	if !f(&l) && !created {
		return nil
	}
	b := l.prune(now)
	return write(PerfPath(cache), b)
}

func (l *PerfLedger) scan(path, source, parser string, p parser, now time.Time) bool {
	done, changed := scanLog(l.Files, path, p, now)
	for _, t := range done {
		l.add(source, parser, t)
		l.addSession(fileKey(path), source, t)
	}
	return changed
}

// maxSessions: the sessions kept; the ones last active longest ago go first.
const maxSessions = 2000

func (l *PerfLedger) addSession(key, source string, t turn) {
	if t.at.IsZero() || t.at.Before(l.Since) || len(t.all) == 0 {
		return
	}
	var s *PerfSession
	for i := range l.Sessions {
		if l.Sessions[i].Key == key && l.Sessions[i].Source == source {
			s = &l.Sessions[i]
		}
	}
	start := t.at.UTC().Truncate(time.Minute)
	if s == nil {
		l.Sessions = append(l.Sessions, PerfSession{Ref: newRef(), Key: key, Source: source, FirstAt: start, LastAt: start})
		s = &l.Sessions[len(l.Sessions)-1]
	}
	if start.Before(s.FirstAt) {
		s.FirstAt = start
	}
	d := day(t.at)
	for _, q := range t.all {
		if q.cfg.model == "" {
			continue
		}
		status := "reported"
		if q.cfg.effort == "" {
			status = "unreported"
		}
		var x *SessionDay
		for i := range s.Days {
			y := &s.Days[i]
			if y.Day == d && y.Model == q.cfg.model && y.EffortStatus == status && y.Effort == q.cfg.effort && y.Speed == q.cfg.speed {
				x = y
			}
		}
		if x == nil {
			s.Days = append(s.Days, SessionDay{Day: d, Model: q.cfg.model, EffortStatus: status, Effort: q.cfg.effort, Speed: q.cfg.speed})
			x = &s.Days[len(s.Days)-1]
		}
		x.ObservedRequests++
		x.ObservedOutputTokens += q.out
		if e := q.end.UTC().Truncate(time.Minute); e.After(s.LastAt) {
			s.LastAt = e
		}
	}
	if e := t.at.Add(t.dur).UTC().Truncate(time.Minute); t.dur > 0 && e.After(s.LastAt) {
		s.LastAt = e
	}
}

// newRef: a random reference, so a session is known here without any id of its own.
func newRef() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func (l *PerfLedger) add(source, parser string, t turn) {
	if t.at.IsZero() || t.at.Before(l.Since) {
		return // started before the ledger did
	}
	d := day(t.at)
	for _, q := range t.all {
		if q.cfg.model == "" {
			continue
		}
		r := l.row(d, source, parser, q.cfg)
		r.ObservedRequests++
		r.ObservedOutputTokens += q.out
		if q.ttft > 0 && q.ttft <= maxTTFT {
			r.TTFTMs = r.TTFTMs.add(float64(q.ttft.Milliseconds()))
		}
		if q.eligible() {
			r.EligibleRequests++
			r.EligibleOutputTokens += q.out
			r.GenMs += q.gen.Milliseconds()
		}
		r.seen(q.end)
	}
	if t.cfg.model == "" {
		return
	}
	r := l.row(d, source, parser, t.cfg)
	if t.mixed {
		r.MixedConfigTurnsExcluded++
		return
	}
	if t.dur > 0 && t.dur <= maxTurn && len(t.reqs) > 0 {
		r.Turns++
		r.TurnMs += t.dur.Milliseconds()
		r.TurnOutputTokens += t.out
		r.TurnMsHist = r.TurnMsHist.add(float64(t.dur.Milliseconds()))
		r.TurnTokensHist = r.TurnTokensHist.add(float64(t.out))
		r.seen(t.at.Add(t.dur))
	}
}

func (r *PerfRow) seen(t time.Time) {
	if t.IsZero() {
		return
	}
	t = t.UTC().Truncate(time.Minute)
	if r.LastAt == nil || t.After(*r.LastAt) {
		r.LastAt = &t
	}
}

func (l *PerfLedger) row(d, source, parser string, c config) *PerfRow {
	status := "reported"
	if c.effort == "" {
		status = "unreported"
	}
	for i := range l.Rows {
		r := &l.Rows[i]
		if r.Day == d && r.Source == source && r.Model == c.model && r.EffortStatus == status && r.Effort == c.effort && r.Speed == c.speed &&
			r.Parser == parser && r.Eligibility == EligibilityV1 {
			return r
		}
	}
	l.Rows = append(l.Rows, PerfRow{Day: d, Source: source, Model: c.model, EffortStatus: status, Effort: c.effort, Speed: c.speed, Parser: parser, Eligibility: EligibilityV1})
	return &l.Rows[len(l.Rows)-1]
}

// prune keeps PerfKeep, at most maxRows rows and maxFile bytes (dropping the oldest days first),
// and returns the file's content.
func (l *PerfLedger) prune(now time.Time) []byte {
	from := day(now.Add(-PerfKeep))
	kept := l.Rows[:0]
	for _, r := range l.Rows {
		if r.Day >= from {
			kept = append(kept, r)
		}
	}
	sort.SliceStable(kept, func(i, j int) bool { return kept[i].Day < kept[j].Day })
	if len(kept) > maxRows {
		kept = kept[len(kept)-maxRows:]
	}
	l.Rows = kept
	sessions := l.Sessions[:0]
	for _, x := range l.Sessions {
		days := x.Days[:0]
		for _, d := range x.Days {
			if d.Day >= from {
				days = append(days, d)
			}
		}
		if x.Days = days; len(days) > 0 {
			sessions = append(sessions, x)
		}
	}
	sort.SliceStable(sessions, func(i, j int) bool { return sessions[i].LastAt.Before(sessions[j].LastAt) })
	if len(sessions) > maxSessions {
		sessions = sessions[len(sessions)-maxSessions:]
	}
	l.Sessions = sessions
	for k, c := range l.Files {
		if c.Seen < from {
			delete(l.Files, k)
		}
	}
	for {
		b, _ := json.Marshal(l)
		if len(b) < maxFile || (len(l.Rows) == 0 && len(l.Sessions) == 0) {
			return append(b, '\n')
		}
		l.Rows = l.Rows[len(l.Rows)/10:]
		l.Sessions = l.Sessions[len(l.Sessions)/10:]
		if len(l.Rows) < 10 && len(l.Sessions) < 10 {
			l.Rows, l.Sessions = nil, nil
		}
	}
}
