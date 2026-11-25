// SPDX-License-Identifier: MIT
package rows

import "testing"

// D417: an extra window carries a short label naming what it is, never the generic "Other limit",
// and that label stays within the 6-character budget both surfaces show in full.
func TestExtraWindowLabelsNameTheWindow(t *testing.T) {
	cases := []struct {
		name  string
		limit string
		model []string
		key   string
		label string
	}{
		{"zcode mcp", "MCP", nil, "mcp", "MCP"},
		{"claude opus weekly", "Opus", []string{"opus"}, "other", "Opus"},
		{"claude sonnet weekly", "Sonnet", []string{"sonnet"}, "other", "Sonnet"},
		{"fable has no reviewed scope id yet", "Fable", []string{"fable"}, "other", "Other limit"},
		{"gemini flash", "x", []string{"gemini-2.5-flash"}, "other", "Flash"},
		{"unknown stays generic", "Cowork", nil, "other", "Other limit"},
		{"unknown scope stays generic", "x", []string{"unknown"}, "other", "Other limit"},
	}
	for _, c := range cases {
		in := sampleInput()
		w := in.Accounts[0].Windows[0]
		w.Kind, w.Limit, w.ModelIDs = "monthly", c.limit, c.model
		in.Accounts[0].Windows = append(in.Accounts[0].Windows, w)
		got := Build(in)
		if err := Validate(in, got); err != nil {
			t.Fatalf("%s: %v", c.name, err)
		}
		ws := rowByID(t, got, "codex").Accounts[0].Windows
		var found *Window
		for i := range ws {
			if ws[i].Role == RoleMonthly {
				found = &ws[i]
			}
		}
		if found == nil || found.LimitKey != c.key || found.Label.EN != c.label || found.Label.ZH != c.label && c.label != "Other limit" {
			t.Fatalf("%s: %+v", c.name, found)
		}
		if c.label != "Other limit" && len([]rune(found.Label.EN)) > 6 {
			t.Fatalf("%s: label %q exceeds 6 characters", c.name, found.Label.EN)
		}
	}
}
