// SPDX-License-Identifier: MIT
package localusage

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
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

func grokHistoryTotal(t *testing.T, r HistoryResult) int64 {
	t.Helper()
	var total int64
	for _, row := range r.Rows {
		if row.Total != nil {
			total += *row.Total
		}
	}
	return total
}

// Review macrev2-968-1 / glm-968-1: Grok history decoded before the per-turn rules keeps its old
// rows for files that never change. The first refresh after the upgrade re-reads every Grok file
// once with the new rules and replaces that file's old rows; later refreshes skip unchanged files
// again. A fresh cache is the positive control.
func TestGrokHistoryUpgradeRereadsOldDecoderRowsOnce(t *testing.T) {
	a := historyTestAccess(t)
	usage := `{"turns":[{"turnNumber":1,"endedAt":"2026-10-23T10:00:00Z","totalTokens":900,"primaryModelId":"grok-a","modelUsage":{"grok-a":{"totalTokens":900},"grok-b":{"totalTokens":900}}}]}`
	setup := func() (string, string) {
		root, cache := t.TempDir(), t.TempDir()
		fixtureFile(t, filepath.Join(root, "project/session/summary.json"), `{"info":{},"created_at":"2026-10-23T09:00:00Z","num_messages":1}`)
		fixtureFile(t, filepath.Join(root, "project/session/usage.json"), usage)
		return root, cache
	}

	root, cache := setup()
	if r := RefreshHistory(context.Background(), "grok", root, cache, a, testNow); grokHistoryTotal(t, r) != 900 {
		t.Fatalf("fresh cache total = %d, want 900", grokHistoryTotal(t, r))
	}

	// Rewrite the stored state as the old decoder left it: one row per model subtotal (1,800 for a
	// 900-token turn) and no decoder version. The source file stays byte-for-byte the same.
	root, cache = setup()
	RefreshHistory(context.Background(), "grok", root, cache, a, testNow)
	path := historyPath(cache, "grok", a)
	var state map[string]json.RawMessage
	b, err := os.ReadFile(path)
	if err != nil || json.Unmarshal(b, &state) != nil {
		t.Fatal("no stored grok history", err)
	}
	delete(state, "grokDecoder")
	var entries map[string]historyStored
	if err := json.Unmarshal(state["entries"], &entries); err != nil || len(entries) != 1 {
		t.Fatal("stored entries", err, len(entries))
	}
	for id, e := range entries {
		e.Model = "grok-b"
		entries = map[string]historyStored{id: entries[id], id + "-old-decoder": e}
		break
	}
	state["entries"], _ = json.Marshal(entries)
	b, _ = json.Marshal(state)
	if err := os.WriteFile(path, b, 0o600); err != nil {
		t.Fatal(err)
	}
	if r := ReadHistoryCache(cache, "grok", a, testNow.Add(time.Minute)); grokHistoryTotal(t, r) != 1800 {
		t.Fatalf("old-decoder seed total = %d, want 1800", grokHistoryTotal(t, r))
	}

	upgraded := RefreshHistory(context.Background(), "grok", root, cache, a, testNow.Add(5*time.Minute))
	if got := grokHistoryTotal(t, upgraded); got != 900 || upgraded.BytesRead == 0 {
		t.Fatalf("after upgrade total = %d (bytesRead %d), want 900 from a re-read", got, upgraded.BytesRead)
	}
	again := RefreshHistory(context.Background(), "grok", root, cache, a, testNow.Add(10*time.Minute))
	if got := grokHistoryTotal(t, again); got != 900 || again.BytesRead != 0 {
		t.Fatalf("second refresh total = %d (bytesRead %d), want 900 without a re-read", got, again.BytesRead)
	}
}
