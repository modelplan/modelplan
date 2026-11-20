// Package digest is the only place that maps publication fields to client concepts.
// Everything else (lineup, render, statusline) reads Digest, so switching from the
// interim `models` component to the `client` component (#178) touches this file only.
package digest

import (
	"encoding/json"
	"errors"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/lineup"
	"math"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	ComponentClient = "client"
	ComponentModels = "models"
)

type TimeBasis struct {
	Source           string  `json:"source"`
	Cohort           string  `json:"cohort"`
	Boundary         string  `json:"boundary"`
	ReferenceSeconds float64 `json:"referenceSeconds"`
}
type Effort struct {
	Effort        string     `json:"effort"` // native key, e.g. "medium"
	Label         string     `json:"label"`  // display, e.g. "Med"
	Ability       *float64   `json:"ability"`
	Cost          *float64   `json:"cost"` // cross-model; units.cost says which basis
	Time          *float64   `json:"time"`
	TimeEstimated bool       `json:"timeEstimated"`
	TimeBasis     *TimeBasis `json:"timeBasis"`
	CostBasisID   string     `json:"costBasisId"`
	// Provisional: the ability rests on evidence outside the range its cross-source link was
	// fitted on. Published only when true; show it within the model's own ladder, never compare
	// it across models.
	Provisional bool `json:"provisional,omitempty"`
	// AAScore (client-v1.5, D292): the raw Artificial Analysis Intelligence Index score for this effort. A reference
	// shown beside our own ability score, never in its place. Parse drops it below client-v1.5 or when not positive.
	AAScore *float64 `json:"aaScore,omitempty"`
}

type HarnessEvidence struct {
	RequiredEndpoints map[string]string `json:"requiredEndpoints"`
}
type Model struct {
	ID              string              `json:"id"`
	Name            string              `json:"name"`
	DeveloperID     string              `json:"developerId"`
	Recommended     string              `json:"recommended"` // native effort key
	Default         bool                `json:"default,omitempty"`
	HarnessIDs      map[string][]string `json:"harnessIds,omitempty"`
	HarnessEvidence *HarnessEvidence    `json:"harnessEvidence"`
	Efforts         []Effort            `json:"efforts"`
}

type Units struct {
	Ability string `json:"ability"`
	Cost    string `json:"cost"`
	Time    string `json:"time"`
}

type PublishedLineup struct {
	DeveloperID string `json:"developerId"`
	CostBasisID string `json:"costBasisId"`
	lineup.Lineup
}

func (d *Digest) PublishedLineup(dev string) *PublishedLineup {
	for i := range d.Lineups {
		if d.Lineups[i].DeveloperID == dev {
			return &d.Lineups[i]
		}
	}
	return nil
}
func (d *Digest) Lineup(dev string) *lineup.Lineup {
	for i := range d.Lineups {
		if d.Lineups[i].DeveloperID == dev {
			return &d.Lineups[i].Lineup
		}
	}
	return nil
}

type MultiplierWindow struct {
	RuleID                 string            `json:"ruleId"`
	Provider               string            `json:"provider"`
	Kind                   string            `json:"kind"`
	Models                 []string          `json:"models"`
	Clients                []string          `json:"clients"`
	PlanIDs                []string          `json:"planIds"`
	Generations            []string          `json:"generations"`
	Region                 string            `json:"region"`
	Timezone               string            `json:"timezone"`
	Multiplier             *float64          `json:"multiplier"`
	StartsAt               string            `json:"startsAt"`
	EndsAt                 string            `json:"endsAt"`
	Priority               int               `json:"priority"`
	Status                 string            `json:"status"`
	MinClientVersions      map[string]string `json:"minClientVersions"`
	RequiresQuotaAvailable bool              `json:"requiresQuotaAvailable"`
	Conditions             []string          `json:"conditions"`
	URL                    string            `json:"url"`
}
type MultiplierHorizon struct {
	From      string `json:"from"`
	To        string `json:"to"`
	Selection string `json:"selection"`
}
type Digest struct {
	// Optional same-publication calendar supplement, not part of the client
	// multiplier pack and never used for billing or recommendation calculations.
	CalendarIntervals []MultiplierWindow `json:"-"`
	CalendarFrom      time.Time          `json:"-"`
	CalendarTo        time.Time          `json:"-"`
	Catalogue         *detect.Catalogue  `json:"-"`
	publication       publicationFields
	CLIUpdate         json.RawMessage    `json:"cli,omitempty"` // optional verified update pin; decoded only by explicit update
	PublicationID     string             `json:"publicationId"`
	ProjectionVersion string             `json:"projectionVersion,omitempty"`
	Multipliers       []MultiplierWindow `json:"multipliers"`
	MultiplierHorizon *MultiplierHorizon `json:"multiplierHorizon,omitempty"`
	PublishedAt       string             `json:"publishedAt,omitempty"`
	Release           string             `json:"release,omitempty"`
	Source            string             `json:"source"` // component the digest came from
	Units             Units              `json:"units"`
	Models            []Model            `json:"models"`
	Lineups           []PublishedLineup  `json:"lineups"`
	Speed             []SpeedTier        `json:"speedTiers,omitempty"`
	PlanMetering      *PlanMetering      `json:"planMetering,omitempty"`   // client-v1.3
	PlanModels        *PlanModels        `json:"planModels,omitempty"`     // client-v1.4
	AAIndexVersion    string             `json:"aaIndexVersion,omitempty"` // client-v1.5: the AA index version behind aaScore
	Resets            []json.RawMessage  `json:"resets"`
	Windows           []json.RawMessage  `json:"windows"`
}

// Rec returns the ★ recommended configuration, or nil.
func (m *Model) Rec() *Effort { return m.Effort(m.Recommended) }

func (m *Model) Effort(key string) *Effort {
	for i := range m.Efforts {
		if strings.EqualFold(m.Efforts[i].Effort, key) || strings.EqualFold(m.Efforts[i].Label, key) {
			return &m.Efforts[i]
		}
	}
	return nil
}

func (d *Digest) Model(id string) *Model {
	for i := range d.Models {
		if d.Models[i].ID == id {
			return &d.Models[i]
		}
	}
	return nil
}

// Developer returns the developer's models in publication order.
func (d *Digest) Developer(dev string) []*Model {
	var out []*Model
	for i := range d.Models {
		if strings.EqualFold(d.Models[i].DeveloperID, dev) {
			out = append(out, &d.Models[i])
		}
	}
	return out
}

func (d *Digest) Developers() []string {
	seen := map[string]bool{}
	var out []string
	for _, m := range d.Models {
		if !seen[m.DeveloperID] {
			seen[m.DeveloperID] = true
			out = append(out, m.DeveloperID)
		}
	}
	sort.Strings(out)
	return out
}

// Match accepts only a literal reviewed identifier for the named harness.
func (d *Digest) Match(harness string, ids ...string) *Model {
	for i := range d.Models {
		if e := d.Models[i].HarnessEvidence; e != nil && e.RequiredEndpoints[harness] != "" {
			continue
		} // No endpoint context: abstain on conditional custom-provider aliases.
		for _, h := range d.Models[i].HarnessIDs[harness] {
			for _, id := range ids {
				if h == id && id != "" {
					return &d.Models[i]
				}
			}
		}
	}
	return nil
}

var DeveloperNames = map[string]string{
	"anthropic": "Anthropic", "openai": "OpenAI", "google": "Google", "xai": "xAI", "meta": "Meta",
	"zhipuai": "智谱 GLM", "kimi": "Kimi", "alibaba": "阿里 Qwen", "deepseek": "DeepSeek",
	"xiaomi": "小米 MiMo", "minimax": "MiniMax", "tencent": "腾讯混元",
}

// validTie accepts the lineup tie on each published index display scale: 1 point on scale 0.3
// and the same gap re-expressed on scale 0.4 (0.815 = 8.150 / 10). Verdicts are unchanged.
func validTie(t float64) bool { return t == 1 || t == 0.815 }

func Parse(component string, b []byte) (*Digest, error) {
	if component != ComponentClient {
		return nil, fmt.Errorf("unsupported component %q; client digest required", component)
	}
	var raw struct {
		SchemaVersion int             `json:"schemaVersion"`
		Kind          string          `json:"kind"`
		Data          json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(b, &raw); err != nil {
		return nil, err
	}
	if raw.SchemaVersion != 1 || raw.Kind != ComponentClient || raw.Data == nil {
		return nil, errors.New("client: unsupported schema")
	}
	var d Digest
	var catalogueErr error
	d.Catalogue, catalogueErr = detect.ParseData(raw.Data)
	if catalogueErr != nil {
		return nil, fmt.Errorf("client: %w", catalogueErr)
	}
	// Optional fields that are dropped when invalid are screened first, so a value of the wrong JSON type (a string
	// aaScore, a number out of float64 range, a non-object planMetering) is dropped rather than failing the decode.
	data := sanitizeOptional(raw.Data)
	if err := json.Unmarshal(data, &d); err != nil {
		return nil, err
	}
	if d.Units.Ability != "websiteAbility" || d.Units.Cost != "usdPerReferenceTask" || d.Units.Time != "taskTimeCrossModel" || d.Models == nil || d.Lineups == nil || d.Resets == nil || d.Windows == nil {
		return nil, errors.New("client: unsupported units or missing arrays")
	}
	seen := map[string]*Model{}
	for i := range d.Models {
		m := &d.Models[i]
		if m.ID == "" || m.DeveloperID == "" || seen[m.ID] != nil || m.HarnessIDs == nil {
			return nil, errors.New("client: invalid identity")
		}
		seen[m.ID] = m
		efforts := map[string]bool{}
		for _, e := range m.Efforts {
			if e.Effort == "" || efforts[e.Effort] {
				return nil, errors.New("client: invalid efforts")
			}
			efforts[e.Effort] = true
		}
		if m.Recommended != "" && !efforts[m.Recommended] {
			return nil, errors.New("client: invalid recommended effort")
		}
	}
	for _, l := range d.Lineups {
		if l.Method != "lineup-v1" || !validTie(l.Tie) || l.CostBasisID == "" || l.Baseline == "" || seen[l.Baseline] == nil {
			return nil, errors.New("client: invalid lineup")
		}
		for _, r := range l.Members {
			if seen[r.ID] == nil || seen[r.ID].DeveloperID != l.DeveloperID {
				return nil, errors.New("client: invalid lineup member")
			}
		}
	}
	if d.ProjectionVersion != "" {
		// client-v1.x only adds fields (v1.2: speedTiers); unknown additions are ignored.
		if !strings.HasPrefix(d.ProjectionVersion, "client-v1.") || d.Multipliers == nil || d.MultiplierHorizon == nil || d.MultiplierHorizon.Selection != "highest-priority-no-stacking" {
			return nil, errors.New("client: incomplete multiplier contract")
		}
	}
	dropInvalidAAScores(&d)
	if d.PlanMetering != nil && !validMetering(d.PlanMetering) {
		d.PlanMetering = nil
	}
	if d.PlanModels != nil && !validPlanModels(d.PlanModels) {
		d.PlanModels = nil
	}
	if err := json.Unmarshal(data, &d.publication); err != nil {
		return nil, err
	}
	d.Source = ComponentClient
	return &d, nil
}

// sanitizeOptional removes every optional client field whose value does not decode into its Go type: an effort's
// aaScore, aaIndexVersion, planMetering and planModels. These are references or add-ons that Parse drops when invalid;
// a bad one must never reject the publication. Required fields are untouched, so they still fail the strict decode.
// The original bytes are returned when nothing was removed.
func sanitizeOptional(data json.RawMessage) json.RawMessage {
	var top map[string]json.RawMessage
	if json.Unmarshal(data, &top) != nil {
		return data
	}
	changed := false
	drop := func(m map[string]json.RawMessage, key string, into func() any) bool {
		v, ok := m[key]
		if !ok || json.Unmarshal(v, into()) == nil {
			return false
		}
		delete(m, key)
		return true
	}
	changed = drop(top, "aaIndexVersion", func() any { return new(string) }) || changed
	changed = drop(top, "planMetering", func() any { return new(*PlanMetering) }) || changed
	changed = drop(top, "planModels", func() any { return new(*PlanModels) }) || changed
	var models []map[string]json.RawMessage
	if raw, ok := top["models"]; ok && json.Unmarshal(raw, &models) == nil {
		modelsChanged := false
		for _, m := range models {
			var efforts []map[string]json.RawMessage
			if json.Unmarshal(m["efforts"], &efforts) != nil {
				continue
			}
			effortsChanged := false
			for _, e := range efforts {
				effortsChanged = drop(e, "aaScore", func() any { return new(*float64) }) || effortsChanged
			}
			if effortsChanged {
				if b, err := json.Marshal(efforts); err == nil {
					m["efforts"], modelsChanged = b, true
				}
			}
		}
		if modelsChanged {
			if b, err := json.Marshal(models); err == nil {
				top["models"], changed = b, true
			}
		}
	}
	if !changed {
		return data
	}
	b, err := json.Marshal(top)
	if err != nil {
		return data
	}
	return b
}

// dropInvalidAAScores keeps an effort's aaScore only where the public reader accepts it: a positive finite number in a
// client-v1.5 or later projection. A bad reference value is dropped, never the publication or our own ability score.
func dropInvalidAAScores(d *Digest) {
	minor := -1
	if v, ok := strings.CutPrefix(d.ProjectionVersion, "client-v1."); ok {
		if n, err := strconv.Atoi(v); err == nil {
			minor = n
		}
	}
	scored := false
	for i := range d.Models {
		for j := range d.Models[i].Efforts {
			e := &d.Models[i].Efforts[j]
			if e.AAScore != nil && (minor < 5 || !(*e.AAScore > 0) || math.IsInf(*e.AAScore, 0)) {
				e.AAScore = nil
			}
			scored = scored || e.AAScore != nil
		}
	}
	if !scored {
		d.AAIndexVersion = ""
	}
}
