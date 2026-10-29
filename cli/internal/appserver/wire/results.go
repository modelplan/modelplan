// SPDX-License-Identifier: MIT
package wire

import "encoding/json"

// PluginInstallResult is the shared CLI/engine installation receipt. Commands
// are display metadata, never shell input; completed counts successful steps.
type PluginInstallResult struct {
	SchemaVersion int                 `json:"schemaVersion" schema:"minimum=1,maximum=1"`
	Tool          PluginTool          `json:"tool"`
	Status        PluginInstallStatus `json:"status"`
	Commands      [][]string          `json:"commands" schema:"minItems=2,maxItems=2"`
	Completed     int                 `json:"completed" schema:"minimum=0,maximum=2"`
	Docs          string              `json:"docs"`
}

// PublicationResult is the public projection returned by publication/get.
// Published content stays verbatim JSON, just as in digest.Publication: these
// extensible objects are published verdicts, not a second client scoring schema.
// Metadata and required containers belong to the production wire contract.
type PublicationResult struct {
	ContractVersion   int                              `json:"contractVersion" schema:"minimum=1,maximum=1"`
	Capabilities      map[string]PublicationCapability `json:"capabilities"`
	SchemaVersion     int                              `json:"schemaVersion" schema:"minimum=1,maximum=1"`
	PublicationID     string                           `json:"publicationId" schema:"minLength=1"`
	PublishedAt       *string                          `json:"publishedAt"`
	Units             PublicationUnits                 `json:"units"`
	SelectionRevision *string                          `json:"selectionRevision,omitempty"`
	Models            []json.RawMessage                `json:"models"`
	Lineups           []json.RawMessage                `json:"lineups"`
	SpeedTiers        []json.RawMessage                `json:"speedTiers"`
	Resets            []json.RawMessage                `json:"resets"`
	Windows           []json.RawMessage                `json:"windows"`
	Multipliers       *[]json.RawMessage               `json:"multipliers"`
	MultiplierHorizon *json.RawMessage                 `json:"multiplierHorizon"`
	PlanMetering      *json.RawMessage                 `json:"planMetering"`
}

type PublicationCapability struct {
	Status string `json:"status"`
	Reason string `json:"reason,omitempty"`
}
type PublicationUnits struct {
	Ability string `json:"ability"`
	Cost    string `json:"cost"`
	Time    string `json:"time"`
}
