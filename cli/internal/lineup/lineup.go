// Package lineup holds the published DTO. The test-only reference is the Go twin of clients/design-kit/lineup.js (lineup-v1, issue #177).
// It exists only until the publication carries server-side lineups; both implementations
// are pinned to testdata/lineup-v1.json.
package lineup

import "encoding/json"

// Tie is the fixed product comparison tolerance in points, not a confidence interval.
const Tie = 1.0

type Member struct {
	ID      string
	Ability *float64
	Cost    *float64
}

type Dominance struct {
	ID   string `json:"id"`
	Kind string `json:"kind"` // "equivalent" | "weaker"
}

type Row struct {
	ID           string     `json:"id"`
	Status       string     `json:"status,omitempty"` // "incomplete" when ability or cost is unknown
	Ability      float64    `json:"ability"`
	Cost         float64    `json:"cost"`
	CostRelative float64    `json:"costRelative"`
	Tags         []string   `json:"tags"`
	DominatedBy  *Dominance `json:"dominatedBy"`
}

type Step struct {
	From         string  `json:"from"`
	To           string  `json:"to"`
	AbilityDelta float64 `json:"abilityDelta"`
	CostRatio    float64 `json:"costRatio"`
}

func (r Row) MarshalJSON() ([]byte, error) {
	if r.Status == "incomplete" {
		return json.Marshal(struct {
			ID          string     `json:"id"`
			Status      string     `json:"status"`
			Tags        []string   `json:"tags"`
			DominatedBy *Dominance `json:"dominatedBy"`
		}{r.ID, r.Status, r.Tags, r.DominatedBy})
	}
	type alias Row
	return json.Marshal(alias(r))
}

type Lineup struct {
	Method   string   `json:"method"`
	Tie      float64  `json:"tie"`
	Baseline string   `json:"baseline"`
	Frontier []string `json:"frontier"`
	Steps    []Step   `json:"steps"`
	Members  []*Row   `json:"members"`
}

func (l *Lineup) Row(id string) *Row {
	for _, r := range l.Members {
		if r.ID == id {
			return r
		}
	}
	return nil
}

func (r *Row) Has(tag string) bool {
	for _, t := range r.Tags {
		if t == tag {
			return true
		}
	}
	return false
}
