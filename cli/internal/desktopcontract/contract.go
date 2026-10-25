// SPDX-License-Identifier: MIT
// Package desktopcontract declares wire capabilities, not observed account values.
package desktopcontract

const Version = 1

type Capability struct {
	Status string `json:"status"`
	Reason string `json:"reason,omitempty"`
}

// PersonalCapabilities describes the command surface. Source-dependent never means
// that a particular account has supplied a reading or authorized a reader.
func PersonalCapabilities() map[string]Capability {
	return map[string]Capability{
		"quotaWindows":        {Status: "supported"},
		"extraQuotaScopes":    {Status: "source-dependent", Reason: "reported-limit-only; model/feature identity is not inferred"},
		"resetCards":          {Status: "source-dependent"},
		"creditsBalance":      {Status: "source-dependent"},
		"creditsHistory":      {Status: "unavailable", Reason: "no-supported-local-source"},
		"resetDropProvenance": {Status: "unavailable", Reason: "meter-drops-do-not-identify-redemption-or-correction"},
		"observedUsage":       {Status: "source-dependent"},
		"sessionRates60s":     {Status: "source-dependent"},
		"projects":            {Status: "source-dependent", Reason: "opaque-local-refs; labels-respect-projectLabels"},
		"historyAttribution":  {Status: "supported", Reason: "source-wide-unless-observed-session-subscriptionRef-proves-ownership"},
		"dailyLong":           {Status: "source-dependent", Reason: "371-day-retention; coverage-is-observed-not-imputed"},
		"quotaCycles":         {Status: "source-dependent", Reason: "source-plan-window-attribution; not-historical-account-ownership"},
		"alerts":              {Status: "supported"},
	}
}

func PublicationCapabilities() map[string]Capability {
	return map[string]Capability{
		"effortLadders":         {Status: "supported"},
		"speedTiers":            {Status: "publication-dependent"},
		"publicResets":          {Status: "publication-dependent"},
		"scopedWindows":         {Status: "publication-dependent"},
		"planMetering":          {Status: "publication-dependent", Reason: "published-metering-is-not-proof-of-entitlement"},
		"lineageSelection":      {Status: "unavailable", Reason: "representatives-and-retirement-not-published-by-current-client-projection"},
		"subscriptionOfferings": {Status: "unavailable", Reason: "harness-aliases-and-metering-do-not-prove-model-entitlement"},
	}
}
