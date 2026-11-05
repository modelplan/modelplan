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
	Measure     string               `json:"measure"` // observed-output-tokens
	Attribution string               `json:"attribution"`
	Recent7d    CockpitEntityWindow  `json:"recent7d"`
	Recent30d   CockpitEntityWindow  `json:"recent30d"`
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
