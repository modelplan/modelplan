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
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
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
	SchemaVersion int       `json:"schemaVersion"`
	Kind          string    `json:"kind"`
	GeneratedAt   time.Time `json:"generatedAt"`
	CLIVersion    string    `json:"cliVersion"`
	// Publication: the verified publication the figures come from; nil before the first sync.
	Publication *Publication         `json:"publication"`
	Sessions    []Session            `json:"sessions"`
	Accounts    []quota.Account      `json:"accounts"`
	Sources     []quota.SourceStatus `json:"sources"`
	Events      []Event              `json:"events"`
	Measured    []speed.Stat         `json:"measured"`
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
	// The quota verdict of the session's account, for the allowance it draws from.
	Headroom string `json:"headroom"`
	Deciding string `json:"deciding,omitempty"`
	Pool     string `json:"pool,omitempty"`
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
	Report   quota.Report
	Digest   *digest.Digest
	State    store.State
	Events   []advise.Event // from advise.Derive with the advice state
	Measured []speed.Stat
	// Ledger: the speed ledger's rows behind Measured, for DataRevision.
	Ledger []speed.Row
	// Boundaries: advise.Boundaries for the same input.
	Boundaries []time.Time
	Recording  bool
	CLIVersion string
	Now        time.Time
}

const note = "Built on this machine from what the harnesses write locally; never sent anywhere. Public recommendations are in the verified publication, which clients read themselves."

func Build(in Input) Snapshot {
	s := Snapshot{SchemaVersion: SchemaVersion, Kind: Kind, GeneratedAt: in.Now.UTC(), CLIVersion: in.CLIVersion,
		Sessions: []Session{}, Accounts: in.Report.Accounts, Sources: in.Report.Sources, Events: []Event{}, Measured: in.Measured,
		Recording: in.Recording, Note: note}
	if s.Accounts == nil {
		s.Accounts = []quota.Account{}
	}
	if s.Sources == nil {
		s.Sources = []quota.SourceStatus{}
	}
	if s.Measured == nil {
		s.Measured = []speed.Stat{}
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
	}
	var v struct {
		Accounts    []account
		Sources     []quota.SourceStatus
		Ledger      []speed.Row
		Publication string
		Recording   bool
	}
	for _, a := range in.Report.Accounts {
		x := account{Source: a.Source, Plan: a.Plan, Generation: a.Generation, Via: a.Via, Pool: a.Pool, ObservedAt: a.ObservedAt.UTC(), Harness: a.Harness, Cards: a.Cards}
		for _, w := range a.Windows {
			x.Windows = append(x.Windows, window{Kind: w.Kind, Limit: w.Limit, ResetMode: w.ResetMode, Used: w.UsedPercent, UsedUSD: w.UsedUSD, LimitUSD: w.LimitUSD,
				Minutes: w.WindowMinutes, ResetsAt: w.ResetsAt, ObservedAt: w.ObservedAt.UTC()})
		}
		v.Accounts = append(v.Accounts, x)
	}
	v.Sources, v.Ledger, v.Recording = in.Report.Sources, in.Ledger, in.Recording
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
		Model: ModelRef{HarnessID: h.Model}, Headroom: a.Headroom, Deciding: a.Deciding, Pool: a.Pool, Speed: speedOf(h), EffortStatus: "unreported"}
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
