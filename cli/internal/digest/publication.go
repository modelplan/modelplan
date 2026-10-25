package digest

import (
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/desktopcontract"
)

// Publication is the versioned public-only view of a parsed client digest.
// Keep the selected published arrays verbatim: display DTOs can omit incomplete
// values or decode nullable numbers as zero. This feed must preserve nulls,
// speed qualifiers, harness aliases and publication order without deriving data.
type Publication struct {
	ContractVersion int                                   `json:"contractVersion"`
	Capabilities    map[string]desktopcontract.Capability `json:"capabilities"`
	SchemaVersion   int                                   `json:"schemaVersion"`
	PublicationID   string                                `json:"publicationId"`
	PublishedAt     *string                               `json:"publishedAt"`
	Units           Units                                 `json:"units"`
	publicationFields
}

type publicationFields struct {
	Models            json.RawMessage `json:"models"`
	Lineups           json.RawMessage `json:"lineups"`
	SpeedTiers        json.RawMessage `json:"speedTiers"`
	Resets            json.RawMessage `json:"resets"`
	Windows           json.RawMessage `json:"windows"`
	Multipliers       json.RawMessage `json:"multipliers"`
	MultiplierHorizon json.RawMessage `json:"multiplierHorizon"`
	PlanMetering      json.RawMessage `json:"planMetering"`
}

// Publication selects only public recommendation fields. Metadata is assigned
// by the publication loader from the verified manifest, never component data.
func (d *Digest) Publication() Publication {
	p := Publication{ContractVersion: desktopcontract.Version, Capabilities: desktopcontract.PublicationCapabilities(), SchemaVersion: 1, PublicationID: d.PublicationID, Units: d.Units, publicationFields: d.publication}
	if d.PublishedAt != "" {
		at := d.PublishedAt
		p.PublishedAt = &at
	}
	if len(p.SpeedTiers) == 0 || string(p.SpeedTiers) == "null" {
		p.SpeedTiers = json.RawMessage("[]")
	}
	if len(p.Resets) == 0 {
		p.Resets = json.RawMessage("[]")
	}
	if len(p.Windows) == 0 {
		p.Windows = json.RawMessage("[]")
	}
	// Parse already rejects malformed metering for all existing consumers. Do not
	// resurrect the original malformed raw field in this public projection.
	if d.PlanMetering == nil {
		p.PlanMetering = nil
	}
	return p
}
