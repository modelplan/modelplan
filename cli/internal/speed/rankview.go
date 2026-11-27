package speed

import (
	"sort"
	"time"
)

// Usage rankings (owner decision D470): every session and every project ranked by one measure, total tokens
// (input + output + cache, the ccusage definition), over today and the recent 7 and 30 local days. Each row
// carries its share of the window's total, an estimated ≈$ and its project kind. Nothing here is stored.

// RankCap: rows listed per window; the rest are summed into Other.
const RankCap = 200

// TokenSums is a row's tokens in a window. Total is the sum of every day whose parts are all known; Complete is
// false when some day was recorded before its input and cache sums were kept (that day then adds nothing to
// Total, never its output alone). Input, CacheRead and CacheWrite add only the days that have them.
type TokenSums struct {
	Total      int64 `json:"total"`
	Input      int64 `json:"input"`
	Output     int64 `json:"output"`
	CacheRead  int64 `json:"cacheRead"`
	CacheWrite int64 `json:"cacheWrite"`
	Complete   bool  `json:"complete"`
}

func (t *TokenSums) addDay(d SessionDay) {
	t.Output = sat(t.Output, max(0, d.ObservedOutputTokens))
	if total, ok := d.CompleteTotal(); ok {
		t.Total = sat(t.Total, total)
	} else {
		t.Complete = false
	}
	if d.Kinds != nil {
		for _, p := range []struct {
			from *int64
			to   *int64
		}{{d.Kinds.InputTokens, &t.Input}, {d.Kinds.CacheReadTokens, &t.CacheRead}, {d.Kinds.CacheWriteTokens, &t.CacheWrite}} {
			if p.from != nil && *p.from > 0 {
				*p.to = sat(*p.to, *p.from)
			}
		}
	}
}

func (t *TokenSums) merge(o TokenSums) {
	t.Total, t.Input, t.Output = sat(t.Total, o.Total), sat(t.Input, o.Input), sat(t.Output, o.Output)
	t.CacheRead, t.CacheWrite = sat(t.CacheRead, o.CacheRead), sat(t.CacheWrite, o.CacheWrite)
	t.Complete = t.Complete && o.Complete
}

// Cost states: priced (every token has a price), partial (some do), unpriced (none; the cost is nil, never $0).
const (
	CostPriced   = "priced"
	CostPartial  = "partial"
	CostUnpriced = "unpriced"
)

// Cost is ≈USD for a row's window.
type Cost struct {
	USD            *float64 `json:"usd"`
	State          string   `json:"state"`
	approximate    bool
	pricedTokens   int64
	unpricedTokens int64
}

func (c *Cost) add(usd float64, tokens int64, priced bool) {
	if tokens <= 0 {
		return
	}
	if priced {
		c.pricedTokens = sat(c.pricedTokens, tokens)
		v := usd
		if c.USD != nil {
			v += *c.USD
		}
		c.USD = &v
	} else {
		c.unpricedTokens = sat(c.unpricedTokens, tokens)
	}
}

func (c *Cost) merge(o Cost) {
	c.pricedTokens, c.unpricedTokens = sat(c.pricedTokens, o.pricedTokens), sat(c.unpricedTokens, o.unpricedTokens)
	if o.USD != nil {
		v := *o.USD
		if c.USD != nil {
			v += *c.USD
		}
		c.USD = &v
	}
}

func (c *Cost) settle() {
	switch {
	case c.pricedTokens > 0 && c.unpricedTokens == 0:
		c.State = CostPriced
	case c.pricedTokens > 0:
		c.State = CostPartial
	default:
		c.State, c.USD = CostUnpriced, nil
	}
}

// UsageRow is one session or one project in a window.
type UsageRow struct {
	Ref    string `json:"ref"`
	Source string `json:"source"`
	// Sources: the tools of a project row's sessions, sorted; a session row has its own.
	Sources          []string  `json:"sources"`
	ProjectRef       *string   `json:"projectRef"`
	ProjectKind      string    `json:"projectKind"`
	Label            *string   `json:"label"`
	Title            *string   `json:"title"`
	SubscriptionRef  *string   `json:"subscriptionRef"`
	SubscriptionRefs []string  `json:"subscriptionRefs"`
	FirstAt          time.Time `json:"firstAt"`
	LastAt           time.Time `json:"lastAt"`
	Sessions         int       `json:"sessions"`
	Running          bool      `json:"running"`
	Tokens           TokenSums `json:"tokens"`
	// Share: of the window's total tokens, every row and the background reviews counted.
	Share   float64         `json:"share"`
	Cost    Cost            `json:"cost"`
	Configs []SessionConfig `json:"configs"`
	// Model: the largest configuration's model, or the dated fallback with ModelApprox when it has none.
	Model       string `json:"model"`
	ModelApprox bool   `json:"modelApprox"`
}

// BackgroundReview folds the Codex background review runs (Auto Review) of a window into one row. They are a
// kind of session, never a model: their tokens count toward the window total, and their model is the dated
// fallback ccusage uses, shown approximate.
type BackgroundReview struct {
	Runs        int       `json:"runs"`
	Tokens      TokenSums `json:"tokens"`
	Share       float64   `json:"share"`
	Cost        Cost      `json:"cost"`
	Model       string    `json:"model"`
	ModelApprox bool      `json:"modelApprox"`
	LastAt      time.Time `json:"lastAt"`
}

// UsageWindow: the ranked sessions and projects of one window.
type UsageWindow struct {
	Total    TokenSums `json:"total"`
	Cost     Cost      `json:"cost"`
	Sessions int       `json:"sessions"`
	Projects int       `json:"projects"`
	// SessionRows and ProjectRows: at most RankCap rows each, by total tokens, largest first. Other: the rest.
	SessionRows   []UsageRow       `json:"sessionRows"`
	ProjectRows   []UsageRow       `json:"projectRows"`
	OtherSessions UsageOther       `json:"otherSessions"`
	OtherProjects UsageOther       `json:"otherProjects"`
	Review        BackgroundReview `json:"review"`
}

// UsageOther: the rows past the cap, summed.
type UsageOther struct {
	Count  int       `json:"count"`
	Tokens TokenSums `json:"tokens"`
	Share  float64   `json:"share"`
	Cost   Cost      `json:"cost"`
}

// UsageRankings: today and the recent 7 and 30 local days.
type UsageRankings struct {
	Measure   string      `json:"measure"` // total-tokens
	Today     UsageWindow `json:"today"`
	Recent7d  UsageWindow `json:"recent7d"`
	Recent30d UsageWindow `json:"recent30d"`
}

// autoReviewFallbacks: the model Codex's Auto Review is priced as, by the date of the run (the newest model
// released on or before it). Ported from ccusage (codex-auto-review-fallbacks.json, rust/adapters/codex/src
// at aacb63f6).
var autoReviewFallbacks = []struct{ releasedOn, model string }{
	{"2026-07-30", "gpt-5.6-luna"},
	{"2026-03-05", "gpt-5.4"},
	{"2026-02-05", "gpt-5.3-codex"},
	{"2025-12-11", "gpt-5.2-codex"},
	{"2025-11-13", "gpt-5.1-codex"},
	{"2025-09-15", "gpt-5-codex"},
	{"2025-08-07", "gpt-5"},
}

// FallbackModel: the dated fallback model for a Codex row that has none, by local day (YYYY-MM-DD). A day
// before the first release uses the oldest entry.
func FallbackModel(dayStr string) string {
	for _, f := range autoReviewFallbacks {
		if dayStr >= f.releasedOn {
			return f.model
		}
	}
	return autoReviewFallbacks[len(autoReviewFallbacks)-1].model
}

// reviewResponse: a Codex response that ran under no named model, or under the Auto Review id: a background run.
func reviewResponse(r SessionResponse) bool {
	return r.Source == "codex" && (r.Model == "" || r.Model == "codex-auto-review")
}

// Usage ranks every session and project over today, 7 and 30 days. p prices (nil: every cost is unpriced).
func (v PerfView) Usage(p Pricer) UsageRankings {
	out := UsageRankings{Measure: "total-tokens"}
	if !v.OK {
		return out
	}
	running := map[string]bool{}
	for _, s := range v.LiveSessions() {
		if s.Status == "running" || s.InProgress {
			running[s.Ref] = true
		}
	}
	out.Today = v.usageWindow(windowFrom(v.Now, 1), p, running)
	out.Recent7d = v.usageWindow(windowFrom(v.Now, 7), p, running)
	out.Recent30d = v.usageWindow(windowFrom(v.Now, 30), p, running)
	return out
}

func (v PerfView) usageWindow(from string, p Pricer, running map[string]bool) UsageWindow {
	w := UsageWindow{SessionRows: []UsageRow{}, ProjectRows: []UsageRow{}}
	w.Total.Complete = true
	sessions := []UsageRow{}
	for _, s := range v.Ledger.Sessions {
		row := UsageRow{Ref: s.Ref, Source: s.Source, Sources: []string{s.Source}, ProjectRef: refOrNil(s.ProjectRef), ProjectKind: sessionKind(s),
			SubscriptionRef: refOrNil(s.SubscriptionRef), SubscriptionRefs: []string{}, FirstAt: s.FirstAt, LastAt: s.LastAt, Sessions: 1, Running: running[s.Ref]}
		row.Tokens.Complete = true
		var c configSums
		var last string
		for _, d := range s.Days {
			if d.Day < from || d.Day > day(v.Now) {
				continue
			}
			row.Tokens.addDay(d)
			c.add(d)
			if d.Day > last {
				last = d.Day
			}
		}
		if row.Tokens.Output == 0 && row.Tokens.Total == 0 {
			continue
		}
		row.Configs = c.top()
		row.Model, row.ModelApprox = rowModel(s.Source, row.Configs, last)
		if s.ProjectLabel != "" {
			l := s.ProjectLabel
			row.Label = &l
		}
		if s.Title != "" {
			t := s.Title
			row.Title = &t
		}
		if s.SubscriptionRef != "" {
			row.SubscriptionRefs = []string{s.SubscriptionRef}
		}
		row.Cost = v.sessionCost(s, from, p)
		sessions = append(sessions, row)
	}
	w.Review = v.reviewRuns(from, p)
	for i := range sessions {
		w.Total.merge(sessions[i].Tokens)
		w.Cost.merge(sessions[i].Cost)
	}
	w.Total.merge(w.Review.Tokens)
	w.Cost.merge(w.Review.Cost)
	w.Total.Complete = w.Total.Complete && allComplete(sessions)
	w.Cost.settle()
	w.Review.Cost.settle()
	w.Sessions = len(sessions)
	share := func(t int64) float64 {
		if w.Total.Total <= 0 {
			return 0
		}
		return float64(t) / float64(w.Total.Total)
	}
	w.Review.Share = share(w.Review.Tokens.Total)
	for i := range sessions {
		sessions[i].Share = share(sessions[i].Tokens.Total)
		sessions[i].Cost.settle()
	}
	w.Projects, w.ProjectRows = projectRows(sessions, share)
	sortRows(sessions)
	w.SessionRows, w.OtherSessions = capRows(sessions, share)
	w.ProjectRows, w.OtherProjects = capRows(w.ProjectRows, share)
	return w
}

func allComplete(rows []UsageRow) bool {
	for _, r := range rows {
		if !r.Tokens.Complete {
			return false
		}
	}
	return true
}

// sessionKind: the project kind of a session recorded before kinds were kept reads as none when it has no
// project and is unknown otherwise.
func sessionKind(s PerfSession) string {
	if s.ProjectKind != "" {
		return s.ProjectKind
	}
	if s.ProjectRef == "" {
		return KindNone
	}
	return ""
}

func rowModel(source string, configs []SessionConfig, lastDay string) (string, bool) {
	if len(configs) > 0 && configs[0].Model != "" && configs[0].Model != "codex-auto-review" {
		return configs[0].Model, false
	}
	if source == "codex" && lastDay != "" {
		return FallbackModel(lastDay), true
	}
	return "", false
}

func sortRows(rows []UsageRow) {
	sort.SliceStable(rows, func(i, j int) bool {
		if rows[i].Tokens.Total != rows[j].Tokens.Total {
			return rows[i].Tokens.Total > rows[j].Tokens.Total
		}
		if !rows[i].LastAt.Equal(rows[j].LastAt) {
			return rows[i].LastAt.After(rows[j].LastAt)
		}
		return rows[i].Ref < rows[j].Ref
	})
}

func capRows(rows []UsageRow, share func(int64) float64) ([]UsageRow, UsageOther) {
	sortRows(rows)
	o := UsageOther{}
	o.Tokens.Complete = true
	if len(rows) <= RankCap {
		return rows, o
	}
	for _, r := range rows[RankCap:] {
		o.Count++
		o.Tokens.merge(r.Tokens)
		o.Cost.merge(r.Cost)
	}
	o.Share = share(o.Tokens.Total)
	o.Cost.settle()
	return rows[:RankCap], o
}

// unattributedRef is the project reference of sessions whose log records no working directory: the 无项目 bucket.
const unattributedRef = "unattributed"

// projectRows sums the session rows per project reference. A session with none is in the no-project bucket.
func projectRows(sessions []UsageRow, share func(int64) float64) (int, []UsageRow) {
	type acc struct {
		r   UsageRow
		cfg configSums
	}
	by := map[string]*acc{}
	var order []string
	for _, s := range sessions {
		ref := unattributedRef
		if s.ProjectRef != nil {
			ref = *s.ProjectRef
		}
		a := by[ref]
		if a == nil {
			r := UsageRow{Ref: ref, ProjectKind: s.ProjectKind, Sources: []string{}, SubscriptionRefs: []string{}, FirstAt: s.FirstAt, LastAt: s.LastAt}
			r.Tokens.Complete = true
			if ref == unattributedRef {
				r.ProjectKind = KindNone
			}
			a = &acc{r: r}
			by[ref] = a
			order = append(order, ref)
		}
		r := &a.r
		r.Sessions++
		r.Running = r.Running || s.Running
		r.Tokens.merge(s.Tokens)
		r.Cost.merge(s.Cost)
		if s.LastAt.After(r.LastAt) {
			r.LastAt = s.LastAt
		}
		if s.FirstAt.Before(r.FirstAt) {
			r.FirstAt = s.FirstAt
		}
		if r.Label == nil && s.Label != nil {
			r.Label = s.Label
		}
		if r.ProjectKind == "" {
			r.ProjectKind = s.ProjectKind
		}
		if !contains(r.Sources, s.Source) {
			r.Sources = append(r.Sources, s.Source)
		}
		for _, sr := range s.SubscriptionRefs {
			if !contains(r.SubscriptionRefs, sr) {
				r.SubscriptionRefs = append(r.SubscriptionRefs, sr)
			}
		}
		for _, c := range s.Configs {
			a.cfg.add(SessionDay{Model: c.Model, EffortStatus: c.EffortStatus, Effort: c.Effort, Speed: c.Speed, ObservedOutputTokens: c.ObservedOutputTokens})
		}
		if s.Source != "" && r.Source == "" {
			r.Source = s.Source
		}
	}
	rows := make([]UsageRow, 0, len(order))
	for _, k := range order {
		a := by[k]
		sort.Strings(a.r.Sources)
		sort.Strings(a.r.SubscriptionRefs)
		a.r.Configs = a.cfg.top()
		a.r.Model, a.r.ModelApprox = rowModel(a.r.Source, a.r.Configs, day(a.r.LastAt))
		a.r.Share = share(a.r.Tokens.Total)
		a.r.Cost.settle()
		rows = append(rows, a.r)
	}
	return len(rows), rows
}

// sessionCost prices a session's window. Responses its log recorded (Codex, Claude Code) are priced one by one,
// each as the Pricer prices a single request; a session without them is priced by its days' totals.
func (v PerfView) sessionCost(s PerfSession, from string, p Pricer) Cost {
	var c Cost
	if p == nil {
		c.settle()
		return c
	}
	if rs := v.Ledger.UsageSessions[s.Key]; len(rs) > 0 {
		for _, r := range rs {
			if d := day(r.At); d < from || d > day(v.Now) || r.At.After(v.Now) || reviewResponse(r) {
				continue
			}
			usd, ok := p.Request(r.Source, r.Model, r.Tier, r.Buckets)
			c.add(usd, r.Buckets.Sum(), ok)
		}
		c.settle()
		return c
	}
	for _, d := range s.Days {
		if d.Day < from || d.Day > day(v.Now) || d.Model == "" {
			continue
		}
		row := PerfRow{ObservedOutputTokens: d.ObservedOutputTokens}
		if d.Kinds != nil {
			row.TokenKinds = *d.Kinds
		}
		b, known := rowBuckets(&row)
		if !known {
			c.add(0, max(b.Sum(), d.ObservedOutputTokens), false)
			continue
		}
		usd, ok, _ := p.Aggregate(s.Source, d.Model, b)
		c.add(usd, b.Sum(), ok)
	}
	c.settle()
	return c
}

// reviewRuns folds the window's Codex background review responses into one row, priced as the dated fallback.
func (v PerfView) reviewRuns(from string, p Pricer) BackgroundReview {
	b := BackgroundReview{}
	b.Tokens.Complete = true
	runs := map[string]bool{}
	for key, rs := range v.Ledger.UsageSessions {
		for _, r := range rs {
			d := day(r.At)
			if !reviewResponse(r) || d < from || d > day(v.Now) || r.At.After(v.Now) {
				continue
			}
			runs[key] = true
			n := r.Buckets.Sum()
			b.Tokens.Total, b.Tokens.Output = sat(b.Tokens.Total, n), sat(b.Tokens.Output, r.Buckets.Output+r.Buckets.Reasoning)
			b.Tokens.Input, b.Tokens.CacheRead, b.Tokens.CacheWrite = sat(b.Tokens.Input, r.Buckets.Input), sat(b.Tokens.CacheRead, r.Buckets.CacheRead), sat(b.Tokens.CacheWrite, r.Buckets.CacheWrite)
			if r.At.After(b.LastAt) {
				b.LastAt = r.At.UTC()
			}
			model := FallbackModel(d)
			if p != nil {
				usd, ok := p.Request(r.Source, model, r.Tier, r.Buckets)
				b.Cost.add(usd, n, ok)
			} else {
				b.Cost.add(0, n, false)
			}
		}
	}
	b.Runs = len(runs)
	if b.Runs > 0 {
		b.Model, b.ModelApprox = FallbackModel(day(b.LastAt)), true
	}
	return b
}

// SessionTotal is a session's tokens and ≈cost over every recorded day: what the tape shows beside it. Tokens is
// nil unless every recorded day's parts are known.
type SessionTotal struct {
	Tokens *int64
	Cost   Cost
}

// SessionTotals: each recorded session's total so far, by its reference. p prices (nil: no cost).
func (v PerfView) SessionTotals(p Pricer) map[string]SessionTotal {
	out := map[string]SessionTotal{}
	if !v.OK {
		return out
	}
	for _, s := range v.Ledger.Sessions {
		var t TokenSums
		t.Complete = true
		for _, d := range s.Days {
			t.addDay(d)
		}
		st := SessionTotal{Cost: v.sessionCost(s, "", p)}
		if t.Complete && len(s.Days) > 0 {
			total := t.Total
			st.Tokens = &total
		}
		out[s.Ref] = st
	}
	return out
}

// SessionInfo reads a recorded session's title and project kind by reference.
func (v PerfView) SessionInfo(ref, source string) (title, kind string, ok bool) {
	for _, s := range v.Ledger.Sessions {
		if s.Ref == ref && s.Source == source {
			return s.Title, sessionKind(s), true
		}
	}
	return "", "", false
}
