// SPDX-License-Identifier: MIT
package localusage

import (
	"testing"
	"time"
)

// CodexBar 7e51f6593 (behaviour only): Grok's usage.json records every turn, and each turn's
// totalTokens and endedAt are authoritative. A turn counts once: the session-level totals are never
// added on top, model subtotals never add to the turn total a second time, and a turn whose models
// were not broken down still counts on the day it ended.
func TestGrokUsageCountsEachTurnOnce(t *testing.T) {
	day := time.Date(2026, 10, 23, 10, 0, 0, 0, time.UTC)
	for _, tc := range []struct {
		name, body string
		want       int64 // sum of Total over the datums
		models     []string
	}{
		{"turn total with matching model subtotal",
			`{"sessionId":"s","session":{"totalTokens":99999},"turns":[{"turnNumber":1,"endedAt":"2026-10-23T10:00:00.000176+00:00","totalTokens":4000,"primaryModelId":"grok-a","modelUsage":{"grok-a":{"totalTokens":4000}}},{"turnNumber":2,"endedAt":"2026-10-23T10:05:00Z","totalTokens":1000,"primaryModelId":"grok-b","modelUsage":{"grok-b":{"totalTokens":1000}}}]}`,
			5000, []string{"grok-a", "grok-b"}},
		{"turn without model breakdown counts its total",
			`{"turns":[{"turnNumber":1,"endedAt":"2026-10-23T10:00:00Z","totalTokens":300,"primaryModelId":"grok-a"}]}`,
			300, []string{"grok-a"}},
		{"single model without its own total takes the turn total",
			`{"turns":[{"turnNumber":1,"endedAt":"2026-10-23T10:00:00Z","totalTokens":700,"modelUsage":{"grok-a":{"inputTokens":600,"outputTokens":50}}}]}`,
			700, []string{"grok-a"}},
		{"model subtotals that disagree with the turn total count the turn once",
			`{"turns":[{"turnNumber":1,"endedAt":"2026-10-23T10:00:00Z","totalTokens":900,"primaryModelId":"grok-a","modelUsage":{"grok-a":{"totalTokens":900},"grok-b":{"totalTokens":900}}}]}`,
			900, []string{"grok-a"}},
		{"turns without numbers stay distinct",
			`{"turns":[{"endedAt":"2026-10-23T10:00:00Z","totalTokens":10,"primaryModelId":"grok-a"},{"endedAt":"2026-10-23T10:01:00Z","totalTokens":20,"primaryModelId":"grok-a"}]}`,
			30, []string{"grok-a", "grok-a"}},
	} {
		var state historyDecodeState
		rows, err := decodeHistory("grok", []byte(tc.body), false, &state)
		if err != nil {
			t.Fatalf("%s: %v", tc.name, err)
		}
		// The store keys rows by ID, so a repeated ID would collapse two turns into one.
		ids := map[string]bool{}
		var total int64
		var models []string
		for _, r := range rows {
			if ids[r.ID] {
				t.Errorf("%s: duplicate id %q", tc.name, r.ID)
			}
			ids[r.ID] = true
			if r.Counts.Total == nil {
				t.Errorf("%s: row %q has no total", tc.name, r.ID)
				continue
			}
			if !r.At.Truncate(time.Hour).Equal(day) {
				t.Errorf("%s: row %q at %v", tc.name, r.ID, r.At)
			}
			total += *r.Counts.Total
			models = append(models, r.Model)
		}
		if total != tc.want {
			t.Errorf("%s: total = %d, want %d", tc.name, total, tc.want)
		}
		if len(models) != len(tc.models) {
			t.Errorf("%s: models = %v, want %v", tc.name, models, tc.models)
			continue
		}
		for i := range models {
			if models[i] != tc.models[i] {
				t.Errorf("%s: models = %v, want %v", tc.name, models, tc.models)
				break
			}
		}
	}
}
