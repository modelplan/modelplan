// SPDX-License-Identifier: MIT
package rows

import "testing"

// Codex reports its Pro tiers as plan ids (prolite, pro, promax). Its own status view and the plan
// catalogue name them by monthly price; the rows carry that name and keep the id for matching.
func TestCodexProTiersAreNamedByPrice(t *testing.T) {
	for raw, want := range map[string][2]string{
		"prolite": {"prolite", "Pro 100"}, "pro_lite": {"prolite", "Pro 100"}, "pro": {"pro", "Pro 200"},
		"promax": {"promax", "Pro 500"}, "Pro-Max": {"promax", "Pro 500"},
	} {
		in := sampleInput()
		in.Accounts[0].PlanID = raw
		out := Build(in)
		if err := Validate(in, out); err != nil {
			t.Fatalf("%s: %v", raw, err)
		}
		p := rowByID(t, out, "codex").Accounts[0].Plan
		if p.ID != want[0] || p.Name == nil || p.Name.EN != want[1] || p.Name.ZH != want[1] {
			t.Errorf("%s -> %+v %+v; want %v", raw, p, p.Name, want)
		}
		if got := PlanLabel("codex", raw); got != want[1] {
			t.Errorf("label %s -> %q", raw, got)
		}
	}
	// Another tool's "pro" keeps its own name, and other plan text stays as the reader gave it.
	if got := planValue("claude", "pro", ""); got.Name == nil || got.Name.EN != "Pro" {
		t.Errorf("claude pro -> %+v", got)
	}
	if got := PlanLabel("claude", "pro"); got != "pro" {
		t.Errorf("claude label %q", got)
	}
	if got := PlanLabel("zai", "GLM Coding Plan"); got != "GLM Coding Plan" {
		t.Errorf("label %q", got)
	}
}
