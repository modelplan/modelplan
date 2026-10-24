package digest

import "encoding/json"

// Publication is the versioned public-only view of a parsed client digest.
// Keep the selected published arrays verbatim: display DTOs can omit incomplete
// values or decode nullable numbers as zero. This feed must preserve nulls,
// speed qualifiers, harness aliases and publication order without deriving data.
type Publication struct {
	SchemaVersion int     `json:"schemaVersion"`
	PublicationID string  `json:"publicationId"`
	PublishedAt   *string `json:"publishedAt"`
	Units         Units   `json:"units"`
	publicationFields
}

type publicationFields struct {
	Models     json.RawMessage `json:"models"`
	Lineups    json.RawMessage `json:"lineups"`
	SpeedTiers json.RawMessage `json:"speedTiers"`
}

// Publication selects only public recommendation fields. Metadata is assigned
// by the publication loader from the verified manifest, never component data.
func (d *Digest) Publication() Publication {
	p := Publication{SchemaVersion: 1, PublicationID: d.PublicationID, Units: d.Units, publicationFields: d.publication}
	if d.PublishedAt != "" {
		at := d.PublishedAt
		p.PublishedAt = &at
	}
	if len(p.SpeedTiers) == 0 || string(p.SpeedTiers) == "null" {
		p.SpeedTiers = json.RawMessage("[]")
	}
	return p
}
