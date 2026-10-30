// SPDX-License-Identifier: MIT
package wire

import "github.com/modelplan/modelplan/cli/internal/rows"

// CockpitData contains display DTOs only. Consent context belongs in Envelope.
// Go groups verified bindings so the page never interprets accounts as plans.
type CockpitData struct {
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
