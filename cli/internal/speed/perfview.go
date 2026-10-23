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
	Ledger PerfLedger
	OK     bool // false: the ledger is there but unreadable
	// Long: the long-term daily ledger (daily-long.json). LongOK false: it was not given or cannot
	// be read; dailyLong then holds what perf.json does.
	Long      LongLedger
	LongOK    bool
	Recording bool
	Now       time.Time
}

const (
	Today        = "today"
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
	ObservedRequests         int    `json:"observedRequests"`
	ObservedOutputTokens     int64  `json:"observedOutputTokens"`
	InputTokens              *int64 `json:"inputTokens"`
	CacheReadTokens          *int64 `json:"cacheReadTokens"`
	CacheWriteTokens         *int64 `json:"cacheWriteTokens"`
	EligibleRequests         int    `json:"eligibleRequests"`
	EligibleOutputTokens     int64  `json:"eligibleOutputTokens"`
	GenMs                    int64  `json:"genMs"`
	Turns                    int    `json:"turns"`
	TurnMs                   int64  `json:"turnMs"`
	TurnOutputTokens         int64  `json:"turnOutputTokens"`
	MixedConfigTurnsExcluded int    `json:"mixedConfigTurnsExcluded"`
}

func (s *PerfSums) add(r *PerfRow) {
	if r.ObservedRequests > 0 {
		s.InputTokens = sumToken(s.InputTokens, r.InputTokens, s.ObservedRequests)
		s.CacheReadTokens = sumToken(s.CacheReadTokens, r.CacheReadTokens, s.ObservedRequests)
		s.CacheWriteTokens = sumToken(s.CacheWriteTokens, r.CacheWriteTokens, s.ObservedRequests)
	}
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
	Today     PerfWindow `json:"today"`
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
	InputTokens          *int64 `json:"inputTokens"`
	CacheReadTokens      *int64 `json:"cacheReadTokens"`
	CacheWriteTokens     *int64 `json:"cacheWriteTokens"`
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
	type both struct{ all, today, w7, w30 acc }
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
		if r.Day == day(v.Now) {
			b.today.add(r)
		}
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
			Freshness: v.freshness(b.all.lastAt), Windows: PerfWindows{Today: v.window(&b.today, b.today.lastAt), Recent7d: v.window(&b.w7, b.all.lastAt), Recent30d: v.window(&b.w30, b.all.lastAt)}})
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
	if !v.OK {
		return []Daily{}
	}
	from := windowFrom(v.Now, 30)
	if d := day(v.Ledger.Since); d > from {
		from = d // the legacy ledger is never mixed in
	}
	return rollup(v.Ledger.Rows, from)
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

// DailyLong: as Daily, per local day of the last LongDays, from daily-long.json together with what
// perf.json holds now (the larger figures of the two, as the ledger itself keeps them). Without a
// usable daily-long.json it is what perf.json holds: the days it keeps whole.
func (v PerfView) DailyLong() []Daily {
	from, ok := v.longFrom()
	if !ok {
		return []Daily{}
	}
	var out []Daily
	if v.longUsable() {
		for _, r := range v.Long.Rows {
			if r.Day >= from {
				out = append(out, r)
			}
		}
	}
	out, _ = mergeDaily(out, rollup(v.Ledger.Rows, from), from)
	if out == nil {
		return []Daily{}
	}
	sortDaily(out)
	return out
}

// LongCoverage: the first day dailyLong covers and whether recording is on.
func (v PerfView) LongCoverage() DailyCoverage {
	c := DailyCoverage{Recording: v.Recording}
	if from, ok := v.longFrom(); ok {
		c.From = &from
	}
	return c
}

func (v PerfView) longUsable() bool { return v.LongOK && !v.Long.Since.IsZero() }

// longFrom: the latest of LongDays ago and where the ledgers' coverage starts: daily-long.json's
// since (or the day after its last size trim), else perf.json's since and the days it keeps whole.
// None while perf.json cannot be read (nothing is recorded then) or neither ledger has started.
func (v PerfView) longFrom() (string, bool) {
	if !v.OK {
		return "", false
	}
	var start string
	switch {
	case v.longUsable():
		start = v.Long.from()
	case !v.Ledger.Since.IsZero():
		start = max(day(v.Ledger.Since), day(v.Now.Add(-PerfKeep)))
	default:
		return "", false
	}
	return max(start, windowFrom(v.Now, LongDays)), true
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
// day and a week old, and local midnight, which moves the calendar windows (dailyLong's too).
func (v PerfView) Boundaries() []time.Time {
	if !v.OK || len(v.Ledger.Rows) == 0 && len(v.Ledger.Live) == 0 && len(v.Ledger.Hourly) == 0 && (!v.longUsable() || len(v.Long.Rows) == 0) {
		return nil
	}
	l := v.Now.Local()
	out := []time.Time{time.Date(l.Year(), l.Month(), l.Day()+1, 0, 0, 0, 0, time.Local)}
	for i := range v.Ledger.Rows {
		if t := v.Ledger.Rows[i].LastAt; t != nil {
			out = append(out, t.Add(fresh), t.Add(staleAfter))
		}
	}
	for _, x := range v.Ledger.Live {
		out = append(out, x.LastAt.Add(LiveWithin+time.Nanosecond))
		for _, q := range x.Samples {
			out = append(out, q.End.Add(time.Minute+time.Nanosecond))
		}
	}
	return out
}

// SessionConfig: one configuration's part of a ranked session.
type SessionConfig struct {
	Model                string `json:"model"`
	EffortStatus         string `json:"effortStatus"`
	Effort               string `json:"effort"`
	Speed                string `json:"speed"`
	ObservedOutputTokens int64  `json:"observedOutputTokens"`
	// Share: of the session's or project's observed output in the window.
	Share float64 `json:"share"`
	// RecommendedEffort: the published ★ effort of the model, when the publication has one (the
	// snapshot fills it in).
	RecommendedEffort *string `json:"recommendedEffort,omitempty"`
}

// RankedSession is one session in a ranking. Share is its part of the observed output tokens of
// all sessions in the window: of what this CLI saw, not of any plan.
type RankedSession struct {
	Ref                  string          `json:"ref"`
	Source               string          `json:"source"`
	ProjectRef           *string         `json:"projectRef"`      // null when the log records no working directory
	SubscriptionRef      *string         `json:"subscriptionRef"` // null when unknown
	FirstAt              time.Time       `json:"firstAt"`
	LastAt               time.Time       `json:"lastAt"`
	ObservedOutputTokens int64           `json:"observedOutputTokens"`
	ObservedRequests     int             `json:"observedRequests"`
	Share                float64         `json:"share"`
	Configs              []SessionConfig `json:"configs"` // the largest first, at most 3
}

type SessionWindow struct {
	Sessions                  int             `json:"sessions"` // with observed output in the window
	TotalObservedOutputTokens int64           `json:"totalObservedOutputTokens"`
	Top                       []RankedSession `json:"top"`
}

// SessionRanking: the sessions that produced the most observed output tokens, over the recent 7
// and 30 local days.
type SessionRanking struct {
	Measure   string        `json:"measure"` // observed-output-tokens
	Recent7d  SessionWindow `json:"recent7d"`
	Recent30d SessionWindow `json:"recent30d"`
}

const rankedSessions = 5

func (v PerfView) Ranking() SessionRanking {
	return SessionRanking{Measure: "observed-output-tokens", Recent7d: v.rank(windowFrom(v.Now, 7)), Recent30d: v.rank(windowFrom(v.Now, 30))}
}

func (v PerfView) rank(from string) SessionWindow {
	w := SessionWindow{Top: []RankedSession{}}
	if !v.OK {
		return w
	}
	var all []RankedSession
	for _, s := range v.Ledger.Sessions {
		r := RankedSession{Ref: s.Ref, Source: s.Source, ProjectRef: refOrNil(s.ProjectRef), SubscriptionRef: refOrNil(s.SubscriptionRef), FirstAt: s.FirstAt, LastAt: s.LastAt}
		var c configSums
		for _, d := range s.Days {
			if d.Day >= from {
				r.ObservedOutputTokens += d.ObservedOutputTokens
				r.ObservedRequests += d.ObservedRequests
				c.add(d)
			}
		}
		if r.ObservedOutputTokens == 0 {
			continue
		}
		r.Configs = c.top()
		w.TotalObservedOutputTokens += r.ObservedOutputTokens
		all = append(all, r)
	}
	sort.SliceStable(all, func(i, j int) bool {
		if all[i].ObservedOutputTokens != all[j].ObservedOutputTokens {
			return all[i].ObservedOutputTokens > all[j].ObservedOutputTokens
		}
		return all[i].LastAt.After(all[j].LastAt)
	})
	w.Sessions = len(all)
	for i := range all {
		if i == rankedSessions {
			break
		}
		all[i].Share = math.Round(float64(all[i].ObservedOutputTokens)/float64(w.TotalObservedOutputTokens)*1000) / 1000
		w.Top = append(w.Top, all[i])
	}
	return w
}

func contains(xs []string, x string) bool {
	for _, v := range xs {
		if v == x {
			return true
		}
	}
	return false
}

func refOrNil(ref string) *string {
	if ref == "" {
		return nil
	}
	return &ref
}

// configSums adds up observed output per configuration, in first-seen order.
type configSums struct {
	by   map[[4]string]*SessionConfig
	keys [][4]string
}

func (c *configSums) add(d SessionDay) {
	if c.by == nil {
		c.by = map[[4]string]*SessionConfig{}
	}
	k := [4]string{d.Model, d.EffortStatus, d.Effort, d.Speed}
	if c.by[k] == nil {
		c.by[k] = &SessionConfig{Model: d.Model, EffortStatus: d.EffortStatus, Effort: d.Effort, Speed: d.Speed}
		c.keys = append(c.keys, k)
	}
	c.by[k].ObservedOutputTokens += d.ObservedOutputTokens
}

// top: the three largest configurations, each with its share of the whole.
func (c *configSums) top() []SessionConfig {
	out := []SessionConfig{}
	var total int64
	for _, k := range c.keys {
		out = append(out, *c.by[k])
		total += c.by[k].ObservedOutputTokens
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].ObservedOutputTokens > out[j].ObservedOutputTokens })
	if len(out) > 3 {
		out = out[:3]
	}
	for i := range out {
		if total > 0 {
			out[i].Share = math.Round(float64(out[i].ObservedOutputTokens)/float64(total)*1000) / 1000
		}
	}
	return out
}

// RankedProject is one project in a ranking: the sessions under one project reference, summed.
// Label is the project folder's name, only while project labels are on; the desktop otherwise
// names projects by their rank.
type RankedProject struct {
	Ref      string  `json:"ref"`
	Label    *string `json:"label"`
	Sessions int     `json:"sessions"` // with observed output in the window
	// SubscriptionRefs: the subscriptions its sessions ran under, as far as known, sorted.
	SubscriptionRefs     []string        `json:"subscriptionRefs"`
	LastAt               time.Time       `json:"lastAt"`
	ObservedOutputTokens int64           `json:"observedOutputTokens"`
	ObservedRequests     int             `json:"observedRequests"`
	Share                float64         `json:"share"`
	Configs              []SessionConfig `json:"configs"` // the largest first, at most 3
}

type ProjectWindow struct {
	Projects int `json:"projects"` // with observed output in the window
	// TotalObservedOutputTokens: of every session in the window, with or without a project;
	// UnattributedOutputTokens: the part from sessions whose log records no working directory.
	TotalObservedOutputTokens int64           `json:"totalObservedOutputTokens"`
	UnattributedOutputTokens  int64           `json:"unattributedOutputTokens"`
	Top                       []RankedProject `json:"top"`
}

// ProjectRanking: the projects whose sessions produced the most observed output tokens, over the
// recent 7 and 30 local days.
type ProjectRanking struct {
	Measure   string        `json:"measure"` // observed-output-tokens
	Recent7d  ProjectWindow `json:"recent7d"`
	Recent30d ProjectWindow `json:"recent30d"`
}

const rankedProjects = 10

func (v PerfView) Projects() ProjectRanking {
	return ProjectRanking{Measure: "observed-output-tokens", Recent7d: v.projects(windowFrom(v.Now, 7)), Recent30d: v.projects(windowFrom(v.Now, 30))}
}

func (v PerfView) projects(from string) ProjectWindow {
	w := ProjectWindow{Top: []RankedProject{}}
	if !v.OK {
		return w
	}
	type acc struct {
		p RankedProject
		c configSums
	}
	by := map[string]*acc{}
	var order []string
	for _, s := range v.Ledger.Sessions {
		var out int64
		var reqs int
		for _, d := range s.Days {
			if d.Day >= from {
				out += d.ObservedOutputTokens
				reqs += d.ObservedRequests
			}
		}
		if out == 0 {
			continue
		}
		w.TotalObservedOutputTokens += out
		if s.ProjectRef == "" {
			w.UnattributedOutputTokens += out
			continue
		}
		a := by[s.ProjectRef]
		if a == nil {
			a = &acc{p: RankedProject{Ref: s.ProjectRef}}
			by[s.ProjectRef] = a
			order = append(order, s.ProjectRef)
		}
		a.p.Sessions++
		if s.SubscriptionRef != "" && !contains(a.p.SubscriptionRefs, s.SubscriptionRef) {
			a.p.SubscriptionRefs = append(a.p.SubscriptionRefs, s.SubscriptionRef)
		}
		a.p.ObservedOutputTokens += out
		a.p.ObservedRequests += reqs
		if s.LastAt.After(a.p.LastAt) {
			a.p.LastAt = s.LastAt
		}
		if s.ProjectLabel != "" && a.p.Label == nil {
			l := s.ProjectLabel
			a.p.Label = &l
		}
		for _, d := range s.Days {
			if d.Day >= from {
				a.c.add(d)
			}
		}
	}
	all := make([]RankedProject, 0, len(order))
	for _, k := range order {
		a := by[k]
		a.p.Configs = a.c.top()
		if a.p.SubscriptionRefs == nil {
			a.p.SubscriptionRefs = []string{}
		}
		sort.Strings(a.p.SubscriptionRefs)
		all = append(all, a.p)
	}
	sort.SliceStable(all, func(i, j int) bool {
		if all[i].ObservedOutputTokens != all[j].ObservedOutputTokens {
			return all[i].ObservedOutputTokens > all[j].ObservedOutputTokens
		}
		return all[i].LastAt.After(all[j].LastAt)
	})
	w.Projects = len(all)
	for i := range all {
		if i == rankedProjects {
			break
		}
		all[i].Share = math.Round(float64(all[i].ObservedOutputTokens)/float64(w.TotalObservedOutputTokens)*1000) / 1000
		w.Top = append(w.Top, all[i])
	}
	return w
}

// LatestProject: the project of the harness's most recently active session, "" when unknown.
func (v PerfView) LatestProject(source string) string {
	var pick *PerfSession
	for i := range v.Ledger.Sessions {
		s := &v.Ledger.Sessions[i]
		if s.Source == source && (pick == nil || s.LastAt.After(pick.LastAt)) {
			pick = s
		}
	}
	if pick == nil {
		return ""
	}
	return pick.ProjectRef
}

// LastCompleted: when the harness's newest counted request or turn completed (to the minute);
// nil when none is known.
func (v PerfView) LastCompleted(source string) *time.Time {
	var last *time.Time
	for i := range v.Ledger.Rows {
		r := &v.Ledger.Rows[i]
		if r.Source == source && r.LastAt != nil && (last == nil || r.LastAt.After(*last)) {
			t := *r.LastAt
			last = &t
		}
	}
	return last
}
