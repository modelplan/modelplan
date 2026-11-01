// SPDX-License-Identifier: MIT
package quota

import (
	"encoding/json"
	"reflect"
	"testing"
	"time"
)

func TestProviderModelScopeAndManagedCache(t *testing.T) {
	now := time.Date(2026, 10, 1, 0, 0, 0, 0, time.UTC)
	var raw map[string]json.RawMessage
	if err := json.Unmarshal([]byte(`{"seven_day":{"utilization":20},"seven_day_opus":{"utilization":90},"seven_day_sonnet":{"utilization":30}}`), &raw); err != nil {
		t.Fatal(err)
	}
	ws, ok := parseClaudeUsage(raw, now)
	if !ok || len(ws) != 3 || !ws[0].ScopeKnown || ws[0].ModelIDs != nil || !reflect.DeepEqual(ws[1].ModelIDs, []string{"opus"}) || !reflect.DeepEqual(ws[2].ModelIDs, []string{"sonnet"}) {
		t.Fatalf("Claude scope: %+v", ws)
	}
	data, err := json.Marshal(ws)
	if err != nil {
		t.Fatal(err)
	}
	var cached []Window
	if err = json.Unmarshal(data, &cached); err != nil {
		t.Fatal(err)
	}
	cached = append(cached, Window{Kind: "weekly"})
	account := Account{Windows: cached}
	got := managedRowsAccount("claude", "profile", &account, t.TempDir(), now, false)
	if len(got.Windows) != 3 || !reflect.DeepEqual(got.Windows[1].ModelIDs, []string{"opus"}) {
		t.Fatalf("managed cache scope: %+v", got.Windows)
	}
	var q geminiQuota
	if err = json.Unmarshal([]byte(`{"buckets":[{"modelId":"gemini-2.5-pro","remainingFraction":0.5}]}`), &q); err != nil {
		t.Fatal(err)
	}
	gem, ok := parseGeminiQuota(q, now)
	if !ok || len(gem) != 1 || !gem[0].ScopeKnown || !reflect.DeepEqual(gem[0].ModelIDs, []string{"gemini-2.5-pro"}) {
		t.Fatalf("Gemini scope: %+v", gem)
	}
}

func TestGeminiModelScopeNeverExportsUnreviewedIDs(t *testing.T) {
	now := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	var q geminiQuota
	if err := json.Unmarshal([]byte(`{"buckets":[{"modelId":"synthetic-token-shaped-secret","remainingFraction":0.5},{"modelId":"gemini-2.5-pro","remainingFraction":0.8}]}`), &q); err != nil {
		t.Fatal(err)
	}
	windows, ok := parseGeminiQuota(q, now)
	if !ok || len(windows) != 2 {
		t.Fatal("synthetic quota rejected")
	}
	if !reflect.DeepEqual(windows[0].ModelIDs, []string{"unknown"}) || !reflect.DeepEqual(windows[1].ModelIDs, []string{"gemini-2.5-pro"}) {
		t.Fatalf("scope normalization: %+v", windows)
	}
	// A cache from an older writer can still contain an unreviewed value.
	legacy := windows[0]
	legacy.ModelIDs = []string{"synthetic-token-shaped-secret"}
	encoded, err := json.Marshal(legacy)
	if err != nil {
		t.Fatal(err)
	}
	var fields map[string]json.RawMessage
	if err = json.Unmarshal(encoded, &fields); err != nil {
		t.Fatal(err)
	}
	if string(fields["modelIds"]) != `["unknown"]` {
		t.Fatalf("unsafe scope output: %s", fields["modelIds"])
	}
}
