// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"testing"
)

func TestCockpitHistoryEnabledFollowsNegotiatedCapability(t *testing.T) {
	if CockpitHistoryEnabled(context.Background()) {
		t.Fatal("history projection offered without negotiation")
	}
	ctx := context.WithValue(context.Background(), cockpitHistoryContextKey{}, true)
	if !CockpitHistoryEnabled(ctx) {
		t.Fatal("negotiated capability not observed")
	}
	if CapabilityCockpitHistoryV1 != "cockpitHistoryV1" {
		t.Fatalf("capability name drifted: %q", CapabilityCockpitHistoryV1)
	}
}
