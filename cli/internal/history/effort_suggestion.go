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

// On by default since v1.1 (D102): passive, local, one notice per rolling week,
// and it needs a verified publication. "modelplan history --effort-suggestion off"
// (or MODELPLAN_EFFORT_SUGGESTION=off) is the off switch behind the Settings toggle.
const effortSuggestionDefaultEnabled = true

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
	// Reason is the stable code of the rule that fired (Reason* constants); Basis is
	// "history", "live" or "reset". BasisHours is the look-back of a live basis.
	// Neither is shown as a number promise; they feed the optional detail line.
	Reason     string `json:"reason,omitempty"`
	Basis      string `json:"basis,omitempty"`
	BasisHours int    `json:"basisHours,omitempty"`
	// Message is localized by the caller, never used in the decision.
	Message string `json:"message,omitempty"`
}

type effortConfig struct {
	model, effort string
	fast          bool
}

func positive(v float64) bool { return v > 0 && !math.IsNaN(v) && !math.IsInf(v, 0) }

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
	if effortSuggestionOff() || v == nil || v.ResetAt.IsZero() || !now.Before(v.ExpiresAt) {
		return nil
	}
	// History advice is for the first day after a reset; a live or reset-close hint
	// is valid until the reset it was gated on.
	if v.Basis == "history" && (now.Before(v.ResetAt) || !now.Before(v.ResetAt.Add(suggestionResetWindow))) {
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

// EffortSuggestionEnabled is the Settings toggle's read side: whether the hint is on
// for this cache (default on; "off" in Settings, the CLI or the environment turns it
// off). Settings writes with SetEffortSuggestion(cache, "on"|"off", now).
func EffortSuggestionEnabled(cache string) bool {
	if effortSuggestionOff() {
		return false
	}
	s, err := loadEffortState(cache)
	return err == nil && s.enabled()
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
