// SPDX-License-Identifier: MIT
package history

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"math"
	"os"
	"path/filepath"
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
)

// Conservative, tunable thresholds: three recent weeks, mostly observed and on one
// configuration. Five observed points rejects meter jitter; 60% dominance avoids
// treating a mixed workload as a default. At most 60% average / 75% maximum
// leaves repeated headroom; 90% average or two limit hits means repeated pressure.
// The middle range deliberately abstains.
const (
	suggestionWeeks       = 3
	suggestionWeek        = 7 * 24 * time.Hour
	suggestionResetWindow = 24 * time.Hour
	minObservedPoints     = 5.0
	minAttributedShare    = .60
	minDominantShare      = .60
	minDominantWeeks      = 2
	tightLimitCycles      = 2
	underusedAverage      = 60.0
	underusedMaximum      = 75.0
	tightAverage          = 90.0
)

// Owner-controlled rollout: no automatic activation on the earliest go-live
// date (2026-11-07). Local on/env opt-in is available for review.
const effortSuggestionDefaultEnabled = false

// EffortSuggestion is personal, local advice, never agent context. CostRatio is a
// published reference-cost ratio, not a prediction of the user's quota consumption.
type EffortSuggestion struct {
	Source         string    `json:"source"`
	Plan           string    `json:"plan"`
	ModelID        string    `json:"modelId"`
	ModelName      string    `json:"modelName"`
	Direction      string    `json:"direction"`
	FromEffort     string    `json:"fromEffort"`
	FromLabel      string    `json:"fromLabel"`
	ToEffort       string    `json:"toEffort"`
	ToLabel        string    `json:"toLabel"`
	Recommended    string    `json:"recommended"`
	Fast           bool      `json:"fast"`
	Cycles         int       `json:"cycles"`
	AverageUsed    float64   `json:"averageUsed"`
	HitLimitCycles int       `json:"hitLimitCycles"`
	CostRatio      float64   `json:"costRatio"`
	CostBasisID    string    `json:"costBasisId"`
	PublicationID  string    `json:"publicationId"`
	ResetAt        time.Time `json:"resetAt"`
	ExpiresAt      time.Time `json:"expiresAt"`
	// Message is localized by the caller, never used in the decision.
	Message string `json:"message,omitempty"`
}

type effortConfig struct {
	model, effort string
	fast          bool
}

func positive(v float64) bool { return v > 0 && !math.IsNaN(v) && !math.IsInf(v, 0) }

// SuggestEffort is pure: callers supply a ledger and a verified publication. No
// historical default, alias, endpoint, cost or speed multiplier is guessed.
func SuggestEffort(l Ledger, d *digest.Digest, now time.Time) *EffortSuggestion {
	return suggestEffort(l, d, now, nil)
}

// SuggestDefaultEffort takes finished weekly cycles of one subscription/pool and
// an explicit current default. Past attribution establishes a comparable model
// and speed setting; the adjacent step starts at the current effort, even when
// the user has since changed it. Unknown defaults and mixed subscriptions abstain.
// Share.Points is unused. The caller owns reading local inputs and publication.
func SuggestDefaultEffort(cycles []Cycle, current Share, d *digest.Digest, now time.Time) *EffortSuggestion {
	if len(cycles) == 0 || current.Model == "" || current.Effort == "" {
		return nil
	}
	pool := cycles[0]
	for _, c := range cycles {
		if c.Source != pool.Source || c.Plan != pool.Plan || c.Limit != pool.Limit || c.WindowMinutes != pool.WindowMinutes ||
			c.Kind != "weekly" || !c.Done(now) {
			return nil
		}
	}
	return suggestEffort(Ledger{Cycles: cycles}, d, now, &current)
}

func suggestEffort(l Ledger, d *digest.Digest, now time.Time, current *Share) *EffortSuggestion {
	if d == nil || d.PublicationID == "" {
		return nil
	}
	type pool struct {
		source, plan, limit string
		minutes             int
	}
	groups := map[pool][]Cycle{}
	for _, c := range l.Cycles {
		// Claude Code's status-line meter does not report a plan label. Keep it
		// unknown and separate from labelled pools; Codex does report its plan.
		if (c.Source != "codex" && c.Source != "claude-code") || (c.Source == "codex" && c.Plan == "") || c.Kind != "weekly" ||
			(c.WindowMinutes != 0 && c.WindowMinutes != 10080) || c.ResetsAt.IsZero() || !c.Done(now) {
			continue
		}
		k := pool{c.Source, c.Plan, c.Limit, c.WindowMinutes}
		groups[k] = append(groups[k], c)
	}
	var candidates []*EffortSuggestion
	for k, cs := range groups {
		sort.Slice(cs, func(i, j int) bool { return cs[i].ResetsAt.After(cs[j].ResetsAt) })
		if len(cs) < suggestionWeeks || !now.Before(cs[0].ResetsAt.Add(suggestionResetWindow)) {
			continue
		}
		cs = cs[:suggestionWeeks]
		totals := map[effortConfig]float64{}
		occurrences := map[effortConfig]int{}
		sum, maximum, knownTotal, hits, valid := 0.0, 0.0, 0.0, 0, true
		for i, c := range cs {
			if i > 0 {
				gap := cs[i-1].ResetsAt.Sub(c.ResetsAt)
				if gap < 5*24*time.Hour || gap > 9*24*time.Hour {
					valid = false
					break
				}
			}
			if !positive(c.LastUsed) || c.LastUsed > 100 || c.FirstUsed < 0 || math.IsNaN(c.FirstUsed) || c.FirstUsed > c.LastUsed ||
				c.FirstAt.IsZero() || c.LastAt.Before(c.FirstAt) || c.LastAt.After(c.ResetsAt) {
				valid = false
				break
			}
			known, spent := 0.0, 0.0
			seen := map[effortConfig]bool{}
			for _, s := range c.Spent {
				if !positive(s.Points) {
					valid = false
					break
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
			if !valid || known < minObservedPoints || known/c.LastUsed < minAttributedShare || spent > c.LastUsed-c.FirstUsed+1 {
				valid = false
				break
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
		if !valid {
			continue
		}
		avg := sum / suggestionWeeks
		step, direction := 0, ""
		if avg <= underusedAverage && maximum <= underusedMaximum && hits == 0 {
			step, direction = 1, "up"
		}
		if avg >= tightAverage || hits >= tightLimitCycles {
			step, direction = -1, "down"
		}
		if step == 0 {
			continue
		}
		var dominant effortConfig
		best := 0.0
		for cfg, n := range totals {
			if n > best {
				dominant, best = cfg, n
			}
		}
		if best/knownTotal < minDominantShare || occurrences[dominant] < minDominantWeeks {
			continue
		}
		m := d.Model(dominant.model)
		if current != nil {
			cm := d.Match(k.source, current.Model)
			if cm == nil || cm.ID != m.ID || current.Fast != dominant.fast || m.Effort(current.Effort) == nil {
				continue
			}
			dominant.effort = m.Effort(current.Effort).Effort
		}
		fromIndex := -1
		for i := range m.Efforts {
			if m.Efforts[i].Effort == dominant.effort {
				fromIndex = i
			}
		}
		toIndex := fromIndex + step
		if fromIndex < 0 || toIndex < 0 || toIndex >= len(m.Efforts) || m.Rec() == nil {
			continue
		}
		from, to := m.Efforts[fromIndex], m.Efforts[toIndex]
		if from.Cost == nil || to.Cost == nil || !positive(*from.Cost) || !positive(*to.Cost) || from.CostBasisID == "" || from.CostBasisID != to.CostBasisID {
			continue
		}
		ratio := *to.Cost / *from.Cost
		if !positive(ratio) || (step > 0 && ratio <= 1) || (step < 0 && ratio >= 1) {
			continue
		}
		// Fast stays on. Require reviewed subscription billing against plan quota;
		// its same published factor cancels in the adjacent-effort reference ratio.
		if dominant.fast && !publishedFast(d, m.ID, k.source, k.plan) {
			continue
		}
		candidates = append(candidates, &EffortSuggestion{Source: k.source, Plan: k.plan, ModelID: m.ID, ModelName: m.Name, Direction: direction,
			FromEffort: from.Effort, FromLabel: from.Label, ToEffort: to.Effort, ToLabel: to.Label, Recommended: m.Recommended, Fast: dominant.fast,
			Cycles: suggestionWeeks, AverageUsed: avg, HitLimitCycles: hits, CostRatio: ratio, CostBasisID: from.CostBasisID, PublicationID: d.PublicationID,
			ResetAt: cs[0].ResetsAt, ExpiresAt: cs[0].ResetsAt.Add(suggestionResetWindow)})
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

func publishedFast(d *digest.Digest, model, source, plan string) bool {
	for _, t := range d.SpeedTiers(model, source) {
		if t.Tier != "fast" {
			continue
		}
		eligible := len(t.Eligibility.Plans) == 0
		for _, p := range t.Eligibility.Plans {
			if p == plan {
				eligible = true
			}
		}
		r := t.Rate("subscription")
		if eligible && r != nil && r.BillsTo == "plan-quota" && positive(r.Ratio) {
			return true
		}
	}
	return false
}

type effortSuggestionState struct {
	SchemaVersion  int       `json:"schemaVersion"`
	Disabled       bool      `json:"disabled"`
	Enabled        bool      `json:"enabled,omitempty"`
	DismissedUntil time.Time `json:"dismissedUntil"`
	LastShownAt    time.Time `json:"lastShownAt"`
}

func EffortSuggestionPath(cache string) string {
	return filepath.Join(cache, "observed", "effort-suggestion.json")
}
func effortSuggestionOff() bool { return Off() || os.Getenv("MODELPLAN_EFFORT_SUGGESTION") == "off" }
func (s effortSuggestionState) enabled() bool {
	return !s.Disabled && (effortSuggestionDefaultEnabled || s.Enabled || os.Getenv("MODELPLAN_EFFORT_SUGGESTION") == "on")
}
func loadEffortState(cache string) (effortSuggestionState, error) {
	s := effortSuggestionState{SchemaVersion: 1}
	b, err := os.ReadFile(EffortSuggestionPath(cache))
	if errors.Is(err, os.ErrNotExist) {
		return s, nil
	}
	if err != nil {
		return s, err
	}
	if len(b) > 4096 {
		return s, errors.New("effort suggestion state too large")
	}
	if err = json.Unmarshal(b, &s); err != nil {
		return s, err
	}
	if s.SchemaVersion != 1 {
		return s, errors.New("unknown effort suggestion state version")
	}
	return s, nil
}
func saveEffortState(cache string, s effortSuggestionState) error {
	b, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	return write(EffortSuggestionPath(cache), b)
}

// EffortView is read-only. Revision hashes observed inputs, never the clock;
// Boundaries reports clock-only eligibility changes.
type EffortView struct {
	Suggestion *EffortSuggestion
	Revision   string
	Boundaries []time.Time
}

func ReadEffortSuggestion(cache string, d *digest.Digest, now time.Time) EffortView {
	if effortSuggestionOff() || d == nil {
		return EffortView{}
	}
	l := Load(cache)
	if len(l.Cycles) == 0 {
		return EffortView{}
	}
	s, err := loadEffortState(cache)
	if err != nil {
		return EffortView{}
	}
	b, _ := json.Marshal(struct {
		Ledger         Ledger
		Disabled       bool
		Enabled        bool
		DismissedUntil time.Time
	}{l, s.Disabled, s.enabled(), s.DismissedUntil})
	h := sha256.Sum256(b)
	v := EffortView{Revision: hex.EncodeToString(h[:])}
	for _, c := range l.Cycles {
		v.Boundaries = append(v.Boundaries, c.ResetsAt, c.ResetsAt.Add(suggestionResetWindow))
	}
	v.Boundaries = append(v.Boundaries, s.DismissedUntil)
	if s.enabled() && !now.Before(s.DismissedUntil) {
		v.Suggestion = SuggestEffort(l, d, now)
	}
	return v
}

// NotifyEffortSuggestion claims one user-facing notice per rolling week shared
// by text history and status-line hints. Never call from plugin/agent outputs.
func NotifyEffortSuggestion(cache string, d *digest.Digest, now time.Time) *EffortSuggestion {
	if effortSuggestionOff() {
		return nil
	}
	return ClaimEffortSuggestion(cache, ReadEffortSuggestion(cache, d, now).Suggestion, now)
}

// ClaimEffortSuggestion atomically reserves the shared weekly user notice for a
// precomputed suggestion, including one based on an explicit current default.
// Call only when the caller will render it; previews and discarded output do not claim.
func ClaimEffortSuggestion(cache string, v *EffortSuggestion, now time.Time) *EffortSuggestion {
	if effortSuggestionOff() || v == nil || v.ResetAt.IsZero() || now.Before(v.ResetAt) || !now.Before(v.ResetAt.Add(suggestionResetWindow)) || !now.Before(v.ExpiresAt) {
		return nil
	}
	unlock, ok := lockNamed(cache, "effort-suggestion.lock")
	if !ok {
		return nil
	}
	defer unlock()
	s, err := loadEffortState(cache)
	if err != nil || !s.enabled() || now.Before(s.DismissedUntil) || (!s.LastShownAt.IsZero() && now.Before(s.LastShownAt.Add(suggestionWeek))) {
		return nil
	}
	s.LastShownAt = now.UTC()
	if saveEffortState(cache, s) != nil {
		return nil
	}
	return v
}

// SetEffortSuggestion changes only this feature's local state, never a harness
// setting. Dismiss lasts one week; off lasts until on or removal of the state file.
func SetEffortSuggestion(cache, action string, now time.Time) error {
	if action != "dismiss" && action != "off" && action != "on" {
		return errors.New("effort suggestion: expected dismiss, off or on")
	}
	unlock, ok := lockNamed(cache, "effort-suggestion.lock")
	if !ok {
		return errors.New("effort suggestion state locked")
	}
	defer unlock()
	s, err := loadEffortState(cache)
	if err != nil {
		return err
	}
	switch action {
	case "dismiss":
		s.DismissedUntil = now.Add(suggestionWeek).UTC()
	case "off":
		s.Disabled = true
	case "on":
		s.Disabled = false
		s.Enabled = true
		s.DismissedUntil = time.Time{}
	}
	return saveEffortState(cache, s)
}
