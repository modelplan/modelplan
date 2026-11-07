// SPDX-License-Identifier: MIT
package rows

import "time"

const Version = 1

type Text struct {
	EN string `json:"en"`
	ZH string `json:"zh"`
}

// Name marks user-declared text at the name itself; compiled titles omit the flag.
type Name struct {
	EN           string `json:"en"`
	ZH           string `json:"zh"`
	UserAuthored bool   `json:"userAuthored,omitempty" null:"coalesced"`
}

type Reason struct {
	Code Code `json:"code"`
	Text Text `json:"text"`
}

type NextStep struct {
	Action         Action          `json:"action"`
	Text           Text            `json:"text"`
	AvailableAt    *time.Time      `json:"availableAt,omitempty" null:"coalesced"`
	DisabledReason *DisabledReason `json:"disabledReason,omitempty" null:"coalesced"`
}

type Row struct {
	RefreshNotBefore **time.Time  `json:"refreshNotBefore,omitempty" null:"coalesced"`
	ID               string       `json:"id"`
	Kind             Kind         `json:"kind"`
	Order            int          `json:"order"`
	Name             Name         `json:"name"`
	VendorKey        *string      `json:"vendorKey" null:"coalesced"`
	Surfaces         []Surface    `json:"surfaces"`
	Consent          Consent      `json:"consent"`
	State            State        `json:"state"`
	Reason           Reason       `json:"reason"`
	NextStep         *NextStep    `json:"nextStep" null:"coalesced"`
	Accounts         []Account    `json:"accounts"`
	ExpiresAt        *time.Time   `json:"expiresAt" null:"coalesced"`
	StateAfterExpiry *ExpiryState `json:"stateAfterExpiry" null:"coalesced"`
}

// ExpiryState is a conservative, non-fresh latch, never another full row.
type ExpiryState struct {
	State    State     `json:"state"`
	Reason   Reason    `json:"reason"`
	NextStep *NextStep `json:"nextStep" null:"coalesced"`
}

type ResetCardState string

const (
	ResetCardUnknown  ResetCardState = "unknown"
	ResetCardPartial  ResetCardState = "partial"
	ResetCardComplete ResetCardState = "complete"
)

type ResetCardSourceKind string

const (
	ResetCardCodexAccount ResetCardSourceKind = "codex-account"
	ResetCardCodexBar     ResetCardSourceKind = "codexbar"
)

// ResetCards is a consent-fenced observation; count is nil when unknown.
type ResetCards struct {
	State             ResetCardState    `json:"state"`
	Count             *int              `json:"count" schema:"minimum=0,maximum=10000" null:"coalesced"`
	EarliestExpiresAt *time.Time        `json:"earliestExpiresAt,omitempty" null:"forbidden"`
	Items             []ResetCardItem   `json:"items,omitempty" schema:"maxItems=64" null:"forbidden"`
	Truncated         bool              `json:"truncated"`
	Sources           []ResetCardSource `json:"sources" schema:"maxItems=16"`
}
type ResetCardItem struct {
	ID        string     `json:"id" schema:"pattern=^[a-f0-9]{64}$,maxLength=64"`
	ExpiresAt *time.Time `json:"expiresAt" null:"coalesced"`
}
type ResetCardSource struct {
	Source     ResetCardSourceKind `json:"source"`
	ObservedAt time.Time           `json:"observedAt"`
}

type Account struct {
	Today            *AccountToday     `json:"today,omitempty" null:"forbidden"`
	Activity         []AccountActivity `json:"activity,omitempty" null:"coalesced"`
	ResetCards       *ResetCards       `json:"resetCards,omitempty" null:"forbidden"`
	RefreshNotBefore **time.Time       `json:"refreshNotBefore,omitempty" null:"coalesced"`
	Route            Route             `json:"route"`
	SubscriptionRef  *string           `json:"subscriptionRef" null:"coalesced"`
	AccountLocator   *string           `json:"accountLocator" null:"coalesced"`
	Plan             Plan              `json:"plan"`
	Beta             bool              `json:"beta"`
	Credits          *Credits          `json:"credits" null:"coalesced"`
	ValueState       ValueState        `json:"valueState"`
	ObservedAt       *time.Time        `json:"observedAt" null:"coalesced"`
	FreshUntil       *time.Time        `json:"freshUntil" null:"coalesced"`
	LastFailure      *Failure          `json:"lastFailure" null:"coalesced"`
	Windows          []Window          `json:"windows"`
}

// AccountToday contains only observed values; omission means unknown.
type AccountToday struct {
	ObservedOutputTokens *int64            `json:"observedOutputTokens,omitempty" null:"forbidden" schema:"minimum=1"`
	GenerationTps        *float64          `json:"generationTps,omitempty" null:"forbidden" schema:"minimum=0"`
	RunningSessions      *int              `json:"runningSessions,omitempty" null:"forbidden" schema:"minimum=1"`
	BindingBasis         TodayBindingBasis `json:"bindingBasis"`
}

// AccountActivity contains no path, transcript, raw session ID or credential.
// SubscriptionRef must match its parent account; SessionRef is an opaque local ref.
type AccountActivity struct {
	SessionRef      string        `json:"sessionRef"`
	SubscriptionRef string        `json:"subscriptionRef"`
	BindingVerified bool          `json:"bindingVerified"`
	Phase           ActivityPhase `json:"phase"`
	RecordAt        time.Time     `json:"recordAt"`
	ExpiresAt       time.Time     `json:"expiresAt"`
}

type Plan struct {
	ID string `json:"id"`
	// Unknown harness plans are exactly {"id":"unknown"}.
	Name *Name `json:"name,omitempty" null:"coalesced"`
}

type Credits struct {
	Balance *float64 `json:"balance" null:"coalesced"`
	Unit    string   `json:"unit"`
}

type Failure struct {
	Code Code      `json:"code"`
	At   time.Time `json:"at"`
}

type ModelScope struct {
	Models []string `json:"models"`
}

type Window struct {
	Source           *WindowSource `json:"source,omitempty" null:"forbidden"`
	ModelScope       *ModelScope   `json:"modelScope,omitempty" null:"forbidden"`
	ID               string        `json:"id"`
	Role             Role          `json:"role"`
	DurationSeconds  *int64        `json:"durationSeconds" null:"coalesced"`
	Label            Text          `json:"label"`
	LimitKey         string        `json:"limitKey"`
	PoolKey          string        `json:"poolKey"`
	ResetMode        ResetMode     `json:"resetMode"`
	RemainingPercent *float64      `json:"remainingPercent" null:"coalesced"`
	ResetsAt         *time.Time    `json:"resetsAt" null:"coalesced"`
	ObservedAt       *time.Time    `json:"observedAt" null:"coalesced"`
	Current          bool          `json:"current"`
	ValidUntil       *time.Time    `json:"validUntil" null:"coalesced"`
	// Forecast stays out of the rows contract; the cockpit details project it when negotiated.
	Forecast *WindowForecast `json:"-"`
}

// WindowForecast is the quota engine's outlook for one window. RunsOutAt is set only
// when the window is forecast to be used up before its reset.
type WindowForecast struct {
	RunsOutAt *time.Time `null:"coalesced"`
	Pace      string     // tight | on_track | surplus | exhausted
	Basis     string     // recent-rate | cycle-average | none
}

type RowsSummary struct {
	State    SummaryState `json:"state"`
	Reason   Reason       `json:"reason"`
	Text     Text         `json:"text"`
	NextStep *NextStep    `json:"nextStep" null:"coalesced"`
}

// Projection is the additive desktop-v1 payload, not a quota Report.
type Projection struct {
	RowsVersion       int         `json:"rowsVersion"`
	ConsentGeneration uint64      `json:"consentGeneration"`
	Rows              []Row       `json:"rows"`
	RowsSummary       RowsSummary `json:"rowsSummary"`
}
