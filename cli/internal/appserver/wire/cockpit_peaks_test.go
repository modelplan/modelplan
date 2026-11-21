// SPDX-License-Identifier: MIT
package wire

import (
	"encoding/json"
	"strings"
	"testing"
)

// D328/D375: a client that negotiated cockpitPeaksV1 and has no peak windows gets "peaks":[] (no rules); a client
// that did not negotiate it gets no field (unknown). omitempty alone would drop the empty list.
func TestCockpitPeaksEmptyListIsSentAndAbsentIsOmitted(t *testing.T) {
	empty := []CockpitPeak{}
	got, err := json.Marshal(CockpitDetails{Peaks: &empty})
	if err != nil || !strings.Contains(string(got), `"peaks":[]`) {
		t.Fatalf("empty list must be sent: %s %v", got, err)
	}
	got, err = json.Marshal(CockpitDetails{})
	if err != nil || strings.Contains(string(got), `"peaks"`) {
		t.Fatalf("absent must be omitted: %s %v", got, err)
	}
}
