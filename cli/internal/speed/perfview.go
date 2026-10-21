package speed

import (
	"math"
	"sort"
	"strings"
	"time"
)

// PerfView projects the performance ledger for the personal snapshot: per configuration over the
// recent 7 and 30 local calendar days, per day and model, and one reading per engine. Every
// figure is a ratio of sums or a quantile of merged histograms; no rate or median is averaged.
type PerfView struct {
	Ledger    PerfLedger
	OK        bool // false: the ledger is there but unreadable
	Recording bool
	Now       time.Time
}

const (
	Recent7d     = "recent7d"
	Recent30d    = "recent30d"
	fresh        = 24 * time.Hour
	staleAfter   = 7 * 24 * time.Hour
	histScheme   = "log1.1/v1"
	quantileName = "log1.1-centre-lower"
)

type Timing struct {
	Start   string `json:"start"`
	First   string `json:"first"`
	End     string `json:"end"`
	Quality string `json:"quality"`
}

type Basis struct {
	TokenBasis string `json:"tokenBasis"`
	Timing     Timing `json:"timing"`
	Quantile   string `json:"quantile"`
}

// basisOf: what the parser's timestamps stand for. They are when the harness logged a line, a
// proxy for the model's own timing.
func basisOf(parser string) Basis {
	t := Timing{Start: "input-logged", First: "item-started-at", End: "usage-logged", Quality: "harness-log-proxy"}
	if parser == ParserClaude {
		t.First, t.End = "thinking-start", "last-block-logged"
	}
	return Basis{TokenBasis: "harness-reported-output", Timing: t, Quantile: quantileName}
}

type PerfSums struct {
	ObservedRequests         int   `json:"observedRequests"`
	ObservedOutputTokens     int64 `json:"observedOutputTokens"`
	EligibleRequests         int   `json:"eligibleRequests"`
	EligibleOutputTokens     int64 `json:"eligibleOutputTokens"`
	GenMs                    int64 `json:"genMs"`
	Turns                    int   `json:"turns"`
	TurnMs                   int64 `json:"turnMs"`
	TurnOutputTokens         int64 `json:"turnOutputTokens"`
	MixedConfigTurnsExcluded int   `json:"mixedConfigTurnsExcluded"`
}

func (s *PerfSums) add(r *PerfRow) {
	s.ObservedRequests += r.ObservedRequests
	s.ObservedOutputTokens += r.ObservedOutputTokens
	s.EligibleRequests += r.EligibleRequests
	s.EligibleOutputTokens += r.EligibleOutputTokens
	s.GenMs += r.GenMs
	s.Turns += r.Turns
	s.TurnMs += r.TurnMs
	s.TurnOutputTokens += r.TurnOutputTokens
	s.MixedConfigTurnsExcluded += r.MixedConfigTurnsExcluded
}

// HistOut is a histogram as published: bucket k ≥ 1 holds [1.1^k, 1.1^(k+1)), bucket 0 every
// value below 1.1. Histograms merge by adding counts, only with the same scheme and unit.
type HistOut struct {
	Scheme string `json:"scheme"`
	Unit   string `json:"unit"`
	Counts Hist   `json:"counts"`
}

type PerfHists struct {
	TTFTMs         HistOut `json:"ttftMs"`
	TurnMsHist     HistOut `json:"turnMsHist"`
	TurnTokensHist HistOut `json:"turnTokensHist"`
}

// Metric: value is set only when status is ok. status: ok | insufficient (n < min) | stale (the
// newest sample is older than 7 days) | unavailable (the source cannot give it, or the ledger is
// unreadable; see reason) | off (recording is off).
type Metric struct {
	Value  *float64 `json:"value"`
	Status string   `json:"status"`
	N      int      `json:"n"`
	Min    int      `json:"min"`
	Reason string   `json:"reason,omitempty"`
}

type PerfMetrics struct {
	GenerationTps Metric `json:"generationTps"`
	TTFTMs        Metric `json:"ttftMs"`
	WholeTurnTps  Metric `json:"wholeTurnTps"`
}

type PerfWindow struct {
	Sums    PerfSums    `json:"sums"`
	Hist    PerfHists   `json:"hist"`
	Metrics PerfMetrics `json:"metrics"`
}

type PerfWindows struct {
	Recent7d  PerfWindow `json:"recent7d"`
	Recent30d PerfWindow `json:"recent30d"`
}

// PerfStat is one configuration. Attribution is "unattributed": the samples belong to the
// harness, not to a verified subscription.
type PerfStat struct {
	Source       string      `json:"source"`
	Model        string      `json:"model"`
	EffortStatus string      `json:"effortStatus"`
	Effort       string      `json:"effort"`
	Speed        string      `json:"speed"`
	Parser       string      `json:"parser"`
	Eligibility  string      `json:"eligibility"`
	Basis        Basis       `json:"basis"`
	Attribution  string      `json:"attribution"`
	Since        time.Time   `json:"since"`
	LastAt       *time.Time  `json:"lastAt"`
	Freshness    string      `json:"freshness"` // fresh (≤ 24 h) | aging (≤ 7 d) | stale
	Windows      PerfWindows `json:"windows"`
}

// Daily is one local day of one model: what the parsers saw, across efforts, speed modes and
// parsers. It covers only the logs this CLI reads, not the account's consumption.
type Daily struct {
	Day                  string `json:"day"`
	Source               string `json:"source"`
	Model                string `json:"model"`
	ObservedOutputTokens int64  `json:"observedOutputTokens"`
	ObservedRequests     int    `json:"observedRequests"`
}

// DailyCoverage: the first day daily[] covers (the later of the ledger's start and 30 days ago;
// null without a ledger) and whether recording is on.
type DailyCoverage struct {
	From      *string `json:"from"`
	Recording bool    `json:"recording"`
}

// Rate is one reading of the generation rate for a session: of its own configuration (ConfigKey)
// or of all the harness's configurations (Scope "all-configurations"), over Window.
type Rate struct {
	ConfigKey   string     `json:"configKey,omitempty"`
	Source      string     `json:"source,omitempty"`
	Window      string     `json:"window"`
	Scope       string     `json:"scope,omitempty"`
	ConfigCount *int       `json:"configCount,omitempty"`
	Value       *float64   `json:"value"`
	Status      string     `json:"status"`
	N           int        `json:"n"`
	Min         int        `json:"min"`
	Reason      string     `json:"reason,omitempty"`
	LastAt      *time.Time `json:"lastAt"`
	Freshness   string     `json:"freshness,omitempty"`
}

type statKey struct{ source, model, effortStatus, effort, speed, parser, eligibility string }

func keyOf(r *PerfRow) statKey {
	return statKey{r.Source, r.Model, r.EffortStatus, r.Effort, r.Speed, r.Parser, r.Eligibility}
}

// ConfigKey: the configuration's key, as sessions[].tokenRate names it.
func (k statKey) String() string {
	return strings.Join([]string{k.source, k.model, k.effortStatus, k.effort, k.speed, k.parser, k.eligibility}, "|")
}

// windowFrom: the first local day of a window of n calendar days including today.
func windowFrom(now time.Time, n int) string {
	l := now.Local()
	return time.Date(l.Year(), l.Month(), l.Day()-(n-1), 12, 0, 0, 0, time.Local).Format("2006-01-02")
}

type acc struct {
	sums             PerfSums
	ttft, ms, tokens Hist
	lastAt           *time.Time
}

func (a *acc) add(r *PerfRow) {
	a.sums.add(r)
	a.ttft, a.ms, a.tokens = a.ttft.merge(r.TTFTMs), a.ms.merge(r.TurnMsHist), a.tokens.merge(r.TurnTokensHist)
	if r.LastAt != nil && (a.lastAt == nil || r.LastAt.After(*a.lastAt)) {
		t := *r.LastAt
		a.lastAt = &t
	}
}

// Stats: one entry per configuration with a row in the last 30 days, ordered by source, model,
// speed, effort and parser.
func (v PerfView) Stats() []PerfStat {
	out := []PerfStat{}
	if !v.OK {
		return out
	}
	from7, from30 := windowFrom(v.Now, 7), windowFrom(v.Now, 30)
	type both struct{ all, w7, w30 acc }
	by := map[statKey]*both{}
	var keys []statKey
	for i := range v.Ledger.Rows {
		r := &v.Ledger.Rows[i]
		k := keyOf(r)
		b := by[k]
		if b == nil {
			b = &both{}
			by[k] = b
			keys = append(keys, k)
		}
		b.all.add(r)
		if r.Day >= from30 {
			b.w30.add(r)
		}
		if r.Day >= from7 {
			b.w7.add(r)
		}
	}
	sort.Slice(keys, func(i, j int) bool {
		a, b := keys[i], keys[j]
		for _, x := range [][2]string{{a.source, b.source}, {a.model, b.model}, {a.speed, b.speed}, {a.effortStatus, b.effortStatus}, {a.effort, b.effort}, {a.parser, b.parser}, {a.eligibility, b.eligibility}} {
			if x[0] != x[1] {
				return x[0] < x[1]
			}
		}
		return false
	})
	for _, k := range keys {
		b := by[k]
		if b.w30.sums.ObservedRequests == 0 && b.w30.sums.MixedConfigTurnsExcluded == 0 {
			continue
		}
		out = append(out, PerfStat{Source: k.source, Model: k.model, EffortStatus: k.effortStatus, Effort: k.effort, Speed: k.speed, Parser: k.parser,
			Eligibility: k.eligibility, Basis: basisOf(k.parser), Attribution: "unattributed", Since: v.Ledger.Since, LastAt: b.all.lastAt,
			Freshness: v.freshness(b.all.lastAt), Windows: PerfWindows{Recent7d: v.window(&b.w7, b.all.lastAt), Recent30d: v.window(&b.w30, b.all.lastAt)}})
	}
	return out
}

func (v PerfView) freshness(last *time.Time) string {
	switch {
	case last == nil:
		return "stale"
	case v.Now.Sub(*last) <= fresh:
		return "fresh"
	case v.Now.Sub(*last) <= staleAfter:
		return "aging"
	}
	return "stale"
}

func (v PerfView) window(a *acc, last *time.Time) PerfWindow {
	w := PerfWindow{Sums: a.sums, Hist: PerfHists{TTFTMs: hist(a.ttft, "ms"), TurnMsHist: hist(a.ms, "ms"), TurnTokensHist: hist(a.tokens, "tokens")}}
	s := a.sums
	w.Metrics.GenerationTps = v.metric(s.EligibleRequests, s.ObservedRequests, func() float64 { return tps(s.EligibleOutputTokens, s.GenMs) }, last)
	w.Metrics.TTFTMs = v.metric(a.ttft.Count(), s.ObservedRequests, func() float64 { return math.Round(a.ttft.Median()) }, last)
	w.Metrics.WholeTurnTps = v.metric(s.Turns, 0, func() float64 { return tps(s.TurnOutputTokens, s.TurnMs) }, last)
	return w
}

func hist(h Hist, unit string) HistOut {
	if h == nil {
		h = Hist{}
	}
	return HistOut{Scheme: histScheme, Unit: unit, Counts: h}
}

// metric: n samples behind the value; observed > 0 with no sample at all means the source gives
// none (a Claude Code request without thinking has no first token).
func (v PerfView) metric(n, observed int, value func() float64, last *time.Time) Metric {
	m := Metric{N: n, Min: MinSamples}
	switch {
	case !v.OK:
		m.Status, m.Reason = "unavailable", "ledger-unreadable"
	case !v.Recording:
		m.Status = "off"
	case last != nil && v.Now.Sub(*last) > staleAfter:
		m.Status = "stale"
	case n == 0 && observed > 0:
		m.Status, m.Reason = "unavailable", "no-first-token"
	case n < MinSamples:
		m.Status = "insufficient"
	default:
		x := value()
		m.Status, m.Value = "ok", &x
	}
	return m
}

func tps(tokens, ms int64) float64 {
	if ms <= 0 {
		return 0
	}
	return math.Round(float64(tokens)/(float64(ms)/1000)*10) / 10
}

// Daily: per local day of the last 30 and model, summed from the ledger's rows. Days without rows
// are left out, not zero: the ledger cannot tell no activity from no coverage.
func (v PerfView) Daily() []Daily {
	out := []Daily{}
	if !v.OK {
		return out
	}
	from := windowFrom(v.Now, 30)
	if d := day(v.Ledger.Since); d > from {
		from = d // the legacy ledger is never mixed in
	}
	by := map[[3]string]*Daily{}
	var keys [][3]string
	for i := range v.Ledger.Rows {
		r := &v.Ledger.Rows[i]
		if r.Day < from {
			continue
		}
		k := [3]string{r.Day, r.Source, r.Model}
		d := by[k]
		if d == nil {
			d = &Daily{Day: r.Day, Source: r.Source, Model: r.Model}
			by[k] = d
			keys = append(keys, k)
		}
		d.ObservedOutputTokens += r.ObservedOutputTokens
		d.ObservedRequests += r.ObservedRequests
	}
	sort.Slice(keys, func(i, j int) bool {
		for x := range keys[i] {
			if keys[i][x] != keys[j][x] {
				return keys[i][x] < keys[j][x]
			}
		}
		return false
	})
	for _, k := range keys {
		out = append(out, *by[k])
	}
	return out
}

func (v PerfView) Coverage() DailyCoverage {
	c := DailyCoverage{Recording: v.Recording}
	if !v.OK || v.Ledger.Since.IsZero() {
		return c
	}
	from := windowFrom(v.Now, 30)
	if d := day(v.Ledger.Since); d > from {
		from = d
	}
	c.From = &from
	return c
}

func parserOf(source string) string {
	if source == "claude-code" {
		return ParserClaude
	}
	return ParserCodex
}

// TokenRate: the recent-7-day generation rate of the session's own configuration. An unreported
// effort gives none: the same unknown configuration is no proof of the same one. No other
// configuration stands in.
func (v PerfView) TokenRate(source, model, effort, speed string) Rate {
	status := "reported"
	if effort == "" {
		status = "unreported"
	}
	k := statKey{source, model, status, effort, speedMode(speed), parserOf(source), EligibilityV1}
	r := Rate{ConfigKey: k.String(), Window: Recent7d, Min: MinSamples}
	if effort == "" && v.OK {
		r.Status, r.Reason = "unavailable", "effort-unreported"
		return r
	}
	var a acc
	from := windowFrom(v.Now, 7)
	var last *time.Time
	for i := range v.Ledger.Rows {
		row := &v.Ledger.Rows[i]
		if keyOf(row) != k {
			continue
		}
		var all acc
		all.add(row)
		if all.lastAt != nil && (last == nil || all.lastAt.After(*last)) {
			last = all.lastAt
		}
		if row.Day >= from {
			a.add(row)
		}
	}
	m := v.metric(a.sums.EligibleRequests, a.sums.ObservedRequests, func() float64 { return tps(a.sums.EligibleOutputTokens, a.sums.GenMs) }, last)
	r.Value, r.Status, r.N, r.Reason, r.LastAt = m.Value, m.Status, m.N, m.Reason, last
	if last != nil {
		r.Freshness = v.freshness(last)
	}
	return r
}

// WorkloadRate: the recent-7-day generation rate of all the harness's configurations together,
// as a ratio of their sums. It describes what this user's mix produced; it is not a plan's speed,
// and it moves when the mix changes.
func (v PerfView) WorkloadRate(source string) Rate {
	r := Rate{Source: source, Window: Recent7d, Scope: "all-configurations", Min: MinSamples}
	var a acc
	configs := map[statKey]bool{}
	from := windowFrom(v.Now, 7)
	var last *time.Time
	for i := range v.Ledger.Rows {
		row := &v.Ledger.Rows[i]
		if row.Source != source {
			continue
		}
		if row.LastAt != nil && (last == nil || row.LastAt.After(*last)) {
			t := *row.LastAt
			last = &t
		}
		if row.Day >= from {
			a.add(row)
			if row.ObservedRequests > 0 {
				configs[keyOf(row)] = true
			}
		}
	}
	n := len(configs)
	r.ConfigCount = &n
	m := v.metric(a.sums.EligibleRequests, a.sums.ObservedRequests, func() float64 { return tps(a.sums.EligibleOutputTokens, a.sums.GenMs) }, last)
	r.Value, r.Status, r.N, r.Reason, r.LastAt = m.Value, m.Status, m.N, m.Reason, last
	if last != nil {
		r.Freshness = v.freshness(last)
	}
	return r
}

// Boundaries: when the clock alone changes the view: each configuration's newest sample turning a
// day and a week old, and local midnight, which moves the calendar windows.
func (v PerfView) Boundaries() []time.Time {
	if !v.OK || len(v.Ledger.Rows) == 0 {
		return nil
	}
	l := v.Now.Local()
	out := []time.Time{time.Date(l.Year(), l.Month(), l.Day()+1, 0, 0, 0, 0, time.Local)}
	for i := range v.Ledger.Rows {
		if t := v.Ledger.Rows[i].LastAt; t != nil {
			out = append(out, t.Add(fresh), t.Add(staleAfter))
		}
	}
	return out
}
