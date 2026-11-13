// SPDX-License-Identifier: MIT
package appserver

import "context"

// CapabilityCockpitHistoryV1 opts in to the 7/30-day local performance history and rankings.
const CapabilityCockpitHistoryV1 = "cockpitHistoryV1"

type cockpitHistoryContextKey struct{}

func CockpitHistoryEnabled(ctx context.Context) bool {
	enabled, _ := ctx.Value(cockpitHistoryContextKey{}).(bool)
	return enabled
}
