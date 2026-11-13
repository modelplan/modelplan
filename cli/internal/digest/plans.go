package digest

import (
	"net/url"
	"strings"
)

// Billing bases (client-v1.3 planMetering): how a plan counts a model's use.
const (
	BasisAPI      = "api-proportional"    // in step with the API price (Claude, ChatGPT: assumed)
	BasisTariff   = "token-tariff"        // plan units per API USD, per model (unitsPerUsd)
	BasisRelative = "relative-multiplier" // a multiplier per model on the API price
	BasisRequest  = "per-request"         // a multiplier per request; effort does not change it
	BasisPool     = "per-model-pool"      // each model draws its own allowance
	BasisOpaque   = "opaque"              // the vendor does not publish per-model rates
)

// PlanMetering (client-v1.3) says, per plan and generation, how a model's use is counted.
// Plans and models without a row are unknown, never assumed.
type PlanMetering struct {
	Revision string        `json:"revision"`
	Plans    []MeteredPlan `json:"plans"`
}

type MeteredPlan struct {
	PlanID       string     `json:"planId"`
	Generation   string     `json:"generation"` // "" when the plan has one way of metering
	Basis        string     `json:"basis"`
	BasisAssumed bool       `json:"basisAssumed"`
	Unit         string     `json:"unit"`
	TimeRules    []string   `json:"timeRules"` // ruleIds of the multiplier windows that apply
	Rows         []MeterRow `json:"rows"`
}

type MeterRow struct {
	ModelID     string   `json:"modelId"`
	UnitsPerUSD *float64 `json:"unitsPerUsd"`
	Multiplier  *float64 `json:"multiplier"`
	Amount      *float64 `json:"amount"` // per-model-pool: the model's own allowance
}

// Metering is the plan's metering for a generation. Without one, only a plan that meters one
// way qualifies; a plan with several generations needs the user to say which.
func (d *Digest) Metering(plan, generation string) *MeteredPlan {
	if d == nil || d.PlanMetering == nil {
		return nil
	}
	var hit []*MeteredPlan
	for i := range d.PlanMetering.Plans {
		p := &d.PlanMetering.Plans[i]
		if p.PlanID != plan {
			continue
		}
		if p.Generation == generation {
			return p
		}
		if generation == "" {
			hit = append(hit, p)
		}
	}
	if len(hit) == 1 {
		return hit[0]
	}
	return nil
}

// Generations lists the metering generations published for a plan.
func (d *Digest) Generations(plan string) []string {
	var out []string
	if d == nil || d.PlanMetering == nil {
		return nil
	}
	for _, p := range d.PlanMetering.Plans {
		if p.PlanID == plan {
			out = append(out, p.Generation)
		}
	}
	return out
}

func (p *MeteredPlan) Row(model string) *MeterRow {
	if p == nil {
		return nil
	}
	for i := range p.Rows {
		if p.Rows[i].ModelID == model {
			return &p.Rows[i]
		}
	}
	return nil
}

// validMetering drops a malformed planMetering instead of the whole publication: advice then
// falls back to API cost, as before v1.3.
func validMetering(m *PlanMetering) bool {
	for _, p := range m.Plans {
		if p.PlanID == "" || p.Basis == "" {
			return false
		}
		for _, r := range p.Rows {
			if r.ModelID == "" {
				return false
			}
		}
	}
	return true
}

// Endpoint is the scheme, host and path of a base URL, lower-cased host, without credentials,
// query or a trailing slash; "" when it is not an http(s) URL. Only this form is recorded.
func Endpoint(raw string) string {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil || (u.Scheme != "https" && u.Scheme != "http") || u.Host == "" {
		return ""
	}
	return u.Scheme + "://" + strings.ToLower(u.Host) + strings.TrimRight(u.EscapedPath(), "/")
}

// MatchAt is Match with the harness's endpoint known: a model that is only reachable through a
// custom endpoint (GLM in Claude Code through Z.ai) matches when that endpoint is the one in use.
func (d *Digest) MatchAt(harness, endpoint string, ids ...string) *Model {
	if m := d.Match(harness, ids...); m != nil {
		return m
	}
	ep := Endpoint(endpoint)
	if ep == "" {
		return nil
	}
	for i := range d.Models {
		e := d.Models[i].HarnessEvidence
		if e == nil || Endpoint(e.RequiredEndpoints[harness]) != ep {
			continue
		}
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

// ViaEndpoint: the model is reached in this harness only through a custom endpoint, so the
// harness's own plan does not pay for it.
func (m *Model) ViaEndpoint(harness string) bool {
	return m != nil && m.HarnessEvidence != nil && m.HarnessEvidence.RequiredEndpoints[harness] != ""
}
