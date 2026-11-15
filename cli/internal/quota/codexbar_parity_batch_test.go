// SPDX-License-Identifier: MIT
package quota

import (
	"encoding/json"
	"testing"
	"time"
)

// CodexBar a96e58f30 (behaviour only): a Claude plan that reports no measured five-hour window is
// weekly-only. Its session window stays absent, judged by the response shape, and the weekly and
// model windows that are measured are kept. An entry without utilization is absent, not a broken
// payload, so it cannot hide valid windows next to it.
func TestClaudeWeeklyOnlyKeepsSessionAbsent(t *testing.T) {
	for _, tc := range []struct {
		name, body string
		want       []string // kind/limit of each window, in order
	}{
		{"five_hour null", `{"five_hour":null,"seven_day":{"utilization":42},"seven_day_opus":{"utilization":17}}`, []string{"weekly/", "weekly/Opus"}},
		{"five_hour missing", `{"seven_day":{"utilization":42}}`, []string{"weekly/"}},
		{"five_hour without utilization", `{"five_hour":{"resets_at":"2026-10-27T16:00:00Z"},"seven_day":{"utilization":42,"resets_at":"2026-10-30T00:00:00Z"}}`, []string{"weekly/"}},
		{"five_hour utilization null", `{"five_hour":{"utilization":null,"resets_at":null},"seven_day":{"utilization":42}}`, []string{"weekly/"}},
		{"sonnet without utilization keeps opus", `{"five_hour":null,"seven_day":{"utilization":5},"seven_day_sonnet":{"resets_at":null},"seven_day_opus":{"utilization":60}}`, []string{"weekly/", "weekly/Opus"}},
		{"session measured", `{"five_hour":{"utilization":12},"seven_day":{"utilization":42}}`, []string{"five_hour/", "weekly/"}},
	} {
		var raw map[string]json.RawMessage
		if err := json.Unmarshal([]byte(tc.body), &raw); err != nil {
			t.Fatal(err)
		}
		ws, ok := parseClaudeUsage(raw, claudeTestNow)
		if !ok {
			t.Errorf("%s: payload rejected", tc.name)
			continue
		}
		var got []string
		for _, w := range ws {
			got = append(got, w.Kind+"/"+w.Limit)
		}
		if len(got) != len(tc.want) {
			t.Errorf("%s: windows = %v, want %v", tc.name, got, tc.want)
			continue
		}
		for i := range got {
			if got[i] != tc.want[i] {
				t.Errorf("%s: windows = %v, want %v", tc.name, got, tc.want)
				break
			}
		}
	}
	// A present but malformed utilization still fails closed.
	for _, body := range []string{`{"five_hour":{"utilization":"12"}}`, `{"seven_day":{"utilization":-1}}`} {
		var raw map[string]json.RawMessage
		_ = json.Unmarshal([]byte(body), &raw)
		if _, ok := parseClaudeUsage(raw, claudeTestNow); ok {
			t.Errorf("%s: malformed utilization accepted", body)
		}
	}
}

// The status-line route follows the same rule: a five_hour object without a percentage is no
// session window.
func TestClaudeStatuslineWeeklyOnly(t *testing.T) {
	for _, tc := range []struct {
		body  string
		kinds string
	}{
		{`{"rate_limits":{"seven_day":{"used_percentage":30,"resets_at":1793000000}}}`, "weekly"},
		{`{"rate_limits":{"five_hour":{"resets_at":1793000000},"seven_day":{"used_percentage":30}}}`, "weekly"},
		{`{"rate_limits":{"five_hour":{"used_percentage":null},"seven_day":{"used_percentage":30}}}`, "weekly"},
		{`{"rate_limits":{"five_hour":{"used_percentage":5},"seven_day":{"used_percentage":30}}}`, "five_hour,weekly"},
	} {
		var in StatuslineInput
		if err := json.Unmarshal([]byte(tc.body), &in); err != nil {
			t.Fatal(err)
		}
		got := ""
		for i, w := range in.Account(claudeTestNow).Windows {
			if i > 0 {
				got += ","
			}
			got += w.Kind
		}
		if got != tc.kinds {
			t.Errorf("%s: kinds = %q, want %q", tc.body, got, tc.kinds)
		}
	}
}

// CodexBar 1ebab5e46: the Kiro reader passes "KIRO PRO+" on with its plus (rows shows it as
// "Kiro Pro+"). CodexBar 929c4fe2d recovers usage when the CLI store has no saved profile; this
// reader never opens that store (nor the keychain): it asks the signed-in kiro-cli over ACP, so a
// missing profile cannot block it. The reply below carries no profile at all.
func TestKiroPlanPlusAndNoProfile(t *testing.T) {
	now := time.Date(2026, 10, 31, 12, 0, 0, 0, time.UTC)
	e := parseKiro(json.RawMessage(`{"success":true,"data":{"planName":"KIRO PRO+","billingCycleReset":"2026-11-01","usageBreakdowns":[{"resourceType":"CREDIT","displayName":"Credits","used":500,"limit":2000,"hasLimit":true}]}}`), now)
	if e.Status != "ok" || e.Plan != "KIRO PRO+" || len(e.Windows) != 1 || *e.Windows[0].UsedPercent != 25 {
		t.Fatalf("entry = %+v", e)
	}
}
