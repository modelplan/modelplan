// Package snapshot assembles the personal snapshot: the one document a desktop client (and later
// a mobile one, through sync) renders for the user's own state. It holds each harness session's
// configuration against its ★ effort, the quota accounts, the advice events with their text, and
// the measured speed. Public recommendations are not in it: clients read the verified publication
// themselves. It is built from what the CLI already reads on this machine; nothing here leaves it.
// docs/personal-snapshot.md describes the format.
package snapshot

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/advise"
	"github.com/modelplan/modelplan/cli/internal/connections"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/history"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/qwenusage"
	"github.com/modelplan/modelplan/cli/internal/render"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
)

const (
	Kind          = "modelplan.personal-snapshot"
	SchemaVersion = 1
	// A publication not checked for this long is stale, as in the plugins.
	publicationStale = 48 * time.Hour
	// Cached CodexBar and Codex account readings are used for this long.
	cachedKeep = 6 * time.Hour
)

type Snapshot struct {
	QwenUsage     *qwenusage.Report `json:"qwenUsage,omitempty"`
	SchemaVersion int               `json:"schemaVersion"`
	Kind          string            `json:"kind"`
	GeneratedAt   time.Time         `json:"generatedAt"`
	CLIVersion    string            `json:"cliVersion"`
	// Publication: the verified publication the figures come from; nil before the first sync.
	Publication *Publication         `json:"publication"`
	Sessions    []Session            `json:"sessions"`
	Accounts    []quota.Account      `json:"accounts"`
	Sources     []quota.SourceStatus `json:"sources"`
	// Connections: per agent and quota source, installed / history / authorization / quota.
	Connections []connections.Connection `json:"connections"`
	Events      []Event                  `json:"events"`
	Measured    []speed.Stat             `json:"measured"`
	// PerfStats, Daily and DailyCoverage come from the performance ledger (perf.json), which runs
	// beside the one behind Measured and is never mixed with it.
	LiveSessions  []speed.LiveSession `json:"liveSessions"`
	TodayTotals   []speed.TodayTotal  `json:"todayTotals"`
	Hourly        []speed.Hourly      `json:"hourly"`
	PerfStats     []speed.PerfStat    `json:"perfStats"`
	Daily         []speed.Daily       `json:"daily"`
	DailyCoverage speed.DailyCoverage `json:"dailyCoverage"`
	// DailyLong and DailyLongCoverage: the same per-day totals for a year, from daily-long.json
	// (perf.json's days rolled up and kept for 371 days).
	DailyLong         []speed.Daily       `json:"dailyLong"`
	DailyLongCoverage speed.DailyCoverage `json:"dailyLongCoverage"`
	// PaceHistory: how fast each window's percentage rose per cycle (pace.json), beside the quota
	// history behind `modelplan history`. Percentage points, never tokens.
	PaceHistory history.PaceHistory `json:"paceHistory"`
	// SessionRanking: the sessions with the most observed output tokens (perf.json).
	SessionRanking speed.SessionRanking `json:"sessionRanking"`
	// ProjectRanking: the same sessions summed per project (opaque references; labels only while
	// ProjectLabels is on).
	ProjectRanking speed.ProjectRanking `json:"projectRanking"`
	// ProjectLabels: project labels are on, as they are unless the user turned them off
	// (`modelplan project-labels off`).
	ProjectLabels bool `json:"projectLabels"`
	// Subscriptions: every subscription the accounts were bound to, with the accounts that read
	// it, for a scope selector. References are random and local; they name no account.
	Subscriptions []Subscription `json:"subscriptions"`
	// Recording: the local quota history and speed measurement are on (MODELPLAN_HISTORY).
	Recording bool   `json:"recording"`
	Note      string `json:"note"`
	// DataRevision changes only when what was observed changes (readings, session configuration,
	// the speed ledger, the publication, recording), never with the clock alone.
	DataRevision string `json:"dataRevision"`
	// ValidUntil: the next instant at which the clock alone changes a verdict here (a reset, a
	// card expiry, a reading going stale, an advice lead); read again then, even with the same
	// DataRevision. Nil when nothing is due.
	ValidUntil *time.Time `json:"validUntil"`
}

type Publication struct {
	PublicationID string     `json:"publicationId"`
	PublishedAt   string     `json:"publishedAt,omitempty"`
	CheckedAt     *time.Time `json:"checkedAt,omitempty"`
	VerifiedAt    *time.Time `json:"verifiedAt,omitempty"`
	Stale         bool       `json:"stale"`
	LastError     string     `json:"lastError,omitempty"`
}

// Session is a harness's current configuration as it last reported it, resolved against the
// publication when the model is listed there.
type Session struct {
	Source      string     `json:"source"` // claude-code | codex
	ObservedAt  *time.Time `json:"observedAt,omitempty"`
	Attribution string     `json:"attribution,omitempty"` // current-thread | recent-thread
	Origin      string     `json:"origin,omitempty"`
	Stale       bool       `json:"stale"`
	Model       ModelRef   `json:"model"`
	// Effort is the effort in use (the harness default reads as ★), Recommended the ★ effort;
	// both nil when the model is not in the publication. Effort keeps that fallback for older
	// clients; EffortStatus says whether the harness reported an effort at all.
	Effort       *EffortRef `json:"effort"`
	EffortStatus string     `json:"effortStatus"` // reported | unreported
	Recommended  *EffortRef `json:"recommended"`
	// VsRecommended: the effort in use against ★ (points, cost multiple); nil at ★ or unknown.
	VsRecommended *Delta `json:"vsRecommended"`
	Speed         string `json:"speed,omitempty"` // "" standard; fast, …
	// TokenRate: the recent generation rate of this configuration; WorkloadRate: of all the
	// harness's configurations together, the one reading to show per engine.
	TokenRate    *speed.Rate `json:"tokenRate,omitempty"`
	WorkloadRate *speed.Rate `json:"workloadRate,omitempty"`
	Activity     *Activity   `json:"activity,omitempty"`
	// ProjectRef: the project of the harness's most recently active session in the performance
	// ledger (the session this entry describes when it is the recent one); null when unknown.
	ProjectRef *string `json:"projectRef"`
	// Subscription: the account the session's harness is signed in to, when a reader saw it.
	Subscription *quota.Binding `json:"subscription"`
	// The quota verdict of the session's account, for the allowance it draws from.
	Headroom string `json:"headroom"`
	Deciding string `json:"deciding,omitempty"`
	Pool     string `json:"pool,omitempty"`
}

// Activity: whether the harness showed recent activity in its own timestamps. recent: a turn
// started or a request completed within WithinMinutes; quiet: not since; unknown: no such
// timestamp. It never claims a session is working now.
type Activity struct {
	Status        string     `json:"status"` // recent | quiet | unknown
	LastSignalAt  *time.Time `json:"lastSignalAt"`
	Basis         string     `json:"basis,omitempty"` // turn-started (Codex turn context) | completed-request
	WithinMinutes int        `json:"withinMinutes"`
}

const activeWithin = 10 * time.Minute

func activity(source string, h *quota.Harness, p *speed.PerfView, now time.Time) *Activity {
	a := &Activity{Status: "unknown", WithinMinutes: int(activeWithin.Minutes())}
	if t := p.LastCompleted(source); t != nil {
		a.LastSignalAt, a.Basis = t, "completed-request"
	}
	// Claude Code's status line also renders while idle, so its time is no sign of activity.
	if source == "codex" && h != nil && h.ObservedAt != nil && (a.LastSignalAt == nil || h.ObservedAt.After(*a.LastSignalAt)) {
		t := h.ObservedAt.UTC()
		a.LastSignalAt, a.Basis = &t, "turn-started"
	}
	switch {
	case a.LastSignalAt == nil:
	case now.Sub(*a.LastSignalAt) <= activeWithin:
		a.Status = "recent"
	default:
		a.Status = "quiet"
	}
	return a
}

type ModelRef struct {
	HarnessID   string `json:"harnessId"`    // as the harness reports it
	ID          string `json:"id,omitempty"` // the publication's; "" when not listed
	Name        string `json:"name,omitempty"`
	DeveloperID string `json:"developerId,omitempty"`
}

type EffortRef struct {
	Key   string `json:"key"`
	Label string `json:"label"`
	Star  bool   `json:"star"`
}

type Delta struct {
	AbilityDelta *float64 `json:"abilityDelta"`
	CostRatio    *float64 `json:"costRatio"`
}

// Event is an advice event as `advise --json` gives it, keyed for once-only notification, with
// its short form for a menu bar.
type Event struct {
	advise.Event
	// Short: the menu-bar hint ("↑High ×1.37", "→Opus 5.5 ★Med ×0.52"), zh and en; empty when the
	// event has none.
	Short map[string]string `json:"short,omitempty"`
	// InMenuBar: the status line would show it now (a switch-back for a while after it appeared, a
	// better model for a week).
	InMenuBar bool `json:"inMenuBar"`
}

type Input struct {
	QwenUsage *qwenusage.Report
	Report    quota.Report
	Digest    *digest.Digest
	State     store.State
	Events    []advise.Event // from advise.Derive with the advice state
	Measured  []speed.Stat
	// Ledger: the speed ledger's rows behind Measured, for DataRevision.
	Ledger      []speed.Row
	Connections []connections.Connection
	// Perf: the performance ledger; nil leaves its fields empty.
	Perf *speed.PerfView
	// Pace: the pace ledger; nil leaves paceHistory empty.
	Pace *history.PaceView
	// Boundaries: advise.Boundaries for the same input.
	Boundaries []time.Time
	Recording  bool
	// ProjectLabels: project labels are on; while off, none is shown even if the ledger has one.
	ProjectLabels bool
	CLIVersion    string
	Now           time.Time
}

const note = "Built on this machine from what the harnesses write locally; never sent anywhere. Public recommendations are in the verified publication, which clients read themselves."

func Build(in Input) Snapshot {
	s := Snapshot{SchemaVersion: SchemaVersion, Kind: Kind, GeneratedAt: in.Now.UTC(), CLIVersion: in.CLIVersion,
		Sessions: []Session{}, Accounts: in.Report.Accounts, Sources: in.Report.Sources, Events: []Event{}, Measured: in.Measured,
		Recording: in.Recording, Note: note, QwenUsage: in.QwenUsage}
	if s.Accounts == nil {
		s.Accounts = []quota.Account{}
	}
	if s.Sources == nil {
		s.Sources = []quota.SourceStatus{}
	}
	s.Connections = in.Connections
	if s.Connections == nil {
		s.Connections = []connections.Connection{}
	}
	if s.Measured == nil {
		s.Measured = []speed.Stat{}
	}
	s.PerfStats, s.Daily, s.DailyCoverage = []speed.PerfStat{}, []speed.Daily{}, speed.DailyCoverage{Recording: in.Recording}
	s.DailyLong, s.DailyLongCoverage = []speed.Daily{}, speed.DailyCoverage{Recording: in.Recording}
	s.LiveSessions, s.TodayTotals, s.Hourly = []speed.LiveSession{}, []speed.TodayTotal{}, []speed.Hourly{}
	if in.Perf != nil {
		s.LiveSessions, s.TodayTotals, s.Hourly = in.Perf.LiveSessions(), in.Perf.TodayTotals(), in.Perf.Hourly()
		s.PerfStats, s.Daily, s.DailyCoverage = in.Perf.Stats(), in.Perf.Daily(), in.Perf.Coverage()
		s.DailyLong, s.DailyLongCoverage = in.Perf.DailyLong(), in.Perf.LongCoverage()
	}
	for i := range s.Connections {
		if c := &s.Connections[i]; in.Perf != nil && c.Kind == "agent" && c.History.Status == "yes" && c.History.At == nil {
			c.History.At = in.Perf.LastCompleted(c.ID) // agents read from a database: their last counted request
		}
	}
	s.SessionRanking, s.ProjectRanking = speed.PerfView{Now: in.Now}.Ranking(), speed.PerfView{Now: in.Now}.Projects()
	if in.Perf != nil {
		s.SessionRanking, s.ProjectRanking = in.Perf.Ranking(), in.Perf.Projects()
	}
	s.ProjectLabels = in.ProjectLabels
	s.Subscriptions = subscriptions(in.Report.Accounts)
	starRankings(&s, in.Digest, in.ProjectLabels)
	s.PaceHistory = history.PaceView{OK: true, Recording: in.Recording, Now: in.Now}.History()
	if in.Pace != nil {
		s.PaceHistory = in.Pace.History()
	}
	if in.Digest != nil && in.State.PublicationID != "" {
		p := &Publication{PublicationID: in.State.PublicationID, PublishedAt: in.State.PublishedAt, LastError: in.State.LastError,
			Stale: in.State.CheckedAt.IsZero() || in.Now.Sub(in.State.CheckedAt) > publicationStale}
		if !in.State.CheckedAt.IsZero() {
			t := in.State.CheckedAt.UTC()
			p.CheckedAt = &t
		}
		if !in.State.VerifiedAt.IsZero() {
			t := in.State.VerifiedAt.UTC()
			p.VerifiedAt = &t
		}
		s.Publication = p
	}
	for i := range in.Report.Accounts {
		if x, ok := session(&in.Report.Accounts[i], in.Digest); ok {
			if p := in.Perf; p != nil {
				h := in.Report.Accounts[i].Harness
				t, w := p.TokenRate(x.Source, h.Model, h.Effort, x.Speed), p.WorkloadRate(x.Source)
				x.TokenRate, x.WorkloadRate, x.Activity = &t, &w, activity(x.Source, h, p, in.Now)
				if ref := p.LatestProject(x.Source); ref != "" {
					x.ProjectRef = &ref
				}
			}
			s.Sessions = append(s.Sessions, x)
		}
	}
	zh, en := render.Style{T: render.ZH}, render.Style{T: render.EN}
	for _, e := range in.Events {
		e.Key = advise.ConfigKey(e)
		e.Text = map[string]string{"zh": zh.AdviceLine(e), "en": en.AdviceLine(e)}
		x := Event{Event: e, InMenuBar: e.InStatusLine(in.Now)}
		if a, b := zh.AdviceShort(e), en.AdviceShort(e); a != "" || b != "" {
			x.Short = map[string]string{"zh": a, "en": b}
		}
		s.Events = append(s.Events, x)
	}
	s.DataRevision = revision(in)
	s.ValidUntil = validUntil(in, s)
	return s
}

// revision hashes the observations the snapshot is built from, and none of what the clock derives
// from them (remaining minutes, elapsed and projected shares, pace, staleness, events).
func revision(in Input) string {
	type window struct {
		Kind, Limit, ResetMode  string
		Used, UsedUSD, LimitUSD *float64
		Minutes                 int
		ResetsAt                *time.Time
		ObservedAt              time.Time
	}
	type account struct {
		Source, Plan, Generation, Via, Pool string
		ObservedAt                          time.Time
		Harness                             *quota.Harness
		Windows                             []window
		Cards                               []quota.Card
		Credits                             *quota.Credits `json:",omitempty"`
		Subscription                        *quota.Binding `json:",omitempty"`
	}
	var v struct {
		QwenUsage   *qwenusage.Report `json:",omitempty"`
		Accounts    []account
		Sources     []quota.SourceStatus
		Ledger      []speed.Row
		Perf        *speed.PerfLedger
		PerfOK      bool
		Long        *speed.LongLedger `json:",omitempty"`
		LongOK      bool              `json:",omitempty"`
		Pace        *history.PaceLedger
		PaceOK      bool
		Connections []connections.Connection
		Publication string
		Recording   bool
	}
	for _, a := range in.Report.Accounts {
		x := account{Source: a.Source, Plan: a.Plan, Generation: a.Generation, Via: a.Via, Pool: a.Pool, ObservedAt: a.ObservedAt.UTC(), Harness: a.Harness, Cards: a.Cards, Subscription: a.Subscription}
		if c := a.Credits; c != nil {
			x.Credits = &quota.Credits{Unlimited: c.Unlimited, Balance: c.Balance, ObservedAt: c.ObservedAt.UTC()} // not its age
		}
		for _, w := range a.Windows {
			x.Windows = append(x.Windows, window{Kind: w.Kind, Limit: w.Limit, ResetMode: w.ResetMode, Used: w.UsedPercent, UsedUSD: w.UsedUSD, LimitUSD: w.LimitUSD,
				Minutes: w.WindowMinutes, ResetsAt: w.ResetsAt, ObservedAt: w.ObservedAt.UTC()})
		}
		v.Accounts = append(v.Accounts, x)
	}
	if in.QwenUsage != nil {
		q := *in.QwenUsage
		q.Periods = append([]qwenusage.Period(nil), q.Periods...)
		for i := range q.Periods {
			q.Periods[i].Stale = false
		}
		v.QwenUsage = &q
	}
	v.Sources, v.Ledger, v.Recording, v.Connections = in.Report.Sources, in.Ledger, in.Recording, in.Connections
	if in.Perf != nil {
		l := in.Perf.Ledger
		l.Files = nil // how far the logs were read is no observation
		v.Perf, v.PerfOK = &l, in.Perf.OK
		if in.Perf.LongOK {
			v.Long, v.LongOK = &in.Perf.Long, true
		}
	}
	if in.Pace != nil {
		v.Pace, v.PaceOK = &in.Pace.Ledger, in.Pace.OK
	}
	if in.Digest != nil {
		v.Publication = in.State.PublicationID
	}
	b, _ := json.Marshal(v)
	h := sha256.Sum256(b)
	return "sha256:" + hex.EncodeToString(h[:16])
}

// validUntil: the earliest coming boundary of the quota verdicts, the advice, a cached reading
// leaving use, the publication going stale and, with measured speed, the local midnight that
// moves its days.
func validUntil(in Input, s Snapshot) *time.Time {
	now := in.Now.UTC()
	ts := append([]time.Time(nil), in.Boundaries...)
	if in.QwenUsage != nil {
		for _, p := range in.QwenUsage.Periods {
			ts = append(ts, p.GeneratedAt.Add(24*time.Hour))
		}
	}
	for i := range in.Report.Accounts {
		a := &in.Report.Accounts[i]
		ts = append(ts, quota.Boundaries(a)...)
		if !a.ObservedAt.IsZero() {
			ts = append(ts, a.ObservedAt.Add(cachedKeep)) // a CodexBar or Codex account reading this old is no longer used
		}
	}
	if s.Publication != nil && s.Publication.CheckedAt != nil {
		ts = append(ts, s.Publication.CheckedAt.Add(publicationStale))
	}
	if in.Perf != nil {
		ts = append(ts, in.Perf.Boundaries()...)
	}
	for _, x := range s.Sessions {
		if x.Activity != nil && x.Activity.LastSignalAt != nil {
			ts = append(ts, x.Activity.LastSignalAt.Add(activeWithin))
		}
	}
	if in.Pace != nil {
		ts = append(ts, in.Pace.Boundaries()...)
	}
	if len(s.Measured) > 0 {
		l := in.Now.Local()
		ts = append(ts, time.Date(l.Year(), l.Month(), l.Day()+1, 0, 0, 0, 0, time.Local))
	}
	sort.Slice(ts, func(i, j int) bool { return ts[i].Before(ts[j]) })
	for _, t := range ts {
		if t.After(now) {
			u := t.UTC()
			return &u
		}
	}
	return nil
}

func session(a *quota.Account, d *digest.Digest) (Session, bool) {
	h := a.Harness
	if h == nil || (a.Source != "claude-code" && a.Source != "codex") {
		return Session{}, false
	}
	x := Session{Source: a.Source, ObservedAt: h.ObservedAt, Attribution: h.Attribution, Origin: h.Origin, Stale: a.Stale,
		Model: ModelRef{HarnessID: h.Model}, Subscription: a.Subscription, Headroom: a.Headroom, Deciding: a.Deciding, Pool: a.Pool, Speed: speedOf(h), EffortStatus: "unreported"}
	if h.Effort != "" {
		x.EffortStatus = "reported"
	}
	if x.ObservedAt == nil && !a.ObservedAt.IsZero() {
		t := a.ObservedAt.UTC()
		x.ObservedAt = &t
	}
	if d == nil || h.Model == "" {
		return x, true
	}
	m := d.Model(h.Model)
	if m == nil {
		m = d.MatchAt(a.Source, h.Endpoint, h.Model)
	}
	if m == nil {
		return x, true
	}
	x.Model.ID, x.Model.Name, x.Model.DeveloperID = m.ID, m.Name, m.DeveloperID
	rec, cur := m.Rec(), m.Rec()
	if h.Effort != "" {
		if e := m.Effort(h.Effort); e != nil {
			cur = e
		}
	}
	if rec != nil {
		x.Recommended = &EffortRef{Key: rec.Effort, Label: rec.Label, Star: true}
	}
	if cur != nil {
		x.Effort = &EffortRef{Key: cur.Effort, Label: cur.Label, Star: cur == rec}
	}
	if cur != nil && rec != nil && cur != rec {
		dl := &Delta{}
		if cur.Ability != nil && rec.Ability != nil {
			v := round1(*cur.Ability - *rec.Ability)
			dl.AbilityDelta = &v
		}
		if cur.Cost != nil && rec.Cost != nil && *rec.Cost > 0 {
			v := round2(*cur.Cost / *rec.Cost)
			dl.CostRatio = &v
		}
		x.VsRecommended = dl
	}
	return x, true
}

// Subscription: one subscription reference and the accounts read from it.
type Subscription struct {
	Ref        string    `json:"subscriptionRef"`
	Sources    []string  `json:"sources"`
	Basis      string    `json:"basis"`
	ObservedAt time.Time `json:"observedAt"`
}

func subscriptions(as []quota.Account) []Subscription {
	out := []Subscription{}
	at := map[string]int{}
	for _, a := range as {
		b := a.Subscription
		if b == nil {
			continue
		}
		i, ok := at[b.Ref]
		if !ok {
			i, at[b.Ref] = len(out), len(out)
			out = append(out, Subscription{Ref: b.Ref, Basis: b.Basis, ObservedAt: b.ObservedAt.UTC()})
		}
		out[i].Sources = append(out[i].Sources, a.Source)
		if b.ObservedAt.After(out[i].ObservedAt) {
			out[i].ObservedAt = b.ObservedAt.UTC()
		}
	}
	return out
}

// starRankings gives each ranked configuration its model's published ★ effort, and drops
// project labels unless they are on.
func starRankings(s *Snapshot, d *digest.Digest, labels bool) {
	star := func(source string, cs []speed.SessionConfig) {
		for i := range cs {
			if d == nil || cs[i].Model == "" {
				continue
			}
			m := d.Model(cs[i].Model)
			for _, h := range []string{source, "codex", "claude-code"} { // a project's configurations span harnesses
				if m == nil && h != "" {
					m = d.Match(h, cs[i].Model)
				}
			}
			if m == nil {
				continue
			}
			if rec := m.Rec(); rec != nil && rec.Effort != "" {
				e := rec.Effort
				cs[i].RecommendedEffort = &e
			}
		}
	}
	for _, w := range []*speed.SessionWindow{&s.SessionRanking.Recent7d, &s.SessionRanking.Recent30d} {
		for i := range w.Top {
			star(w.Top[i].Source, w.Top[i].Configs)
		}
	}
	for _, w := range []*speed.ProjectWindow{&s.ProjectRanking.Recent7d, &s.ProjectRanking.Recent30d} {
		for i := range w.Top {
			star("", w.Top[i].Configs)
			if !labels {
				w.Top[i].Label = nil
			}
		}
	}
}

// speedOf: the speed mode the harness reports (Claude Code fast mode, Codex service tier).
func speedOf(h *quota.Harness) string {
	switch {
	case h.FastMode != nil && *h.FastMode:
		return "fast"
	case h.ServiceTier != "" && h.ServiceTier != "default" && h.ServiceTier != "auto":
		return h.ServiceTier
	}
	return ""
}

func round1(v float64) float64 { return float64(int64(v*10+sign(v)*0.5)) / 10 }
func round2(v float64) float64 { return float64(int64(v*100+sign(v)*0.5)) / 100 }
func sign(v float64) float64 {
	if v < 0 {
		return -1
	}
	return 1
}
