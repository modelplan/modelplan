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
	// Cost is ≈cost at public API list prices (WP-06), present only when the verified
	// publication carries prices (client-v1.6). See CockpitCost.
	Cost *CockpitCost `json:"cost,omitempty" null:"forbidden"`
	// Usage ranks every project and session by total tokens over today, 7 and 30 days (owner decision D470).
	// Present whenever local history is. Titles and labels cross only while project labels are on.
	Usage *CockpitUsage `json:"usage,omitempty" null:"forbidden"`
}

// CockpitCycleGroup is one window kind of one subscription.
type CockpitCycleGroup struct {
	SubscriptionRef string         `json:"subscriptionRef" schema:"pattern=^[a-f0-9]{16}$,maxLength=16"`
	Kind            string         `json:"kind"`
	Attribution     string         `json:"attribution"`
	Cycles          []CockpitCycle `json:"cycles" schema:"maxItems=10"`
}

// CockpitCycle is a closed cycle. HadDrop means the meter fell inside it: a banked reset or a
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
	TotalTokens      *int64   `json:"totalTokens,omitempty" null:"forbidden"`
	ReasoningTokens  *int64   `json:"reasoningTokens,omitempty" null:"forbidden"`
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

// CockpitCost is ≈cost (WP-06, D291): tokens this device counted × each model's public API
// list price from the verified publication (client-v1.6). It estimates what the same use
// would cost at API list prices; it is not what a subscription charges. It is computed on
// this device and present only when the publication carries prices. Usage of a model
// without a public price counts in UnpricedTokens and never in EstimatedUsd.
type CockpitCost struct {
	Basis    string `json:"basis"`    // api-list-price
	Currency string `json:"currency"` // USD
	// PricesAsOf is the newest asOf date among the prices used, null when none was used.
	PricesAsOf *string `json:"pricesAsOf" null:"coalesced" schema:"maxLength=10"`
	// Daily holds the last 30 local days per source; Hourly the last 48 local hours per source.
	// A day or hour without usage is not listed.
	Daily  []CockpitCostBucket `json:"daily" schema:"maxItems=480"`
	Hourly []CockpitCostBucket `json:"hourly" schema:"maxItems=384"`
	// Models ranks the published models used in each range by ≈cost; usage the publication
	// cannot name is one "unknown" entry per source.
	Models CockpitCostModels `json:"models"`
}

// CockpitCostBucket is one source's ≈cost in one local day ("2006-01-02") or hour (RFC 3339).
// Approximate: part of it came from day totals of a model with a long-context price, so the
// long-context rate could not be chosen per request; the page keeps "≈" and says why.
type CockpitCostBucket struct {
	At             string  `json:"at" schema:"maxLength=32"`
	Source         string  `json:"source"`
	EstimatedUsd   float64 `json:"estimatedUsd" schema:"minimum=0"`
	PricedTokens   int64   `json:"pricedTokens" schema:"minimum=0"`
	UnpricedTokens int64   `json:"unpricedTokens" schema:"minimum=0"`
	Approximate    bool    `json:"approximate,omitempty" null:"forbidden"`
}

type CockpitCostModels struct {
	Today     []CockpitModelCost `json:"today" schema:"maxItems=64"`
	Recent7d  []CockpitModelCost `json:"recent7d" schema:"maxItems=64"`
	Recent30d []CockpitModelCost `json:"recent30d" schema:"maxItems=64"`
}

// CockpitModelCost is one model's use from one source in a range. Model is a published model
// ID or "unknown". EstimatedUsd is null when none of its tokens had a price.
type CockpitModelCost struct {
	Model          string   `json:"model" schema:"minLength=1,maxLength=128"`
	Source         string   `json:"source"`
	EstimatedUsd   *float64 `json:"estimatedUsd" null:"coalesced" schema:"minimum=0"`
	PricedTokens   int64    `json:"pricedTokens" schema:"minimum=0"`
	UnpricedTokens int64    `json:"unpricedTokens" schema:"minimum=0"`
	Approximate    bool     `json:"approximate,omitempty" null:"forbidden"`
}

// CockpitUsage: sessions and projects ranked by one measure, total tokens (input + output + cache, each once).
type CockpitUsage struct {
	Measure   string             `json:"measure"` // total-tokens
	Today     CockpitUsageWindow `json:"today"`
	Recent7d  CockpitUsageWindow `json:"recent7d"`
	Recent30d CockpitUsageWindow `json:"recent30d"`
}

// CockpitUsageWindow: one window. Tokens and CostUsd are the window's total, background reviews included; every
// share is a part of Tokens.Total, so the listed rows, Other and BackgroundReview add up to 1. Rows are the
// largest first, at most 200 each; the rest are summed in Other.
type CockpitUsageWindow struct {
	Tokens           CockpitUsageTokens       `json:"tokens"`
	CostUsd          *float64                 `json:"costUsd" null:"coalesced"`
	CostState        CockpitCostState         `json:"costState"`
	SessionCount     int                      `json:"sessionCount"`
	ProjectCount     int                      `json:"projectCount"`
	Projects         []CockpitUsageProject    `json:"projects" schema:"maxItems=200"`
	Sessions         []CockpitUsageSession    `json:"sessions" schema:"maxItems=200"`
	OtherProjects    CockpitUsageOther        `json:"otherProjects"`
	OtherSessions    CockpitUsageOther        `json:"otherSessions"`
	BackgroundReview *CockpitBackgroundReview `json:"backgroundReview" null:"coalesced"`
}

// CockpitUsageTokens: Total is the sum of the days whose parts are all known; Complete is false when some day was
// recorded before its input and cache sums were kept, which then adds nothing to Total (never its output alone).
type CockpitUsageTokens struct {
	Total      int64 `json:"total" schema:"minimum=0"`
	Input      int64 `json:"input" schema:"minimum=0"`
	Output     int64 `json:"output" schema:"minimum=0"`
	CacheRead  int64 `json:"cacheRead" schema:"minimum=0"`
	CacheWrite int64 `json:"cacheWrite" schema:"minimum=0"`
	Complete   bool  `json:"complete"`
}

// CockpitUsageProject: the sessions under one project reference, summed. Label is present only while project
// labels are on and only for a repo or workspace; a bucket kind has none.
type CockpitUsageProject struct {
	Ref              string             `json:"ref" schema:"maxLength=64"`
	Kind             CockpitProjectKind `json:"kind"`
	Label            *string            `json:"label" null:"coalesced"`
	Sessions         int                `json:"sessions"`
	Sources          []string           `json:"sources" schema:"maxItems=16"`
	SubscriptionRefs []string           `json:"subscriptionRefs" schema:"maxItems=16"`
	LastObservedAt   time.Time          `json:"lastObservedAt"`
	Running          bool               `json:"running"`
	Tokens           CockpitUsageTokens `json:"tokens"`
	Share            float64            `json:"share" schema:"minimum=0,maximum=1"`
	CostUsd          *float64           `json:"costUsd" null:"coalesced"`
	CostState        CockpitCostState   `json:"costState"`
	Model            *string            `json:"model" null:"coalesced"`
	ModelApprox      bool               `json:"modelApprox"`
	Effort           *string            `json:"effort" null:"coalesced"`
}

// CockpitUsageSession: one tool thread. Title is the tool's own generated or user-set title, never the first
// message, and present only while project labels are on. A folded background review is CockpitBackgroundReview,
// never a session row.
type CockpitUsageSession struct {
	SessionRef      string              `json:"sessionRef" schema:"pattern=^[a-f0-9]{16}$,maxLength=16"`
	Source          string              `json:"source"`
	SubscriptionRef *string             `json:"subscriptionRef" schema:"pattern=^[a-f0-9]{16}$,maxLength=16" null:"coalesced"`
	ProjectRef      *string             `json:"projectRef" schema:"maxLength=64" null:"coalesced"`
	ProjectKind     CockpitProjectKind  `json:"projectKind"`
	ProjectLabel    *string             `json:"projectLabel" null:"coalesced"`
	ProjectState    CockpitProjectState `json:"projectState"`
	Title           *string             `json:"title" null:"coalesced"`
	FirstObservedAt time.Time           `json:"firstObservedAt"`
	LastObservedAt  time.Time           `json:"lastObservedAt"`
	Running         bool                `json:"running"`
	Tokens          CockpitUsageTokens  `json:"tokens"`
	Share           float64             `json:"share" schema:"minimum=0,maximum=1"`
	CostUsd         *float64            `json:"costUsd" null:"coalesced"`
	CostState       CockpitCostState    `json:"costState"`
	Model           *string             `json:"model" null:"coalesced"`
	// ModelApprox: the model is the dated fallback for a row that has none, to be shown with "≈".
	ModelApprox bool    `json:"modelApprox"`
	Effort      *string `json:"effort" null:"coalesced"`
}

// CockpitUsageOther: the rows past the 200 listed, summed.
type CockpitUsageOther struct {
	Count     int                `json:"count"`
	Tokens    CockpitUsageTokens `json:"tokens"`
	Share     float64            `json:"share" schema:"minimum=0,maximum=1"`
	CostUsd   *float64           `json:"costUsd" null:"coalesced"`
	CostState CockpitCostState   `json:"costState"`
}

// CockpitBackgroundReview folds the Codex background review runs (Auto Review) of a window into one row. It is a
// kind of session, never a model: its tokens count toward the window total and its model is the dated fallback,
// to be shown with "≈". Null when the window had none.
type CockpitBackgroundReview struct {
	Runs           int                `json:"runs"`
	Tokens         CockpitUsageTokens `json:"tokens"`
	Share          float64            `json:"share" schema:"minimum=0,maximum=1"`
	CostUsd        *float64           `json:"costUsd" null:"coalesced"`
	CostState      CockpitCostState   `json:"costState"`
	Model          *string            `json:"model" null:"coalesced"`
	ModelApprox    bool               `json:"modelApprox"`
	LastObservedAt time.Time          `json:"lastObservedAt"`
}
