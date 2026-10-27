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
	"sort"
	"strings"
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
	Catalogue         *detect.Catalogue `json:"-"`
	publication       publicationFields
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
	PlanMetering      *PlanMetering      `json:"planMetering,omitempty"` // client-v1.3
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
	if err := json.Unmarshal(raw.Data, &d); err != nil {
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
		if l.Method != "lineup-v1" || l.Tie != 1 || l.CostBasisID == "" || l.Baseline == "" || seen[l.Baseline] == nil {
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
	if d.PlanMetering != nil && !validMetering(d.PlanMetering) {
		d.PlanMetering = nil
	}
	if err := json.Unmarshal(raw.Data, &d.publication); err != nil {
		return nil, err
	}
	d.Source = ComponentClient
	return &d, nil
}
