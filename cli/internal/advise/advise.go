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
	"github.com/modelplan/modelplan/cli/internal/lineup"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// Event types, most urgent first (Rank).
const (
	WindowExhausted = "window_exhausted"
	WindowTight     = "window_tight"
	WindowPace      = "window_pace_warning"
	SwitchBack      = "reset_passed_switch_back"
	// BetterModel: the publication marks the session's model as beaten (dominatedBy), and the
	// model that beats it runs in this harness at an effort that scores within a tie for clearly
	// less. Told once per model and effort; the status line shows it for betterShown after that.
	BetterModel      = "better_model_available"
	ResetSoonSurplus = "reset_soon_with_surplus"
	// AnnouncedSurplus: a provider announced a reset for a stated time; if it covers this account,
	// what is left in the longer window is void then. Never proof that it covers this account.
	AnnouncedSurplus  = "announced_reset_with_surplus"
	PeakStartsSoon    = "peak_starts_soon"
	OffpeakStartsSoon = "offpeak_starts_soon"
	CardsExpiring     = "cards_expiring"
	PublicReset       = "public_reset_announced"
)

var rank = map[string]int{WindowExhausted: 0, WindowPace: 1, WindowTight: 2, SwitchBack: 2, BetterModel: 3, ResetSoonSurplus: 4, AnnouncedSurplus: 5, PeakStartsSoon: 6, OffpeakStartsSoon: 7, CardsExpiring: 8, PublicReset: 9}

const (
	// A surplus counts as "reset soon" in the last quarter of the window, as in quota's pace rule.
	soonShare = 0.25
	// Rate changes and card expiries are announced this far ahead.
	rateLead = 60 * time.Minute
	cardLead = 48 * time.Hour
	// Public resets are news for a day after publication.
	publicFresh = 24 * time.Hour
	// "Switch back" waits this long after the reset for the user's next prompt (back from a
	// break or the next morning), and the status line shows it for switchBackShown after that.
	switchBackFor   = 24 * time.Hour
	switchBackShown = 90 * time.Minute
	// Harness readings older than this belong to a finished session; no hints from them.
	harnessQuiet = 6 * time.Hour
	// An announced reset is worth spending ahead of within this lead, when at least this much of
	// the longer window is left and that window would not reset on its own before it.
	announcedLead    = 24 * time.Hour
	announcedMinLeft = 20.0
	// A reset can land before the post that announces it is seen, or a little before the post
	// itself: a window that began within announcedTrail before the post already had it. A window
	// with announcedRise points more left than when we advised had it too.
	announcedTrail = 6 * time.Hour
	announcedRise  = 10.0
	// Another model is worth naming when it costs at most betterSaving of the current
	// configuration. Once told, the status line keeps it for betterShown, and the hint is not
	// repeated for betterFor: a user still on that model a week later chose it.
	betterSaving = 0.7
	betterShown  = 7 * 24 * time.Hour
	betterFor    = 90 * 24 * time.Hour
)

// Step is a concrete suggestion against what the harness reports now.
type Step struct {
	Action       string   `json:"action"` // step_up | stronger_model | step_down | cheaper_model | switch_back | wait | use_card | effort_free | wait_offpeak | none
	Model        string   `json:"model,omitempty"`
	ModelName    string   `json:"modelName,omitempty"`
	Effort       string   `json:"effort,omitempty"` // native key
	Label        string   `json:"label,omitempty"`  // display label
	Recommended  bool     `json:"recommended,omitempty"`
	ModelChange  bool     `json:"modelChange,omitempty"`  // switch_back: to another model than the current one
	Kind         string   `json:"kind,omitempty"`         // better_model, cheaper_model: equivalent (within the lineup's tie) | stronger
	AbilityDelta *float64 `json:"abilityDelta,omitempty"` // vs the current configuration
	CostRatio    *float64 `json:"costRatio,omitempty"`    // vs the current configuration, in the plan's units when known
	// wait_offpeak: when the model's time-of-day rate drops, and from what to what.
	At        *time.Time `json:"at,omitempty"`
	InMinutes *int       `json:"inMinutes,omitempty"`
	RateFrom  *float64   `json:"rateFrom,omitempty"`
	RateTo    *float64   `json:"rateTo,omitempty"`
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
	Type             string     `json:"type"`
	Key              string     `json:"key"`
	Severity         string     `json:"severity"` // warn | info
	Source           string     `json:"source"`   // claude-code | codex | user | public
	Plan             string     `json:"plan,omitempty"`
	Basis            string     `json:"basis,omitempty"` // the declared plan's billing basis, for a session linked to it
	Window           string     `json:"window,omitempty"`
	Limit            string     `json:"limit,omitempty"` // the window's allowance when not the main one (Codex: reserve)
	At               *time.Time `json:"at,omitempty"`    // reset, rate boundary or card expiry
	InMinutes        *int       `json:"inMinutes,omitempty"`
	RemainingPercent *float64   `json:"remainingPercent,omitempty"`
	// RunsOutInMinutes: at the recent rate of use the window is used up this soon, before its reset.
	RunsOutInMinutes *int   `json:"runsOutInMinutes,omitempty"`
	Model            string `json:"model,omitempty"`  // harness model id as reported
	Effort           string `json:"effort,omitempty"` // harness effort as reported
	Count            *int   `json:"count,omitempty"`  // reset cards
	// Credits: window_exhausted only; the account's usage credits, which the harness draws on now.
	Credits *quota.Credits `json:"credits,omitempty"`
	Suggest *Step          `json:"suggest,omitempty"`
	// Alternative: when a window is tight, a cheaper configuration of another published model
	// that scores at least as high as the current one (action cheaper_model).
	Alternative *Step `json:"alternative,omitempty"`
	// Current: better_model only; the configuration in use, as published.
	Current *Step  `json:"current,omitempty"`
	Speed   *Speed `json:"speed,omitempty"`
	// Fast: the harness runs the plan-quota Fast tier now (Codex), with what it costs.
	Fast *Speed `json:"fast,omitempty"`
	// FastOff: switch back only; Fast was turned on since the advice and draws extra quota.
	FastOff bool              `json:"fastOff,omitempty"`
	Rate    *Rate             `json:"rate,omitempty"`
	Public  *Public           `json:"public,omitempty"`
	Stale   bool              `json:"stale,omitempty"`
	Text    map[string]string `json:"text,omitempty"` // rendered by the CLI for plugins: zh, en

	windowReset *time.Time // AnnouncedSurplus: the window's own reset when advised
	noted       *time.Time // SwitchBack: when it was first derived
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
	var linked map[string]bool
	if in.Digest != nil {
		linked = linkedPlans(in.Report, in.Digest)
	}
	for i := range in.Report.Accounts {
		a := &in.Report.Accounts[i]
		sources[a.Source] = true
		if harnessOf(a.Source) != "" && !a.ObservedAt.IsZero() && now.Sub(a.ObservedAt) > harnessQuiet {
			continue
		}
		// Other plans (Cursor, Copilot, …, read natively or through CodexBar) are shown by `quota`
		// and the dashboards; a prompt in Claude Code or Codex does not draw on them, so they give
		// no hints there.
		if strings.HasPrefix(a.Source, "codexbar:") || strings.HasPrefix(a.Source, "native:") {
			continue
		}
		var plan *Plan
		if harnessOf(a.Source) != "" && in.Digest != nil {
			if eff, p := Link(a, in.Report, in.Digest); p != nil {
				a, plan = &eff, p
			}
		}
		var es []Event
		// A declared plan a session is linked to is advised through that session.
		if !(a.Source == "user" && linked[strings.ToLower(a.Plan)]) {
			es = append(accountEvents(a, in.Digest, now, plan), announcedEvents(a, in.Digest, in.State, now)...)
			es = append(es, paceEvents(a, in.State, now)...)
		}
		if in.State != nil {
			in.State.arm(es)
		}
		out = append(out, es...)
		if plan == nil && harnessOf(a.Source) != "" {
			out = append(out, betterEvents(a, in.Digest, now)...)
		}
		out = append(out, cardEvents(a, now)...)
		if a.Source == "user" && a.Plan != "" && in.Digest != nil {
			out = append(out, rateEvents(a, in.Digest, now)...)
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
		for _, e := range publicEvents(in.Digest, sources, in.Report, in.State, now) {
			if !covered[e.Public.ID] {
				out = append(out, e)
			}
		}
	}
	out = dropRepeatedSwitch(out)
	if in.State != nil {
		for i := range out {
			if out[i].Type == BetterModel {
				out[i].noted = in.State.firstNoted(out[i].Key)
			}
		}
	}
	sort.SliceStable(out, func(i, j int) bool { return rank[out[i].Type] < rank[out[j].Type] })
	return out
}

// dropRepeatedSwitch: a tight window that already offers the same model says it; the better-model
// hint waits for a reading that is not tight.
func dropRepeatedSwitch(es []Event) []Event {
	offered := map[string]bool{}
	for _, e := range es {
		if e.Type == WindowTight && e.Alternative != nil {
			offered[e.Source+"|"+e.Alternative.Model] = true
		}
	}
	kept := es[:0]
	for _, e := range es {
		if e.Type == BetterModel && e.Suggest != nil && offered[e.Source+"|"+e.Suggest.Model] {
			continue
		}
		kept = append(kept, e)
	}
	return kept
}

// betterEvents: a better model for the session's configuration, when there is one.
func betterEvents(a *quota.Account, d *digest.Digest, now time.Time) []Event {
	cfg := current(a, d)
	s := cfg.better(d, harnessOf(a.Source))
	if s == nil {
		return nil
	}
	cur := cfg.step("current", cfg.cur)
	cur.AbilityDelta, cur.CostRatio = nil, nil
	e := Event{Type: BetterModel, Severity: "info", Source: a.Source, Plan: a.Plan, Stale: a.Stale, Suggest: s, Current: cur,
		Key: strings.Join([]string{"better", a.Source, cfg.model.ID, cfg.cur.Effort, s.Model, s.Effort}, "|")}
	if h := a.Harness; h != nil {
		e.Model, e.Effort = h.Model, h.Effort
	}
	return []Event{e}
}

func minutesUntil(t, now time.Time) *int {
	m := int(math.Ceil(t.Sub(now).Minutes()))
	return &m
}

func deciding(a *quota.Account) *quota.Window {
	for i := range a.Windows {
		if a.Windows[i].Kind == a.Deciding && a.InPool(&a.Windows[i]) {
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

// resetSoonSurplus: a window of the account's pool in its last quarter with a surplus.
func resetSoonSurplus(a *quota.Account, w *quota.Window) bool {
	return a.InPool(w) && w.Pace == "surplus" && w.ResetsInMinutes != nil && w.WindowMinutes > 0 &&
		float64(*w.ResetsInMinutes) <= float64(w.WindowMinutes)*soonShare
}

func accountEvents(a *quota.Account, d *digest.Digest, now time.Time, plan *Plan) []Event {
	w := deciding(a)
	if a.Headroom == "spend" {
		// Spending is allowed by every window; the hint is about whichever surplus resets first.
		w = nil
		for i := range a.Windows {
			x := &a.Windows[i]
			if resetSoonSurplus(a, x) && (w == nil || *x.ResetsInMinutes < *w.ResetsInMinutes) {
				w = x
			}
		}
	}
	if w == nil {
		return nil
	}
	base := func(typ, sev string) Event {
		e := Event{Type: typ, Key: windowKey(typ, a, w), Severity: sev, Source: a.Source, Plan: a.Plan, Window: w.Kind, Limit: w.Limit, RemainingPercent: w.RemainingPercent, RunsOutInMinutes: w.RunsOutInMinutes, Stale: a.Stale}
		if plan != nil {
			e.Basis = plan.Basis
		}
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
	cfg.plan, cfg.now = plan, now
	fast := fastNow(a, cfg, d)
	switch a.Headroom {
	case "exhausted":
		e := base(WindowExhausted, "warn")
		e.Suggest = &Step{Action: "wait"}
		e.Credits = a.Credits
		for _, c := range a.Cards {
			if (c.Kind == w.Kind || c.Kind == "full") && c.Count != nil && *c.Count > 0 && (c.ExpiresAt == nil || c.ExpiresAt.After(now)) {
				e.Suggest = &Step{Action: "use_card"}
			}
		}
		return []Event{e}
	case "conserve":
		e := base(WindowTight, "warn")
		e.Suggest = cfg.down()
		if plan != nil && plan.Basis == digest.BasisRequest && cfg.model != nil {
			// Counted per request: a lower effort saves nothing. An off-peak start before the
			// reset (and soon) does.
			e.Suggest = &Step{Action: "effort_free"}
			until := now.Add(offpeakWait)
			if w.ResetsAt != nil && w.ResetsAt.Before(until) {
				until = *w.ResetsAt
			}
			if t, from, to := plan.cheaperLater(cfg.model, now, until); t != nil {
				e.Suggest = &Step{Action: "wait_offpeak", At: t, InMinutes: minutesUntil(*t, now), RateFrom: from, RateTo: to}
			}
		}
		e.Alternative = cfg.cheaper(d, harnessOf(a.Source))
		e.Fast = fast // turning Fast off comes first: same answers, a fraction of the quota
		return []Event{e}
	case "spend":
		e := base(ResetSoonSurplus, "info")
		e.Suggest = cfg.up(d)
		if fast == nil {
			e.Speed = quotaSpeed(cfg, d, a.Source)
		}
		e.Fast = fast
		return []Event{e}
	}
	return nil
}

// config is the harness's current model and effort, resolved against the publication.
type config struct {
	model *digest.Model
	cur   *digest.Effort // what the harness reports, else ★
	rec   *digest.Effort
	plan  *Plan // the declared plan paying for a model on another vendor's endpoint
	now   time.Time
}

func current(a *quota.Account, d *digest.Digest) config {
	var c config
	h, hn := a.Harness, harnessOf(a.Source)
	if d == nil || h == nil || h.Model == "" || hn == "" {
		return c
	}
	c.model = d.Model(h.Model)
	if c.model == nil {
		c.model = d.MatchAt(hn, h.Endpoint, h.Model)
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

// ratioTo: ability and cost of (m, e) against the current configuration; the cost in the
// declared plan's units when the session is linked to one (nil where the plan gives no number).
func (c config) ratioTo(m *digest.Model, e *digest.Effort) (*float64, *float64) {
	if c.plan == nil {
		return ratio(e, c.cur)
	}
	var a *float64
	if e.Ability != nil && c.cur.Ability != nil {
		x := math.Round((*e.Ability-*c.cur.Ability)*10) / 10
		a = &x
	}
	hi, lo := c.plan.cost(m, e, c.now, m.ID != c.model.ID), c.plan.cost(c.model, c.cur, c.now, false)
	if hi == nil || lo == nil || *lo <= 0 {
		return a, nil
	}
	r := math.Round(*hi / *lo * 100) / 100
	return a, &r
}

func (c config) step(action string, e *digest.Effort) *Step {
	s := &Step{Action: action, Model: c.model.ID, ModelName: c.model.Name, Effort: e.Effort, Label: e.Label, Recommended: e == c.rec}
	s.AbilityDelta, s.CostRatio = c.ratioTo(c.model, e)
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
		if m := d.Model(best); m != nil && best != c.model.ID && (c.plan == nil || c.plan.m.Row(m.ID) != nil) {
			if rec := m.Rec(); rec != nil && rec.Ability != nil && c.cur.Ability != nil && *rec.Ability > *c.cur.Ability {
				s := &Step{Action: "stronger_model", Model: m.ID, ModelName: m.Name, Effort: rec.Effort, Label: rec.Label, Recommended: true}
				s.AbilityDelta, s.CostRatio = c.ratioTo(m, rec)
				return s
			}
		}
	}
	return &Step{Action: "none"}
}

// tie: the lineup's published comparison tolerance in points (scores this close are equivalent).
func tie(l *lineup.Lineup) float64 {
	if l != nil && l.Tie > 0 {
		return l.Tie
	}
	return lineup.Tie
}

// better: when the publication marks the session's model as beaten by another (dominatedBy,
// weaker or equivalent at ★), that model's cheapest effort usable in this harness that scores
// within a tie of the current configuration and costs at most betterSaving of it. It follows
// the published verdict; nil when the model is not beaten or nothing qualifies.
func (c config) better(d *digest.Digest, harness string) *Step {
	if c.model == nil || !crossModel(c.cur) || c.cur.Ability == nil || c.cur.Cost == nil || c.plan != nil || d == nil || harness == "" {
		return nil
	}
	l := d.Lineup(c.model.DeveloperID)
	r := (*lineup.Row)(nil)
	if l != nil {
		r = l.Row(c.model.ID)
	}
	if r == nil || r.DominatedBy == nil {
		return nil
	}
	m := d.Model(r.DominatedBy.ID)
	if m == nil || m.ID == c.model.ID || len(m.HarnessIDs[harness]) == 0 {
		return nil
	}
	t := tie(l)
	var best *digest.Effort
	for i := range m.Efforts {
		e := &m.Efforts[i]
		if !crossModel(e) || e.Ability == nil || e.Cost == nil || e.CostBasisID != c.cur.CostBasisID || *e.Ability < *c.cur.Ability-t || *e.Cost > *c.cur.Cost*betterSaving {
			continue
		}
		if best == nil || *e.Cost < *best.Cost {
			best = e
		}
	}
	if best == nil {
		return nil
	}
	s := &Step{Action: "better_model", Model: m.ID, ModelName: m.Name, Effort: best.Effort, Label: best.Label, Recommended: best == m.Rec(), Kind: kindOf(*best.Ability-*c.cur.Ability, t)}
	s.AbilityDelta, s.CostRatio = ratio(best, c.cur)
	return s
}

// crossModel reports whether a configuration may be compared with another model's. A provisional
// ability is published for its own model's ladder only.
func crossModel(e *digest.Effort) bool { return e != nil && !e.Provisional }

func kindOf(delta, tie float64) string {
	if delta > tie {
		return "stronger"
	}
	return "equivalent"
}

// cheaper: the lowest-cost effort of another model in the developer's published lineup, usable
// in this harness, that scores within the lineup's tie of the current configuration or higher, on
// the same cost basis. Lowering the effort trades ability for quota; this keeps it. Nil when none
// qualifies.
func (c config) cheaper(d *digest.Digest, harness string) *Step {
	if c.plan != nil {
		return c.cheaperInPlan(d, harness)
	}
	if c.model == nil || !crossModel(c.cur) || c.cur.Ability == nil || c.cur.Cost == nil || d == nil || harness == "" {
		return nil
	}
	l := d.Lineup(c.model.DeveloperID)
	if l == nil {
		return nil
	}
	var best *digest.Effort
	var bestModel *digest.Model
	for _, r := range l.Members {
		m := d.Model(r.ID)
		if m == nil || r.Status != "" || m.ID == c.model.ID || len(m.HarnessIDs[harness]) == 0 {
			continue
		}
		for i := range m.Efforts {
			e := &m.Efforts[i]
			if !crossModel(e) || e.Ability == nil || e.Cost == nil || e.CostBasisID != c.cur.CostBasisID || *e.Ability < *c.cur.Ability-tie(l) || *e.Cost >= *c.cur.Cost {
				continue
			}
			if best == nil || *e.Cost < *best.Cost || (*e.Cost == *best.Cost && *e.Ability > *best.Ability) {
				best, bestModel = e, m
			}
		}
	}
	if best == nil {
		return nil
	}
	s := &Step{Action: "cheaper_model", Model: bestModel.ID, ModelName: bestModel.Name, Effort: best.Effort, Label: best.Label, Recommended: best == bestModel.Rec(), Kind: kindOf(*best.Ability-*c.cur.Ability, tie(l))}
	s.AbilityDelta, s.CostRatio = ratio(best, c.cur)
	return s
}

// cheaperInPlan: as cheaper, among the models the declared plan meters, by what the plan charges
// now. A plan where each model has its own pool, or with unpublished rates, has no cross-model
// cost: nil.
func (c config) cheaperInPlan(d *digest.Digest, harness string) *Step {
	if c.model == nil || !crossModel(c.cur) || c.cur.Ability == nil || harness == "" {
		return nil
	}
	lo := c.plan.cost(c.model, c.cur, c.now, false)
	if lo == nil {
		return nil
	}
	var best *digest.Effort
	var bestModel *digest.Model
	var bestCost float64
	for _, r := range c.plan.m.Rows {
		m := d.Model(r.ModelID)
		if m == nil || m.ID == c.model.ID || len(m.HarnessIDs[harness]) == 0 {
			continue
		}
		for i := range m.Efforts {
			e := &m.Efforts[i]
			v := c.plan.cost(m, e, c.now, true)
			if !crossModel(e) || e.Ability == nil || v == nil || *e.Ability < *c.cur.Ability || *v >= *lo {
				continue
			}
			if best == nil || *v < bestCost || (*v == bestCost && *e.Ability > *best.Ability) {
				best, bestModel, bestCost = e, m, *v
			}
		}
	}
	if best == nil {
		return nil
	}
	s := &Step{Action: "cheaper_model", Model: bestModel.ID, ModelName: bestModel.Name, Effort: best.Effort, Label: best.Label, Recommended: best == bestModel.Rec()}
	s.AbilityDelta, s.CostRatio = c.ratioTo(bestModel, best)
	return s
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

// fastNow: the Fast tier the harness runs now, when it draws plan quota (Codex only).
func fastNow(a *quota.Account, c config, d *digest.Digest) *Speed {
	if a.Harness == nil || a.Harness.ServiceTier != "fast" {
		return nil
	}
	return quotaSpeed(c, d, harnessOf(a.Source))
}

// NoticeSteps is what a low quota notice to the model may name, from the thread's own reported
// model and effort (never another thread's). Above ★: the step to ★, when it saves quota on
// this plan. At or below ★ no step down (★ is where the effort is worth its cost); only another
// model that scores as well for less, when one exists.
func NoticeSteps(a *quota.Account, r quota.Report, d *digest.Digest, now time.Time) (down, cheaper *Step) {
	if a == nil || a.Harness == nil || a.Harness.Effort == "" || a.Harness.Attribution != "current-thread" || d == nil {
		return nil, nil
	}
	eff, plan := Link(a, r, d)
	c := current(&eff, d)
	c.plan, c.now = plan, now
	if c.model == nil || c.cur == nil || c.model.Effort(a.Harness.Effort) == nil {
		return nil, nil
	}
	if c.rec != nil && index(c.model, c.cur) > index(c.model, c.rec) {
		if s := c.step("step_down", c.rec); s.CostRatio != nil && *s.CostRatio < 1 {
			return s, nil
		}
		return nil, nil
	}
	return nil, c.cheaper(d, harnessOf(a.Source))
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
// window really restarted (State.switchBack). Nothing once the reset has reached this account,
// whatever the announcement still says: spending ahead would spend the restored allowance.
func announcedEvents(a *quota.Account, d *digest.Digest, s *State, now time.Time) []Event {
	if d == nil || harnessOf(a.Source) == "" || a.Headroom == "conserve" || a.Headroom == "exhausted" {
		return nil
	}
	w := longerWindow(a)
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
		// Only a reading taken after the post can tell whether the reset already came.
		if landed, known := announcedLanded(a, w, s, r); landed || !known {
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
	e := Event{Type: AnnouncedSurplus, Key: announcedKey(a, w, best.ID), Severity: "info",
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

// longerWindow: the account's longest pooled window past five hours with a known balance and reset.
func longerWindow(a *quota.Account) *quota.Window {
	var w *quota.Window
	for i := range a.Windows {
		x := &a.Windows[i]
		if a.InPool(x) && x.WindowMinutes > 300 && x.RemainingPercent != nil && x.ResetsAt != nil && (w == nil || x.WindowMinutes > w.WindowMinutes) {
			w = x
		}
	}
	return w
}

// announcedLanded: whether an announced reset already reached this account. A window that began
// after the post, or within announcedTrail before it, had it; so did one we advised on that has
// since restarted or has more left. known is false when the reading predates the post.
func announcedLanded(a *quota.Account, w *quota.Window, s *State, r resetSummary) (landed, known bool) {
	p, err := time.Parse(time.RFC3339, r.PublishedAt)
	if err != nil || w.ObservedAt.Before(p) {
		return false, false
	}
	began := w.ResetsAt.Add(-time.Duration(w.WindowMinutes) * time.Minute)
	return began.After(p.Add(-announcedTrail)) || s.reachedKey(a, announcedKey(a, w, r.ID)), true
}

func announcedKey(a *quota.Account, w *quota.Window, id string) string {
	return strings.Join([]string{AnnouncedSurplus, a.Source, a.Plan, w.Kind, id}, "|")
}

// providerSource: whose public resets matter to which local account.
var providerSource = map[string]string{"openai": "codex"}

func publicEvents(d *digest.Digest, sources map[string]bool, rep quota.Report, s *State, now time.Time) []Event {
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
		// Nor once the local reading shows it already reached the account: "will reset" would mislead.
		if r.EventType == "direct_reset_announced" && announcedReached(rep, s, src, r) {
			continue
		}
		out = append(out, Event{Type: PublicReset, Key: PublicReset + "|" + r.ID, Severity: "info", Source: src,
			Public: &Public{ID: r.ID, Provider: r.Provider, EventType: r.EventType, Status: r.Status, URL: r.URL}})
	}
	return out
}

func announcedReached(rep quota.Report, s *State, src string, r resetSummary) bool {
	for i := range rep.Accounts {
		a := &rep.Accounts[i]
		if a.Source != src {
			continue
		}
		if w := longerWindow(a); w != nil {
			if landed, _ := announcedLanded(a, w, s, r); landed {
				return true
			}
		}
	}
	return false
}

// rateEvents: a published quota-rate boundary for this declared plan within the next hour. A
// plan with published metering takes its windows by its time rules, else by the windows' planIds.
func rateEvents(a *quota.Account, d *digest.Digest, now time.Time) []Event {
	plan := a.Plan
	p := planOf(a, d)
	if p == nil {
		p = &Plan{ID: plan, Generation: a.Generation, Region: a.Region, d: d, rules: map[string]bool{}}
	}
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
	for i := range d.Multipliers {
		m := &d.Multipliers[i]
		if !p.appliesTo(m) {
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
		match := func(w *digest.MultiplierWindow) bool {
			return p.appliesTo(w) && (len(w.Models) == 0 || contains(w.Models, model))
		}
		from, fs := publishedRate(p.timeDigest(), match, now)
		next, ns := publishedRate(p.timeDigest(), match, b)
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

// rateAt applies the published selection (highest priority, no stacking) over the windows
// that match one plan and model; conflicting top-priority coefficients or a null one give an
// unknown rate.
func rateAt(ws []digest.MultiplierWindow, match func(*digest.MultiplierWindow) bool, at time.Time) (*float64, string) {
	best, status := -1<<31, ""
	var rate *float64
	conflict := false
	for i := range ws {
		m := &ws[i]
		if !match(m) {
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
