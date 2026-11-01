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
