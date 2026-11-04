// SPDX-License-Identifier: MIT
package rows

import (
	"fmt"
	"testing"
	"time"
)

func TestResetCardsDifferingSourceObservationsArePartial(t *testing.T) {
	now := time.Date(2026, 11, 3, 12, 0, 0, 0, time.UTC)
	expiry := now.Add(time.Hour)
	count := 2
	items := []ResetCardItem{{ID: fmt.Sprintf("%064x", 1), ExpiresAt: &expiry}, {ID: fmt.Sprintf("%064x", 2), ExpiresAt: &expiry}}
	left := &ResetCards{State: ResetCardComplete, Count: &count, Items: items, Sources: []ResetCardSource{{Source: ResetCardCodexAccount, ObservedAt: now}}}
	right := &ResetCards{State: ResetCardComplete, Count: &count, Items: items, Sources: []ResetCardSource{{Source: ResetCardCodexBar, ObservedAt: now.Add(-time.Minute)}}}
	got := mergeResetCards([]*ResetCards{left, right})
	if got.State != ResetCardPartial || got.Count != nil || got.EarliestExpiresAt != nil {
		t.Fatalf("different observation times asserted complete: %+v", got)
	}
	if len(got.Items) != 2 || len(got.Sources) != 2 {
		t.Fatalf("lost partial facts: %+v", got)
	}
}
