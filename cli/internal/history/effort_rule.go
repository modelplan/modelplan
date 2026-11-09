// SPDX-License-Identifier: MIT
package history

import (
	"math"
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
)

// The v1.1 effort rule (spec effort-suggestion.md, D101/D102). The suggestion starts
// from the published recommended effort (★) of one model and only adjusts it from
// the user's own quota, at most maxRungs rungs away and always on the same model.
// Projections below are internal gates; they are never shown as numbers.
const (
	maxRungs = 2
	// A rung is affordable when its projected use stays at or below this share.
	upFitPercent = 85.0
	// A lower rung "fits" when its projection stays at or below this share.
	downFitPercent = 85.0
	// Live pace: used% must exceed elapsed% by this many points, and the window
	// must be this far along, before the forecast counts as a shortfall.
	liveOverPoints  = 10.0
	liveMinElapsed  = 10.0
	liveLookHours   = 24
	resetImminentIn = time.Hour
)

// Reason codes: stable, one per outcome, silent outcomes included. The copy never
// shows them; tests, the snapshot and the detail line use them.
const (
	ReasonHeadroomHistory = "headroom-history" // up: three finished cycles with headroom
	ReasonResetUnused     = "reset-unused"     // up: a reset is close and much is left
	ReasonTightHistory    = "tight-history"    // down: limit hit or average high in past cycles
	ReasonLiveRunout      = "live-runout"      // down: the current pace runs out before reset

	ReasonNoData          = "no-data"
	ReasonFewCycles       = "few-cycles"
	ReasonCoverageGap     = "coverage-gap"
	ReasonMixedWorkload   = "mixed-workload"
	ReasonOutsideWindow   = "outside-reset-window"
	ReasonFastUnpublished = "fast-unpublished"
	ReasonNoModel         = "no-model"
	ReasonNoStar          = "no-star"
	ReasonLadderEnd       = "ladder-end"
	ReasonNoCost          = "no-cost"
	ReasonProjectionOver  = "projection-over"
	ReasonMiddleRange     = "middle-range"
	ReasonAlreadyThere    = "already-there"
	ReasonResetBeforeRun  = "reset-before-runout"
	ReasonResetImminent   = "reset-imminent"
	ReasonLiveLasts       = "live-lasts"
	ReasonTooEarly        = "too-early"
)

// Live is the current reading of one weekly window. RunsOutIn is quota.Window's
// LastDayRunout: minutes from now until the recent rate exhausts the window before
// its scheduled reset, nil when the pace lasts or the data cannot say.
type Live struct {
	Used, Elapsed float64
	ResetsAt      time.Time
	RunsOutIn     *int
}

// EffortInput is everything the rule reads. Cycles are finished weekly cycles of one
// subscription pool (a ledger with mixed pools is split by SuggestEffort).
// Announced holds the reset times of officially announced extra resets that are
// still announced (withdrawn or unconfirmed ones must be left out by the caller).
// Surplus is advise's existing "this resets unused" verdict for the pool.
type EffortInput struct {
	Source, Plan string
	Cycles       []Cycle
	Current      *Share
	Live         *Live
	Announced    []time.Time
	Surplus      bool
	Now          time.Time
}

// EffortDecision is the outcome with its reason; Suggestion is nil when silent.
type EffortDecision struct {
	Suggestion *EffortSuggestion
	Reason     string
}

type poolKey struct {
	source, plan, limit string
	minutes             int
}

type histStats struct {
	pool          poolKey
	avg, max      float64
	hits          int
	cfg           effortConfig
	model         *digest.Model
	reset         time.Time // newest finished reset
	publicationOK bool
}

func poolOK(c Cycle, now time.Time) bool {
	// Claude Code's status-line meter does not report a plan label. Keep it
	// unknown and separate from labelled pools; Codex does report its plan.
	return (c.Source == "codex" || c.Source == "claude-code") && !(c.Source == "codex" && c.Plan == "") && c.Kind == "weekly" &&
		(c.WindowMinutes == 0 || c.WindowMinutes == 10080) && !c.ResetsAt.IsZero() && c.Done(now)
}

// readHistory validates the newest suggestionWeeks finished cycles of one pool and
// summarises them. A non-empty reason means history cannot be used.
func readHistory(cs []Cycle, k poolKey, d *digest.Digest, now time.Time) (*histStats, string) {
	if len(cs) < suggestionWeeks {
		return nil, ReasonFewCycles
	}
	sort.Slice(cs, func(i, j int) bool { return cs[i].ResetsAt.After(cs[j].ResetsAt) })
	if !now.Before(cs[0].ResetsAt.Add(suggestionResetWindow)) {
		return nil, ReasonOutsideWindow
	}
	cs = cs[:suggestionWeeks]
	totals := map[effortConfig]float64{}
	occurrences := map[effortConfig]int{}
	sum, maximum, knownTotal, hits := 0.0, 0.0, 0.0, 0
	for i, c := range cs {
		if i > 0 {
			gap := cs[i-1].ResetsAt.Sub(c.ResetsAt)
			if gap < 5*24*time.Hour || gap > 9*24*time.Hour {
				return nil, ReasonCoverageGap
			}
		}
		if !positive(c.LastUsed) || c.LastUsed > 100 || c.FirstUsed < 0 || math.IsNaN(c.FirstUsed) || c.FirstUsed > c.LastUsed ||
			c.FirstAt.IsZero() || c.LastAt.Before(c.FirstAt) || c.LastAt.After(c.ResetsAt) {
			return nil, ReasonCoverageGap
		}
		known, spent := 0.0, 0.0
		seen := map[effortConfig]bool{}
		for _, s := range c.Spent {
			if !positive(s.Points) {
				return nil, ReasonCoverageGap
			}
			spent += s.Points
			m := d.Match(c.Source, s.Model)
			if m == nil || s.Effort == "" {
				continue
			}
			e := m.Effort(s.Effort)
			if e == nil {
				continue
			}
			cfg := effortConfig{m.ID, e.Effort, s.Fast}
			known += s.Points
			totals[cfg] += s.Points
			seen[cfg] = true
		}
		// Includes unrecognized configuration points and use before FirstAt.
		// Allow one point for the recorder's per-share decimal rounding.
		if known < minObservedPoints || known/c.LastUsed < minAttributedShare || spent > c.LastUsed-c.FirstUsed+1 {
			return nil, ReasonCoverageGap
		}
		for cfg := range seen {
			occurrences[cfg]++
		}
		knownTotal += known
		sum += c.LastUsed
		maximum = math.Max(maximum, c.LastUsed)
		if c.HitLimit {
			hits++
		}
	}
	var dominant effortConfig
	best := 0.0
	for cfg, n := range totals {
		if n > best || (n == best && cfg.model+"|"+cfg.effort < dominant.model+"|"+dominant.effort) {
			dominant, best = cfg, n
		}
	}
	if best/knownTotal < minDominantShare || occurrences[dominant] < minDominantWeeks {
		return nil, ReasonMixedWorkload
	}
	m := d.Model(dominant.model)
	if m == nil {
		return nil, ReasonNoModel
	}
	// Fast stays on. Require reviewed subscription billing against plan quota;
	// its same published factor cancels in the same-model effort cost ratio.
	if dominant.fast && !publishedFast(d, m.ID, k.source, k.plan) {
		return nil, ReasonFastUnpublished
	}
	return &histStats{pool: k, avg: sum / suggestionWeeks, max: maximum, hits: hits, cfg: dominant, model: m, reset: cs[0].ResetsAt}, ""
}

func ladderIndex(m *digest.Model, effort string) int {
	e := m.Effort(effort)
	if e == nil {
		return -1
	}
	for i := range m.Efforts {
		if m.Efforts[i].Effort == e.Effort {
			return i
		}
	}
	return -1
}

// costRatio is cost(to)/cost(from) on one published cost basis, or 0 when unknown.
func costRatio(m *digest.Model, from, to int) float64 {
	if from < 0 || to < 0 || from >= len(m.Efforts) || to >= len(m.Efforts) {
		return 0
	}
	a, b := m.Efforts[from], m.Efforts[to]
	if a.Cost == nil || b.Cost == nil || !positive(*a.Cost) || !positive(*b.Cost) || a.CostBasisID == "" || a.CostBasisID != b.CostBasisID {
		return 0
	}
	return *b.Cost / *a.Cost
}

// earliestReset: the scheduled reset, or an announced extra reset that lands first.
func earliestReset(now, scheduled time.Time, announced []time.Time) time.Time {
	out := scheduled
	for _, t := range announced {
		if t.After(now) && (out.IsZero() || t.Before(out)) {
			out = t
		}
	}
	return out
}

func (l *Live) short(now time.Time) bool {
	return l != nil && l.RunsOutIn != nil && l.Elapsed >= liveMinElapsed && l.Used-l.Elapsed >= liveOverPoints && l.ResetsAt.After(now)
}

// liveProjection: projected use at the scheduled reset if the recent rate continues,
// where the rate is what exhausts the remaining share in RunsOutIn minutes.
func (l *Live) projection(now time.Time) float64 {
	rate := (100 - l.Used) / float64(*l.RunsOutIn)
	return l.Used + rate*l.ResetsAt.Sub(now).Minutes()
}

// DecideEffort applies the rule. It is pure and always returns a reason.
func DecideEffort(in EffortInput, d *digest.Digest) EffortDecision {
	if d == nil || d.PublicationID == "" {
		return EffortDecision{Reason: ReasonNoData}
	}
	var h *histStats
	hreason := ReasonNoData
	if len(in.Cycles) > 0 {
		pool := in.Cycles[0]
		ok := true
		for _, c := range in.Cycles {
			if c.Source != pool.Source || c.Plan != pool.Plan || c.Limit != pool.Limit || c.WindowMinutes != pool.WindowMinutes || !poolOK(c, in.Now) {
				ok = false
			}
		}
		if ok {
			h, hreason = readHistory(append([]Cycle(nil), in.Cycles...), poolKey{pool.Source, pool.Plan, pool.Limit, pool.WindowMinutes}, d, in.Now)
		} else {
			hreason = ReasonCoverageGap
		}
	}
	var m *digest.Model
	curIdx := -1
	if in.Current != nil && in.Current.Model != "" {
		m = d.Match(in.Source, in.Current.Model)
		if m != nil && in.Current.Effort != "" {
			curIdx = ladderIndex(m, in.Current.Effort)
		}
	}
	if h != nil {
		// History of another model or another speed setting is not about this default.
		if m != nil && (m.ID != h.model.ID || in.Current.Fast != h.cfg.fast) {
			h, hreason = nil, ReasonMixedWorkload
		} else if m == nil {
			m = h.model
		}
	}
	if m == nil {
		return EffortDecision{Reason: orReason(hreason, ReasonNoModel)}
	}
	star := ladderIndex(m, m.Recommended)
	if star < 0 {
		return EffortDecision{Reason: ReasonNoStar}
	}
	// The effort that produced the usage the projection scales from.
	basis := curIdx
	if h != nil {
		basis = ladderIndex(m, h.cfg.effort)
	}
	if in.Current != nil && curIdx >= 0 && in.Live != nil {
		basis = curIdx
	}
	liveShort := in.Live.short(in.Now)
	histTight := h != nil && (h.avg >= tightAverage || h.hits >= tightLimitCycles)
	histUp := h != nil && h.avg <= underusedAverage && h.max <= underusedMaximum && h.hits == 0

	if liveShort || histTight {
		return decideDown(in, d, m, h, star, curIdx, basis, liveShort)
	}
	if !histUp && !in.Surplus {
		switch {
		case h != nil:
			return EffortDecision{Reason: ReasonMiddleRange}
		case in.Live != nil && in.Live.RunsOutIn != nil && in.Live.Elapsed < liveMinElapsed:
			return EffortDecision{Reason: ReasonTooEarly}
		case in.Live != nil:
			return EffortDecision{Reason: ReasonLiveLasts}
		}
		return EffortDecision{Reason: orReason(hreason, ReasonNoData)}
	}
	// Up: at most one rung above ★, the same model.
	to := star + 1
	if to >= len(m.Efforts) {
		return EffortDecision{Reason: ReasonLadderEnd}
	}
	reason := ReasonHeadroomHistory
	if histUp {
		r := costRatio(m, basis, to)
		if r == 0 {
			if !in.Surplus {
				return EffortDecision{Reason: ReasonNoCost}
			}
			reason = ReasonResetUnused
		} else if h.avg*r > upFitPercent {
			if !in.Surplus {
				return EffortDecision{Reason: ReasonProjectionOver}
			}
			reason = ReasonResetUnused
		}
	} else {
		reason = ReasonResetUnused
	}
	if curIdx >= to {
		return EffortDecision{Reason: ReasonAlreadyThere}
	}
	return finish(in, d, m, h, star, to, "up", reason)
}

func orReason(a, b string) string {
	if a == "" {
		return b
	}
	return a
}

func decideDown(in EffortInput, d *digest.Digest, m *digest.Model, h *histStats, star, curIdx, basis int, liveShort bool) EffortDecision {
	// Reset gate: the earliest of the scheduled and any still-announced reset.
	var scheduled time.Time
	if in.Live != nil {
		scheduled = in.Live.ResetsAt
	}
	reset := earliestReset(in.Now, scheduled, in.Announced)
	if !reset.IsZero() && reset.Sub(in.Now) <= resetImminentIn {
		return EffortDecision{Reason: ReasonResetImminent}
	}
	if liveShort && !reset.IsZero() && !reset.After(in.Now.Add(time.Duration(*in.Live.RunsOutIn)*time.Minute)) {
		return EffortDecision{Reason: ReasonResetBeforeRun}
	}
	if star == 0 {
		return EffortDecision{Reason: ReasonLadderEnd}
	}
	maxDrop := maxRungs
	if maxDrop > star {
		maxDrop = star
	}
	// Smallest drop whose projection fits; with none, the largest allowed drop.
	drop := maxDrop
	known := basis >= 0
	for k := 1; k <= maxDrop && known; k++ {
		r := costRatio(m, basis, star-k)
		if r == 0 {
			known = false
			break
		}
		var proj float64
		if liveShort {
			proj = in.Live.Used + (in.Live.projection(in.Now)-in.Live.Used)*r
			if proj <= 100 {
				drop = k
				break
			}
		} else {
			proj = h.avg * r
			if proj <= downFitPercent {
				drop = k
				break
			}
		}
	}
	if !known {
		drop = 1
	}
	to := star - drop
	if curIdx >= 0 && curIdx <= to {
		return EffortDecision{Reason: ReasonAlreadyThere}
	}
	reason := ReasonTightHistory
	if liveShort {
		reason = ReasonLiveRunout
	}
	return finish(in, d, m, h, star, to, "down", reason)
}

func finish(in EffortInput, d *digest.Digest, m *digest.Model, h *histStats, star, to int, direction, reason string) EffortDecision {
	from, target := m.Efforts[star], m.Efforts[to]
	s := &EffortSuggestion{Source: in.Source, Plan: in.Plan, ModelID: m.ID, ModelName: m.Name, Direction: direction, Reason: reason,
		FromEffort: from.Effort, FromLabel: from.Label, ToEffort: target.Effort, ToLabel: target.Label, Recommended: m.Recommended,
		CostRatio: costRatio(m, star, to), CostBasisID: from.CostBasisID, PublicationID: d.PublicationID}
	if in.Current != nil {
		s.Fast = in.Current.Fast
	}
	if h != nil {
		s.Source, s.Plan, s.Fast = h.pool.source, h.pool.plan, h.cfg.fast
	}
	switch reason {
	case ReasonHeadroomHistory, ReasonTightHistory:
		s.Basis, s.Cycles, s.AverageUsed, s.HitLimitCycles = "history", suggestionWeeks, h.avg, h.hits
		s.ResetAt, s.ExpiresAt = h.reset, h.reset.Add(suggestionResetWindow)
	case ReasonLiveRunout:
		s.Basis, s.BasisHours = "live", liveLookHours
		s.ResetAt, s.ExpiresAt = in.Now, earliestReset(in.Now, in.Live.ResetsAt, in.Announced)
	default: // reset-unused
		s.Basis = "reset"
		s.ResetAt, s.ExpiresAt = in.Now, in.Now.Add(suggestionResetWindow)
		if in.Live != nil && in.Live.ResetsAt.After(in.Now) {
			s.ExpiresAt = earliestReset(in.Now, in.Live.ResetsAt, in.Announced)
		}
	}
	if h != nil && s.Basis != "history" {
		s.Cycles = suggestionWeeks
	}
	return EffortDecision{Suggestion: s, Reason: reason}
}

// SuggestEffort reads a ledger (several pools possible) with a verified publication:
// the history-only rule behind "modelplan history". It abstains before three finished
// weekly cycles and outside the first day after a reset.
func SuggestEffort(l Ledger, d *digest.Digest, now time.Time) *EffortSuggestion {
	if d == nil || d.PublicationID == "" {
		return nil
	}
	groups := map[poolKey][]Cycle{}
	for _, c := range l.Cycles {
		if poolOK(c, now) {
			k := poolKey{c.Source, c.Plan, c.Limit, c.WindowMinutes}
			groups[k] = append(groups[k], c)
		}
	}
	var candidates []*EffortSuggestion
	for k, cs := range groups {
		if v := DecideEffort(EffortInput{Source: k.source, Plan: k.plan, Cycles: cs, Now: now}, d).Suggestion; v != nil {
			candidates = append(candidates, v)
		}
	}
	// One line: newest reset, then stable source/plan/model ordering (never map order).
	sort.Slice(candidates, func(i, j int) bool {
		a, b := candidates[i], candidates[j]
		if !a.ResetAt.Equal(b.ResetAt) {
			return a.ResetAt.After(b.ResetAt)
		}
		return a.Source+"|"+a.Plan+"|"+a.ModelID < b.Source+"|"+b.Plan+"|"+b.ModelID
	})
	if len(candidates) == 0 {
		return nil
	}
	return candidates[0]
}
