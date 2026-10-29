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
	UserAuthored bool   `json:"userAuthored,omitempty"`
}

type Reason struct {
	Code Code `json:"code"`
	Text Text `json:"text"`
}

type NextStep struct {
	Action         Action          `json:"action"`
	Text           Text            `json:"text"`
	AvailableAt    *time.Time      `json:"availableAt,omitempty"`
	DisabledReason *DisabledReason `json:"disabledReason,omitempty"`
}

type Row struct {
	ID               string       `json:"id"`
	Kind             Kind         `json:"kind"`
	Order            int          `json:"order"`
	Name             Name         `json:"name"`
	VendorKey        *string      `json:"vendorKey"`
	Surfaces         []Surface    `json:"surfaces"`
	Consent          Consent      `json:"consent"`
	State            State        `json:"state"`
	Reason           Reason       `json:"reason"`
	NextStep         *NextStep    `json:"nextStep"`
	Accounts         []Account    `json:"accounts"`
	ExpiresAt        *time.Time   `json:"expiresAt"`
	StateAfterExpiry *ExpiryState `json:"stateAfterExpiry"`
}

// ExpiryState is a conservative, non-fresh latch, never another full row.
type ExpiryState struct {
	State    State     `json:"state"`
	Reason   Reason    `json:"reason"`
	NextStep *NextStep `json:"nextStep"`
}

type Account struct {
	Route           Route      `json:"route"`
	SubscriptionRef *string    `json:"subscriptionRef"`
	AccountLocator  *string    `json:"accountLocator"`
	Plan            Plan       `json:"plan"`
	Beta            bool       `json:"beta"`
	Credits         *Credits   `json:"credits"`
	ValueState      ValueState `json:"valueState"`
	ObservedAt      *time.Time `json:"observedAt"`
	FreshUntil      *time.Time `json:"freshUntil"`
	LastFailure     *Failure   `json:"lastFailure"`
	Windows         []Window   `json:"windows"`
}

type Plan struct {
	ID string `json:"id"`
	// Unknown harness plans are exactly {"id":"unknown"}.
	Name *Name `json:"name,omitempty"`
}

type Credits struct {
	Balance *float64 `json:"balance"`
	Unit    string   `json:"unit"`
}

type Failure struct {
	Code Code      `json:"code"`
	At   time.Time `json:"at"`
}

type Window struct {
	ID               string     `json:"id"`
	Role             Role       `json:"role"`
	DurationSeconds  *int64     `json:"durationSeconds"`
	Label            Text       `json:"label"`
	LimitKey         string     `json:"limitKey"`
	PoolKey          string     `json:"poolKey"`
	ResetMode        ResetMode  `json:"resetMode"`
	RemainingPercent *float64   `json:"remainingPercent"`
	ResetsAt         *time.Time `json:"resetsAt"`
	ObservedAt       *time.Time `json:"observedAt"`
	Current          bool       `json:"current"`
	ValidUntil       *time.Time `json:"validUntil"`
}

type RowsSummary struct {
	State    SummaryState `json:"state"`
	Reason   Reason       `json:"reason"`
	Text     Text         `json:"text"`
	NextStep *NextStep    `json:"nextStep"`
}

// Projection is the additive desktop-v1 payload, not a quota Report.
type Projection struct {
	RowsVersion       int         `json:"rowsVersion"`
	ConsentGeneration uint64      `json:"consentGeneration"`
	Rows              []Row       `json:"rows"`
	RowsSummary       RowsSummary `json:"rowsSummary"`
}
