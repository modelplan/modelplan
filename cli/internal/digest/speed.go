package digest

import "encoding/json"

// SpeedTier is a harness setting that runs the same model faster at a higher rate
// (client-v1.2, #347): Codex Fast / Ultrafast and Claude Code fast mode. Speed is token
// generation, never task time; a nil ratio means the vendor did not state one.
type SpeedTier struct {
	ID          string `json:"id"`
	Harness     string `json:"harness"` // codex | claude-code
	Tier        string `json:"tier"`    // fast | ultrafast
	Label       string `json:"label"`
	Toggle      string `json:"toggle"`
	Eligibility struct {
		Plans []string `json:"plans"`
		Note  string   `json:"note"`
	} `json:"eligibility"`
	Models  []SpeedTierModel `json:"models"`
	Billing []SpeedBilling   `json:"billing"`
	Caveats []string         `json:"caveats"`
	Sources []string         `json:"sources"`
}

type SpeedTierModel struct {
	VendorModelID string  `json:"vendorModelId"`
	ModelID       *string `json:"modelId"`
	Speed         struct {
		Ratio     *float64 `json:"ratio"`
		Qualifier string   `json:"qualifier"` // up-to | approximate | unstated
	} `json:"speed"`
}

// SpeedBilling: what the tier costs for one kind of account, as a multiple of Standard.
type SpeedBilling struct {
	Account string  `json:"account"` // subscription | credits | api
	BillsTo string  `json:"billsTo"` // plan-quota | usage-credits | credits | api
	Basis   string  `json:"basis"`   // included-usage | credit-rate | token-price
	Ratio   float64 `json:"ratio"`
}

// ModelTier is one tier as it applies to one published model.
type ModelTier struct {
	*SpeedTier
	Model *SpeedTierModel
}

// SpeedTiers lists the tiers that apply to a published model, optionally for one harness.
func (d *Digest) SpeedTiers(modelID, harness string) []ModelTier {
	var out []ModelTier
	for i := range d.Speed {
		t := &d.Speed[i]
		if harness != "" && t.Harness != harness {
			continue
		}
		for j := range t.Models {
			if m := &t.Models[j]; m.ModelID != nil && *m.ModelID == modelID {
				out = append(out, ModelTier{t, m})
			}
		}
	}
	return out
}

// MarshalJSON is the tier as it applies to this model, without the other models.
func (t ModelTier) MarshalJSON() ([]byte, error) {
	return json.Marshal(struct {
		ID          string         `json:"id"`
		Harness     string         `json:"harness"`
		Tier        string         `json:"tier"`
		Label       string         `json:"label"`
		Toggle      string         `json:"toggle"`
		Eligibility any            `json:"eligibility"`
		Model       SpeedTierModel `json:"model"`
		Billing     []SpeedBilling `json:"billing"`
		Caveats     []string       `json:"caveats"`
		Sources     []string       `json:"sources"`
	}{t.ID, t.Harness, t.Tier, t.Label, t.Toggle, t.Eligibility, *t.Model, t.Billing, t.Caveats, t.Sources})
}

// Rate is the billing multiple for an account kind, or nil.
func (t ModelTier) Rate(account string) *SpeedBilling {
	for i := range t.Billing {
		if t.Billing[i].Account == account {
			return &t.Billing[i]
		}
	}
	return nil
}

func (t ModelTier) Has(caveat string) bool {
	for _, c := range t.Caveats {
		if c == caveat {
			return true
		}
	}
	return false
}
