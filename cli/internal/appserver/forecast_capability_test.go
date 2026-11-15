// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"slices"
	"testing"
)

// Settings asks each engine session for this exact name; the cockpit field has its own.
func TestEngineReportsTheForecastCapabilities(t *testing.T) {
	caps := (&SharedBackend{}).Capabilities()
	for _, want := range []string{"forecastProducerV1", "cockpitForecastV1"} {
		if !slices.Contains(caps, want) {
			t.Fatalf("capabilities %v lack %s", caps, want)
		}
	}
}

func TestCockpitForecastNeedsNegotiation(t *testing.T) {
	if CockpitForecastEnabled(context.Background()) {
		t.Fatal("forecast enabled without negotiation")
	}
	if !CockpitForecastEnabled(context.WithValue(context.Background(), cockpitForecastContextKey{}, true)) {
		t.Fatal("negotiated forecast not seen")
	}
}
