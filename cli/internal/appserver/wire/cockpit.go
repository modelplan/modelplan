// SPDX-License-Identifier: MIT
package wire

import (
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/rows"
)

// CockpitQueryParams carries the App's committed display threshold.
// Omission uses the documented default. Explicit null is not a threshold.
type CockpitQueryParams struct {
	RedBelow int `json:"redBelow,omitempty" schema:"minimum=10,maximum=40" null:"forbidden"`
}

// CockpitData contains display DTOs only. Consent context belongs in Envelope.
// Go groups verified bindings so the page never interprets accounts as plans.
type CockpitData struct {
	Details       *CockpitDetails       `json:"details,omitempty" null:"coalesced"`
	History       *CockpitHistory       `json:"history,omitempty" null:"coalesced"`
	Projection    RowsProjection        `json:"projection"`
	Subscriptions []CockpitSubscription `json:"subscriptions"`
}
type CockpitSubscription struct {
	SubscriptionRef string           `json:"subscriptionRef" schema:"pattern=^[a-f0-9]{16}$,maxLength=16"`
	Accounts        []CockpitAccount `json:"accounts"`
}
type CockpitAccount struct {
	Tool    string       `json:"tool"`
	Account rows.Account `json:"account"`
}

// CockpitDetails is present only for a client that negotiated cockpitDetailsV1.
// Performance and sessions describe observations on this device only.
type CockpitDetails struct {
	Publication     *CockpitPublication          `json:"publication,omitempty" null:"forbidden"`
	Version         int                          `json:"version" schema:"minimum=1,maximum=1"`
	Sources         []string                     `json:"sources" schema:"maxItems=4,uniqueItems=true"`
	Subscriptions   []CockpitSubscriptionDetails `json:"subscriptions" schema:"maxItems=128"`
	Sessions        []CockpitSession             `json:"sessions" schema:"maxItems=64"`
	SessionCoverage string                       `json:"sessionCoverage"`
	ResetEvents     []rows.ResetEvent            `json:"resetEvents" schema:"maxItems=64"`
	Alerts          []CockpitAlert               `json:"alerts" schema:"maxItems=128"`
	// Forecasts is present only for a client that negotiated cockpitForecastV1.
	Forecasts []CockpitForecast `json:"forecasts,omitempty" schema:"maxItems=128" null:"forbidden"`
}

// CockpitForecast is the engine's outlook for one current window. RunsOutAt is
// present only when the window is forecast to run out before its reset.
type CockpitForecast struct {
	Source          string        `json:"source"`
	SubscriptionRef string        `json:"subscriptionRef" schema:"pattern=^[a-f0-9]{16}$,maxLength=16"`
	WindowID        string        `json:"windowId"`
	RunsOutAt       *time.Time    `json:"runsOutAt" null:"coalesced"`
	Pace            ForecastPace  `json:"pace"`
	Basis           ForecastBasis `json:"basis"`
	ObservedAt      time.Time     `json:"observedAt"`
}

// ProjectForecasts reports only windows the alert rule could also see: a current reading of a
// verified subscription the caller admits, still inside its validity.
func ProjectForecasts(projection rows.Projection, admit func(string) bool, now time.Time) []CockpitForecast {
	out := []CockpitForecast{}
	for _, row := range projection.Rows {
		for _, account := range row.Accounts {
			if account.SubscriptionRef == nil || !admit(*account.SubscriptionRef) || account.ValueState != rows.ValueStateCurrent {
				continue
			}
			for _, window := range account.Windows {
				f := window.Forecast
				if f == nil || !window.Current || window.ValidUntil == nil || !now.Before(*window.ValidUntil) || window.ObservedAt == nil {
					continue
				}
				out = append(out, CockpitForecast{Source: row.ID, SubscriptionRef: *account.SubscriptionRef, WindowID: window.ID, RunsOutAt: f.RunsOutAt, Pace: ForecastPace(f.Pace), Basis: ForecastBasis(f.Basis), ObservedAt: *window.ObservedAt})
			}
		}
	}
	sort.Slice(out, func(i, j int) bool {
		a, b := out[i], out[j]
		if a.Source != b.Source {
			return a.Source < b.Source
		}
		if a.SubscriptionRef != b.SubscriptionRef {
			return a.SubscriptionRef < b.SubscriptionRef
		}
		return a.WindowID < b.WindowID
	})
	if len(out) > 128 {
		out = out[:128]
	}
	return out
}

// CockpitPublication contains only facts from a verified public publication.
type CockpitPublication struct {
	ContractVersion int                       `json:"contractVersion" schema:"minimum=1,maximum=1"`
	PublicationID   string                    `json:"publicationId" schema:"minLength=1,maxLength=128"`
	PublishedAt     time.Time                 `json:"publishedAt"`
	Source          string                    `json:"source" schema:"minLength=1,maxLength=32"`
	Models          []CockpitPublicationModel `json:"models" schema:"maxItems=3"`
	Truncated       bool                      `json:"truncated"`
}
type CockpitPublicationModel struct {
	ID          string                     `json:"id" schema:"minLength=1,maxLength=128"`
	Name        string                     `json:"name" schema:"minLength=1,maxLength=200"`
	DeveloperID string                     `json:"developerId" schema:"minLength=1,maxLength=128"`
	Recommended string                     `json:"recommended" schema:"maxLength=64"`
	Efforts     []CockpitPublicationEffort `json:"efforts" schema:"maxItems=32"`
}
type CockpitPublicationEffort struct {
	Effort      string   `json:"effort" schema:"minLength=1,maxLength=64"`
	Label       string   `json:"label" schema:"maxLength=64"`
	Star        bool     `json:"star"`
	Multiplier  *float64 `json:"multiplier,omitempty" null:"forbidden"`
	Ability     *float64 `json:"ability" null:"coalesced"`
	Cost        *float64 `json:"cost" null:"coalesced"`
	Time        *float64 `json:"time" null:"coalesced"`
	Provisional bool     `json:"provisional,omitempty" null:"forbidden"`
}

type CockpitSubscriptionDetails struct {
	ResetCountsTruncated bool                `json:"resetCountsTruncated,omitempty" null:"forbidden"`
	ResetCards           *rows.ResetCards    `json:"resetCards,omitempty" null:"forbidden"`
	SubscriptionRef      string              `json:"subscriptionRef" schema:"pattern=^[a-f0-9]{16}$,maxLength=16"`
	ResetCounts          []CockpitResetCount `json:"resetCounts" schema:"maxItems=64"`
	Credits              *CockpitCredits     `json:"credits" null:"coalesced"`
	Today                []CockpitToday      `json:"today" schema:"maxItems=4"`
}
type CockpitResetCount struct {
	Kind      string     `json:"kind"`
	Count     *int       `json:"count" null:"coalesced"`
	ExpiresAt *time.Time `json:"expiresAt" null:"coalesced"`
}
type CockpitCredits struct {
	Balance    *float64  `json:"balance" null:"coalesced"`
	ObservedAt time.Time `json:"observedAt"`
}
type CockpitToday struct {
	Source               string   `json:"source"`
	ObservedOutputTokens int64    `json:"observedOutputTokens"`
	GenerationTps        *float64 `json:"generationTps" null:"coalesced"`
	BindingBasis         string   `json:"bindingBasis"`
}
type CockpitSession struct {
	SessionRef      string    `json:"sessionRef" schema:"pattern=^[a-f0-9]{16}$,maxLength=16"`
	Source          string    `json:"source"`
	SubscriptionRef *string   `json:"subscriptionRef" schema:"pattern=^[a-f0-9]{16}$,maxLength=16" null:"coalesced"`
	Model           string    `json:"model"`
	Effort          *string   `json:"effort" null:"coalesced"`
	ProjectLabel    *string   `json:"projectLabel" null:"coalesced"`
	LastObservedAt  time.Time `json:"lastObservedAt"`
	State           string    `json:"state"`
	Rate            *float64  `json:"rate" null:"coalesced"`
}
type CockpitAlert struct {
	Source           string  `json:"source"`
	SubscriptionRef  string  `json:"subscriptionRef" schema:"pattern=^[a-f0-9]{16}$,maxLength=16"`
	WindowID         string  `json:"windowId"`
	Severity         string  `json:"severity"`
	RemainingPercent float64 `json:"remainingPercent"`
}
