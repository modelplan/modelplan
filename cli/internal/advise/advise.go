// Package advise turns the local quota report and the public publication into a short list
// of things worth telling the user now: a window that resets soon with allowance left, a
// window running tight or used up, a reset that has passed since we suggested stepping up or
// down, an announced provider reset that would void what is left, a quota-rate change for a
// plan coming up, reset cards about to expire, and a public reset for a harness the user has. It only advises; it never changes a model, effort, fast
// mode or setting.
//
// Derive is pure. The status line and the Claude Code hook keep a small State next to the
// quota snapshot so a hint is shown once and "switch back after the reset" can be remembered.
package advise

import (
	"encoding/json"
	"math"
	"sort"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// Event types, most urgent first (Rank).
const (
	WindowExhausted  = "window_exhausted"
	WindowTight      = "window_tight"
	SwitchBack       = "reset_passed_switch_back"
	ResetSoonSurplus = "reset_soon_with_surplus"
	// AnnouncedSurplus: a provider announced a reset for a stated time; if it covers this account,
	// what is left in the longer window is void then. Never proof that it covers this account.
	AnnouncedSurplus  = "announced_reset_with_surplus"
	PeakStartsSoon    = "peak_starts_soon"
	OffpeakStartsSoon = "offpeak_starts_soon"
	CardsExpiring     = "cards_expiring"
	PublicReset       = "public_reset_announced"
)

var rank = map[string]int{WindowExhausted: 0, WindowTight: 1, SwitchBack: 2, ResetSoonSurplus: 3, AnnouncedSurplus: 4, PeakStartsSoon: 5, OffpeakStartsSoon: 6, CardsExpiring: 7, PublicReset: 8}

const (
	// A surplus counts as "reset soon" in the last quarter of the window, as in quota's pace rule.
	soonShare = 0.25
	// Rate changes and card expiries are announced this far ahead.
	rateLead = 60 * time.Minute
	cardLead = 48 * time.Hour
	// Public resets are news for a day after publication.
	publicFresh = 24 * time.Hour
	// "Switch back" stays relevant for this long after the reset it waited for.
	switchBackFor = 90 * time.Minute
	// Harness readings older than this belong to a finished session; no hints from them.
	harnessQuiet = 6 * time.Hour
	// An announced reset is worth spending ahead of within this lead, when at least this much of
	// the longer window is left and that window would not reset on its own before it.
	announcedLead    = 24 * time.Hour
	announcedMinLeft = 20.0
)

// Step is a concrete suggestion against what the harness reports now.
type Step struct {
	Action       string   `json:"action"` // step_up | stronger_model | step_down | switch_back | wait | use_card | none
	Model        string   `json:"model,omitempty"`
	ModelName    string   `json:"modelName,omitempty"`
	Effort       string   `json:"effort,omitempty"` // native key
	Label        string   `json:"label,omitempty"`  // display label
	Recommended  bool     `json:"recommended,omitempty"`
	AbilityDelta *float64 `json:"abilityDelta,omitempty"` // vs the current configuration
	CostRatio    *float64 `json:"costRatio,omitempty"`    // vs the current configuration
}

type Rate struct {
	Model  string   `json:"model"`
	From   *float64 `json:"from"`
	To     *float64 `json:"to"`
	Status string   `json:"status"` // CONFIRMED | TENTATIVE | unknown
	URL    string   `json:"url,omitempty"`
}

// Speed is a speed tier worth mentioning with a surplus: it draws the same plan quota faster.
type Speed struct {
	Tier       string   `json:"tier"`
	Label      string   `json:"label"`
	QuotaRatio float64  `json:"quotaRatio"`
	SpeedRatio *float64 `json:"speedRatio"`
	Qualifier  string   `json:"qualifier"`
}

type Public struct {
	ID        string `json:"id"`
	Provider  string `json:"provider"`
	EventType string `json:"eventType"`
	Status    string `json:"status"`
	URL       string `json:"url,omitempty"`
	When      string `json:"when,omitempty"` // the announcement's own schedule label
}

type Event struct {
	Type             string            `json:"type"`
	Key              string            `json:"key"`
	Severity         string            `json:"severity"` // warn | info
	Source           string            `json:"source"`   // claude-code | codex | user | public
	Plan             string            `json:"plan,omitempty"`
	Window           string            `json:"window,omitempty"`
	At               *time.Time        `json:"at,omitempty"` // reset, rate boundary or card expiry
	InMinutes        *int              `json:"inMinutes,omitempty"`
	RemainingPercent *float64          `json:"remainingPercent,omitempty"`
	Model            string            `json:"model,omitempty"`  // harness model id as reported
	Effort           string            `json:"effort,omitempty"` // harness effort as reported
	Count            *int              `json:"count,omitempty"`  // reset cards
	Suggest          *Step             `json:"suggest,omitempty"`
	Speed            *Speed            `json:"speed,omitempty"`
	Rate             *Rate             `json:"rate,omitempty"`
	Public           *Public           `json:"public,omitempty"`
	Stale            bool              `json:"stale,omitempty"`
	Text             map[string]string `json:"text,omitempty"` // rendered by the CLI for plugins: zh, en

	windowReset *time.Time // AnnouncedSurplus: the window's own reset when advised
}

// Input bundles everything Derive reads. Digest and State may be nil.
type Input struct {
	Report quota.Report
	Digest *digest.Digest
	State  *State
	Now    time.Time
}

func harnessOf(source string) string {
	switch source {
	case "claude-code", "codex":
		return source
	}
	return ""
}

// Derive lists the current events, most urgent first. With a State it also arms
// "switch back" for the windows it advised on and reports those whose reset has passed.
func Derive(in Input) []Event {
	now := in.Now.UTC()
	var out []Event
	sources := map[string]bool{}
	for i := range in.Report.Accounts {
		a := &in.Report.Accounts[i]
		sources[a.Source] = true
		if harnessOf(a.Source) != "" && !a.ObservedAt.IsZero() && now.Sub(a.ObservedAt) > harnessQuiet {
			continue
		}
		es := append(accountEvents(a, in.Digest, now), announcedEvents(a, in.Digest, now)...)
		if in.State != nil {
			in.State.arm(es)
		}
		out = append(out, es...)
		out = append(out, cardEvents(a, now)...)
		if a.Source == "user" && a.Plan != "" && in.Digest != nil {
			out = append(out, rateEvents(a.Plan, in.Digest, now)...)
		}
	}
	if in.State != nil {
		out = append(out, in.State.switchBack(in.Report, in.Digest, now)...)
	}
	if in.Digest != nil {
		// A spend hint already carries its announcement; do not repeat it as news.
		covered := map[string]bool{}
		for _, e := range out {
			if e.Type == AnnouncedSurplus {
				covered[e.Public.ID] = true
			}
		}
		for _, e := range publicEvents(in.Digest, sources, now) {
			if !covered[e.Public.ID] {
				out = append(out, e)
			}
		}
	}
	sort.SliceStable(out, func(i, j int) bool { return rank[out[i].Type] < rank[out[j].Type] })
	return out
}

func minutesUntil(t, now time.Time) *int {
	m := int(math.Ceil(t.Sub(now).Minutes()))
	return &m
}

func deciding(a *quota.Account) *quota.Window {
	for i := range a.Windows {
		if a.Windows[i].Kind == a.Deciding {
			return &a.Windows[i]
		}
	}
	return nil
}

func windowKey(prefix string, a *quota.Account, w *quota.Window) string {
	at := "none"
	if w.ResetsAt != nil {
		at = w.ResetsAt.UTC().Format(time.RFC3339)
	}
	return strings.Join([]string{prefix, a.Source, a.Plan, w.Kind, w.Limit, at}, "|")
}

func accountEvents(a *quota.Account, d *digest.Digest, now time.Time) []Event {
	w := deciding(a)
	if a.Headroom == "spend" {
		// Spending is allowed by every window; the hint is about whichever surplus resets first.
		w = nil
		for i := range a.Windows {
			x := &a.Windows[i]
			if x.Pace == "surplus" && x.ResetsInMinutes != nil && x.WindowMinutes > 0 && float64(*x.ResetsInMinutes) <= float64(x.WindowMinutes)*soonShare &&
				(w == nil || *x.ResetsInMinutes < *w.ResetsInMinutes) {
				w = x
			}
		}
	}
	if w == nil {
		return nil
	}
	base := func(typ, sev string) Event {
		e := Event{Type: typ, Key: windowKey(typ, a, w), Severity: sev, Source: a.Source, Plan: a.Plan, Window: w.Kind, RemainingPercent: w.RemainingPercent, Stale: a.Stale}
		if w.ResetsAt != nil {
			t := w.ResetsAt.UTC()
			e.At, e.InMinutes = &t, minutesUntil(t, now)
		}
		if h := a.Harness; h != nil {
			e.Model, e.Effort = h.Model, h.Effort
		}
		return e
	}
	cfg := current(a, d)
	switch a.Headroom {
	case "exhausted":
		e := base(WindowExhausted, "warn")
		e.Suggest = &Step{Action: "wait"}
		for _, c := range a.Cards {
			if (c.Kind == w.Kind || c.Kind == "full") && c.Count != nil && *c.Count > 0 && (c.ExpiresAt == nil || c.ExpiresAt.After(now)) {
				e.Suggest = &Step{Action: "use_card"}
			}
		}
		return []Event{e}
	case "conserve":
		e := base(WindowTight, "warn")
		e.Suggest = cfg.down()
		return []Event{e}
	case "spend":
		e := base(ResetSoonSurplus, "info")
		e.Suggest = cfg.up(d)
		e.Speed = quotaSpeed(cfg, d, a.Source)
		return []Event{e}
	}
	return nil
}

// config is the harness's current model and effort, resolved against the publication.
type config struct {
	model *digest.Model
	cur   *digest.Effort // what the harness reports, else ★
	rec   *digest.Effort
}

func current(a *quota.Account, d *digest.Digest) config {
	var c config
	h, hn := a.Harness, harnessOf(a.Source)
	if d == nil || h == nil || h.Model == "" || hn == "" {
		return c
	}
	c.model = d.Model(h.Model)
	if c.model == nil {
		c.model = d.Match(hn, h.Model)
	}
	if c.model == nil {
		return c
	}
	c.rec = c.model.Rec()
	c.cur = c.rec
	if h.Effort != "" {
		if e := c.model.Effort(h.Effort); e != nil {
			c.cur = e
		}
	}
	return c
}

func index(m *digest.Model, e *digest.Effort) int {
	for i := range m.Efforts {
		if &m.Efforts[i] == e {
			return i
		}
	}
	return -1
}

func ratio(hi, lo *digest.Effort) (*float64, *float64) {
	if hi == nil || lo == nil || hi.Ability == nil || lo.Ability == nil || hi.Cost == nil || lo.Cost == nil || *lo.Cost <= 0 || hi.CostBasisID != lo.CostBasisID {
		return nil, nil
	}
	a := math.Round((*hi.Ability-*lo.Ability)*10) / 10
	r := math.Round(*hi.Cost / *lo.Cost * 100) / 100
	return &a, &r
}

func (c config) step(action string, e *digest.Effort) *Step {
	s := &Step{Action: action, Model: c.model.ID, ModelName: c.model.Name, Effort: e.Effort, Label: e.Label, Recommended: e == c.rec}
	s.AbilityDelta, s.CostRatio = ratio(e, c.cur)
	return s
}

// up: the next effort that actually scores higher, else the developer's strongest model at ★.
func (c config) up(d *digest.Digest) *Step {
	if c.model == nil || c.cur == nil {
		return &Step{Action: "step_up"}
	}
	i := index(c.model, c.cur)
	for j := i + 1; i >= 0 && j < len(c.model.Efforts); j++ {
		e := &c.model.Efforts[j]
		if e.Ability != nil && c.cur.Ability != nil && *e.Ability > *c.cur.Ability {
			return c.step("step_up", e)
		}
	}
	if l := d.Lineup(c.model.DeveloperID); l != nil {
		var best string
		for _, r := range l.Members {
			if r.Status == "" && r.Has("strongest") {
				best = r.ID
			}
		}
		if m := d.Model(best); m != nil && best != c.model.ID {
			if rec := m.Rec(); rec != nil && rec.Ability != nil && c.cur.Ability != nil && *rec.Ability > *c.cur.Ability {
				s := &Step{Action: "stronger_model", Model: m.ID, ModelName: m.Name, Effort: rec.Effort, Label: rec.Label, Recommended: true}
				s.AbilityDelta, s.CostRatio = ratio(rec, c.cur)
				return s
			}
		}
	}
	return &Step{Action: "none"}
}

// quotaSpeed: the harness's Fast tier for this model when it draws plan quota (Codex), so
// a surplus can pay for speed. Claude Code fast mode bills usage credits and never qualifies.
func quotaSpeed(c config, d *digest.Digest, harness string) *Speed {
	if c.model == nil || d == nil {
		return nil
	}
	for _, t := range d.SpeedTiers(c.model.ID, harness) {
		if r := t.Rate("subscription"); t.Tier == "fast" && r != nil && r.BillsTo == "plan-quota" {
			return &Speed{Tier: t.Tier, Label: t.Label, QuotaRatio: r.Ratio, SpeedRatio: t.Model.Speed.Ratio, Qualifier: t.Model.Speed.Qualifier}
		}
	}
	return nil
}

// down: back to ★ when above it, otherwise one effort lower.
func (c config) down() *Step {
	if c.model == nil || c.cur == nil {
		return &Step{Action: "step_down"}
	}
	if c.rec != nil && c.cur != c.rec && index(c.model, c.cur) > index(c.model, c.rec) {
		return c.step("step_down", c.rec)
	}
	if i := index(c.model, c.cur); i > 0 {
		return c.step("step_down", &c.model.Efforts[i-1])
	}
	return &Step{Action: "none"}
}

// ---- Public data

type resetSummary struct {
	ID          string `json:"id"`
	Provider    string `json:"provider"`
	EventType   string `json:"eventType"`
	Status      string `json:"status"`
	PublishedAt string `json:"publishedAt"`
	URL         string `json:"url"`
	Schedule    *struct {
		Through string `json:"through"`
		Label   string `json:"label"`
	} `json:"schedule"`
}

// announcedEvents: a reset the provider announced for a time within announcedLead, while this
// account's longer window still has announcedMinLeft% that would otherwise last past it. The
// window is armed for the announced time; switching back waits for a reading that shows the
// window really restarted (State.switchBack).
func announcedEvents(a *quota.Account, d *digest.Digest, now time.Time) []Event {
	if d == nil || harnessOf(a.Source) == "" || a.Headroom == "conserve" || a.Headroom == "exhausted" {
		return nil
	}
	var w *quota.Window
	for i := range a.Windows {
		x := &a.Windows[i]
		if x.WindowMinutes > 300 && x.RemainingPercent != nil && x.ResetsAt != nil && (w == nil || x.WindowMinutes > w.WindowMinutes) {
			w = x
		}
	}
	if w == nil || *w.RemainingPercent < announcedMinLeft {
		return nil
	}
	var best *resetSummary
	var bestAt time.Time
	for _, raw := range d.Resets {
		var r resetSummary
		if json.Unmarshal(raw, &r) != nil || r.ID == "" || r.EventType != "direct_reset_announced" || r.Schedule == nil ||
			providerSource[r.Provider] != a.Source || r.Status == "withdrawn" || r.Status == "cancelled" {
			continue
		}
		t, err := time.Parse(time.RFC3339, r.Schedule.Through)
		if err != nil || !t.After(now) || t.Sub(now) > announcedLead || !w.ResetsAt.After(t) {
			continue
		}
		if best == nil || t.Before(bestAt) {
			best, bestAt = &r, t
		}
	}
	if best == nil {
		return nil
	}
	t := bestAt.UTC()
	e := Event{Type: AnnouncedSurplus, Key: strings.Join([]string{AnnouncedSurplus, a.Source, a.Plan, w.Kind, best.ID}, "|"), Severity: "info",
		Source: a.Source, Plan: a.Plan, Window: w.Kind, At: &t, InMinutes: minutesUntil(t, now), RemainingPercent: w.RemainingPercent, Stale: a.Stale,
		Public:      &Public{ID: best.ID, Provider: best.Provider, EventType: best.EventType, Status: best.Status, URL: best.URL, When: best.Schedule.Label},
		windowReset: w.ResetsAt}
	if h := a.Harness; h != nil {
		e.Model, e.Effort = h.Model, h.Effort
	}
	cfg := current(a, d)
	e.Suggest = cfg.up(d)
	e.Speed = quotaSpeed(cfg, d, a.Source)
	return []Event{e}
}

// providerSource: whose public resets matter to which local account.
var providerSource = map[string]string{"openai": "codex"}

func publicEvents(d *digest.Digest, sources map[string]bool, now time.Time) []Event {
	var out []Event
	for _, raw := range d.Resets {
		var r resetSummary
		if json.Unmarshal(raw, &r) != nil || r.ID == "" {
			continue
		}
		src := providerSource[r.Provider]
		if src == "" || !sources[src] || r.Status == "withdrawn" || r.Status == "cancelled" {
			continue
		}
		p, err := time.Parse(time.RFC3339, r.PublishedAt)
		if err != nil || p.After(now.Add(5*time.Minute)) || now.Sub(p) > publicFresh {
			continue
		}
		// An announcement whose own time has passed is no longer news; its completion is.
		if r.Schedule != nil {
			if t, err := time.Parse(time.RFC3339, r.Schedule.Through); err == nil && r.EventType == "direct_reset_announced" && t.Before(now) {
				continue
			}
		}
		out = append(out, Event{Type: PublicReset, Key: PublicReset + "|" + r.ID, Severity: "info", Source: src,
			Public: &Public{ID: r.ID, Provider: r.Provider, EventType: r.EventType, Status: r.Status, URL: r.URL}})
	}
	return out
}

// rateEvents: a published quota-rate boundary for this plan within the next hour.
func rateEvents(plan string, d *digest.Digest, now time.Time) []Event {
	if d.MultiplierHorizon == nil {
		return nil
	}
	to, err := time.Parse(time.RFC3339, d.MultiplierHorizon.To)
	if err != nil {
		return nil
	}
	var models []string
	seen := map[string]bool{}
	var bounds []time.Time
	for _, m := range d.Multipliers {
		if !contains(m.PlanIDs, plan) {
			continue
		}
		for _, id := range m.Models {
			if !seen[id] {
				seen[id] = true
				models = append(models, id)
			}
		}
		for _, s := range []string{m.StartsAt, m.EndsAt} {
			if t, err := time.Parse(time.RFC3339, s); err == nil && t.After(now) && !t.After(now.Add(rateLead)) && t.Before(to) {
				bounds = append(bounds, t)
			}
		}
	}
	if len(models) == 0 || len(bounds) == 0 {
		return nil
	}
	sort.Slice(bounds, func(i, j int) bool { return bounds[i].Before(bounds[j]) })
	b := bounds[0]
	// One event per plan: the first listed model whose rate changes at the boundary.
	for _, model := range models {
		from, fs := rateAt(d.Multipliers, plan, model, now)
		next, ns := rateAt(d.Multipliers, plan, model, b)
		if next == nil || (from != nil && *from == *next) {
			continue
		}
		typ := PeakStartsSoon
		if from != nil && *next < *from {
			typ = OffpeakStartsSoon
		}
		status := "CONFIRMED"
		if fs != "CONFIRMED" || ns != "CONFIRMED" {
			status = "TENTATIVE"
		}
		t := b.UTC()
		return []Event{{Type: typ, Key: strings.Join([]string{typ, plan, model, t.Format(time.RFC3339)}, "|"), Severity: "info", Source: "user", Plan: plan,
			At: &t, InMinutes: minutesUntil(t, now), Rate: &Rate{Model: model, From: from, To: next, Status: status}}}
	}
	return nil
}

// rateAt applies the published selection (highest priority, no stacking) for one plan and
// model; conflicting top-priority coefficients or a null one give an unknown rate.
func rateAt(ws []digest.MultiplierWindow, plan, model string, at time.Time) (*float64, string) {
	best, status := -1<<31, ""
	var rate *float64
	conflict := false
	for _, m := range ws {
		if !contains(m.PlanIDs, plan) || (len(m.Models) > 0 && !contains(m.Models, model)) {
			continue
		}
		s, err1 := time.Parse(time.RFC3339, m.StartsAt)
		e, err2 := time.Parse(time.RFC3339, m.EndsAt)
		if err1 != nil || err2 != nil || at.Before(s) || !at.Before(e) {
			continue
		}
		switch {
		case m.Priority > best:
			best, rate, status, conflict = m.Priority, m.Multiplier, m.Status, m.Multiplier == nil
		case m.Priority == best:
			if m.Multiplier == nil || rate == nil || *m.Multiplier != *rate {
				conflict = true
			}
			if m.Status != "CONFIRMED" {
				status = m.Status
			}
		}
	}
	if conflict {
		return nil, "unknown"
	}
	return rate, status
}

func contains(xs []string, v string) bool {
	for _, x := range xs {
		if x == v {
			return true
		}
	}
	return false
}

// cardEvents: reset cards about to expire unused.
func cardEvents(a *quota.Account, now time.Time) []Event {
	var out []Event
	for _, c := range a.Cards {
		if c.Count == nil || *c.Count <= 0 || c.ExpiresAt == nil || !c.ExpiresAt.After(now) || c.ExpiresAt.Sub(now) > cardLead {
			continue
		}
		t := c.ExpiresAt.UTC()
		out = append(out, Event{Type: CardsExpiring, Key: strings.Join([]string{CardsExpiring, a.Plan, c.Kind, t.Format(time.RFC3339)}, "|"), Severity: "info",
			Source: a.Source, Plan: a.Plan, Window: c.Kind, At: &t, InMinutes: minutesUntil(t, now), Count: c.Count})
	}
	return out
}
