// SPDX-License-Identifier: MIT
package queries

import (
	"encoding/json"
	"testing"
)

func TestCockpitThresholdRequiresNegotiationAndCommittedValue(t *testing.T) {
	for _, tc := range []struct { raw string; enabled bool; want int; ok bool }{
		{"", false, 25, true}, {"{}", false, 25, true}, {`{"redBelow":10}`, true, 10, true},
		{`{"redBelow":16}`, true, 16, true}, {`{"redBelow":20}`, true, 20, true}, {`{"redBelow":25}`, true, 25, true},
		{`{"redBelow":10}`, false, 0, false}, {`{"redBelow":null}`, true, 0, false},
		{`{"redBelow":17}`, true, 0, false}, {`{"redBelow":0}`, true, 0, false},
		{`{"redBelow":25,"path":"secret"}`, true, 0, false}, {"null", true, 0, false},
	} {
		got, err := cockpitParams(json.RawMessage(tc.raw), tc.enabled)
		if (err == nil) != tc.ok || (tc.ok && got != tc.want) { t.Errorf("params %s negotiated=%v: got %d, %v", tc.raw, tc.enabled, got, err) }
	}
}
