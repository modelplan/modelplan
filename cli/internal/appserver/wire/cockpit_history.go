// SPDX-License-Identifier: MIT
package wire

import (
	"time"
)

// CockpitHistory is present only for a client that negotiated cockpitHistoryV1. Windows and
// rankings describe observations on this device only; a subscription row carries one source's
// current binding, never historic account ownership. Unknown sums stay null, never zero.
type CockpitHistory struct {
	Version        int                          `json:"version" schema:"minimum=1,maximum=1"`
	Sources        []string                     `json:"sources" schema:"maxItems=4,uniqueItems=true"`
	Coverage       string                       `json:"coverage"` // local-history | recording-off | unavailable
	RecordingSince *time.Time                   `json:"recordingSince" null:"coalesced"`
	Subscriptions  []CockpitSubscriptionHistory `json:"subscriptions" schema:"maxItems=128"`
	Models         CockpitEntityRanking         `json:"models"`
	Tools          CockpitEntityRanking         `json:"tools"`
	// Daily holds local days with observed output, per source, for the last 182 days from
	// DailyFrom on (the earliest day of live or imported data); Hourly the same for the last 48 local hours. A day or hour that is not
	// listed has no observation, which is not the same as a known zero.
	DailyFrom *string               `json:"dailyFrom" null:"coalesced"`
	Daily     []CockpitSourceBucket `json:"daily" schema:"maxItems=728"`
	Hourly    []CockpitSourceBucket `json:"hourly" schema:"maxItems=192"`
	Projects  CockpitProjectRanking `json:"projects"`
	// Cycles holds up to ten newest closed cycles per window, oldest first, under a subscription only through the
	// source's one current binding. Points are observed on this device and unattributed.
	Cycles []CockpitCycleGroup `json:"cycles" schema:"maxItems=64"`
}

// CockpitCycleGroup is one window kind of one subscription.
type CockpitCycleGroup struct {
	SubscriptionRef string         `json:"subscriptionRef" schema:"pattern=^[a-f0-9]{16}$,maxLength=16"`
	Kind            string         `json:"kind"`
	Attribution     string         `json:"attribution"`
	Cycles          []CockpitCycle `json:"cycles" schema:"maxItems=10"`
}

// CockpitCycle is a closed cycle. HadDrop means the meter fell inside it: a reset card or a
// correction, which the readings cannot tell apart.
type CockpitCycle struct {
	StartedAt time.Time           `json:"startedAt"`
	ResetsAt  time.Time           `json:"resetsAt"`
	Points    float64             `json:"points"`
	HadDrop   bool                `json:"hadDrop"`
	Spent     []CockpitCycleShare `json:"spent" schema:"maxItems=16"`
}
type CockpitCycleShare struct {
	Model  *string `json:"model" null:"coalesced"`
	Effort *string `json:"effort" null:"coalesced"`
	Fast   bool    `json:"fast"`
	Points float64 `json:"points"`
}

// CockpitSourceBucket is one source's observed output in one local day or hour. Sources are
// this device's tools, not subscriptions: the page may show them only as locally observed.
// Origin is "live" (read while the engine recorded) or "import" (older history the user imported;
// never a day a live bucket covers); the page may draw the two differently.
type CockpitSourceBucket struct {
	At                   string `json:"at" schema:"maxLength=32"`
	Source               string `json:"source"`
	Origin               string `json:"origin"`
	ObservedOutputTokens int64  `json:"observedOutputTokens"`
}

// CockpitProjectRanking ranks project references by observed output. Label is present only
// while the project-labels preference is on.
type CockpitProjectRanking struct {
	Recent7d  []CockpitRankedProject `json:"recent7d" schema:"maxItems=10"`
	Recent30d []CockpitRankedProject `json:"recent30d" schema:"maxItems=10"`
}
type CockpitRankedProject struct {
	Ref                  string  `json:"ref" schema:"maxLength=64"`
	Label                *string `json:"label" null:"coalesced"`
	Model                *string `json:"model" null:"coalesced"`
	Effort               *string `json:"effort" null:"coalesced"`
	ObservedOutputTokens int64   `json:"observedOutputTokens"`
	Share                float64 `json:"share"`
}
type CockpitSubscriptionHistory struct {
	SubscriptionRef string                 `json:"subscriptionRef" schema:"pattern=^[a-f0-9]{16}$,maxLength=16"`
	Sources         []CockpitSourceHistory `json:"sources" schema:"maxItems=4"`
}
type CockpitSourceHistory struct {
	Source       string             `json:"source"`
	BindingBasis string             `json:"bindingBasis"`
	Recent7d     CockpitHistorySums `json:"recent7d"`
	Recent30d    CockpitHistorySums `json:"recent30d"`
}
type CockpitHistorySums struct {
	InputTokens      *int64   `json:"inputTokens" null:"coalesced"`
	OutputTokens     int64    `json:"outputTokens"`
	CacheReadTokens  *int64   `json:"cacheReadTokens" null:"coalesced"`
	CacheWriteTokens *int64   `json:"cacheWriteTokens" null:"coalesced"`
	CacheHitRatio    *float64 `json:"cacheHitRatio" null:"coalesced"`
	GenerationTps    *float64 `json:"generationTps" null:"coalesced"`
	ObservedRequests int      `json:"observedRequests"`
	EligibleRequests int      `json:"eligibleRequests"`
}

// CockpitEntityRanking: models or tools this device observed, ranked by observed output tokens.
type CockpitEntityRanking struct {
	Measure     string              `json:"measure"` // observed-output-tokens
	Attribution string              `json:"attribution"`
	Recent7d    CockpitEntityWindow `json:"recent7d"`
	Recent30d   CockpitEntityWindow `json:"recent30d"`
}
type CockpitEntityWindow struct {
	Entities                  int                   `json:"entities"`
	TotalObservedOutputTokens int64                 `json:"totalObservedOutputTokens"`
	Top                       []CockpitRankedEntity `json:"top" schema:"maxItems=10"`
}
type CockpitRankedEntity struct {
	Name                 string  `json:"name"`
	ObservedRequests     int     `json:"observedRequests"`
	ObservedOutputTokens int64   `json:"observedOutputTokens"`
	Share                float64 `json:"share"`
}
