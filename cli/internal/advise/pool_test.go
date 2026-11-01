package advise

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestDecidingWindowIsThePools(t *testing.T) {
	main, reserve := 30.0, 95.0
	a := &quota.Account{Source: "codex", Deciding: "weekly", Windows: []quota.Window{
		{Kind: "weekly", Limit: "reserve", UsedPercent: &reserve},
		{Kind: "weekly", UsedPercent: &main},
	}}
	if w := deciding(a); w == nil || w.Limit != "" {
		t.Fatalf("main pool: deciding = %+v", w)
	}
	a.Pool = "reserve"
	if w := deciding(a); w == nil || w.Limit != "reserve" {
		t.Fatalf("reserve pool: deciding = %+v", w)
	}
}

func TestHintsNameTheirAllowance(t *testing.T) {
	reserve, main := 99.0, 30.0
	a := &quota.Account{Source: "codex", Plan: "plus", Pool: "reserve", Headroom: "exhausted", Deciding: "weekly", Windows: []quota.Window{
		{Kind: "weekly", UsedPercent: &main},
		{Kind: "weekly", Limit: "reserve", UsedPercent: &reserve},
	}}
	if w := deciding(a); w == nil || w.Limit != "reserve" {
		t.Fatalf("deciding = %+v", w)
	}
	es := accountEvents(a, nil, time.Date(2026, 10, 17, 12, 0, 0, 0, time.UTC), nil)
	if len(es) == 0 {
		t.Fatal("an exhausted Reserve gives a hint")
	}
	for _, e := range es {
		if e.Limit != "reserve" {
			t.Errorf("event %s about %q, want reserve", e.Type, e.Limit)
		}
	}
}

func TestLegacyGeminiLabelIsSanitizedInAdviceAndKey(t *testing.T) {
	for _, tc := range []struct{ source, label, want string }{
		{"native:gemini", "synthetic-token-shaped-secret requests", "unknown requests"},
		{"native:gemini", "gemini-2.5-pro requests", "gemini-2.5-pro requests"},
		{"codex", "reserve", "reserve"},
	} {
		// This models an old cache decoded before Gemini labels were sanitized.
		data, _ := json.Marshal(map[string]any{"source": tc.source, "headroom": "exhausted", "deciding": "unknown", "windows": []any{map[string]any{"kind": "unknown", "limit": tc.label}}})
		var a quota.Account
		if err := json.Unmarshal(data, &a); err != nil {
			t.Fatal(err)
		}
		events := accountEvents(&a, nil, time.Now(), nil)
		if len(events) != 1 {
			t.Fatalf("%s: events = %+v", tc.source, events)
		}
		if events[0].Limit != tc.want || !strings.Contains(events[0].Key, "|"+tc.want+"|") {
			t.Fatalf("%s: event limit/key = %q / %q", tc.source, events[0].Limit, events[0].Key)
		}
		encoded, err := json.Marshal(events)
		if err != nil {
			t.Fatal(err)
		}
		if tc.source == "native:gemini" && strings.Contains(string(encoded), "synthetic-token-shaped-secret") {
			t.Fatal("raw legacy label in advice JSON")
		}
		if tc.source == "native:gemini" {
			actual := Derive(Input{Report: quota.Report{Accounts: []quota.Account{a}}, Now: time.Now()})
			if len(actual) != 0 {
				t.Fatalf("native account unexpectedly eligible for advice: %+v", actual)
			}
		}
	}
}

func TestGeminiScopedWindowsHaveDistinctAdviceKeys(t *testing.T) {
	labels := []string{"unknown-0000000000000001 requests", "gemini-2.5-pro requests", "unknown-0000000000000002 requests", "unknown-0000000000000003 requests"}
	a := quota.Account{Source: "native:gemini"}
	for _, label := range labels {
		a.Windows = append(a.Windows, quota.Window{Kind: "unknown", Limit: label, ScopeKnown: true})
	}
	seen := map[string]bool{}
	for i := range a.Windows {
		key := windowKey(WindowTight, &a, &a.Windows[i])
		if seen[key] || !strings.Contains(key, "|"+labels[i]+"|") {
			t.Fatalf("collapsed Gemini advice key: %q", key)
		}
		seen[key] = true
	}
}
