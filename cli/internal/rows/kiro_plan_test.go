// SPDX-License-Identifier: MIT
package rows

import "testing"

// CodexBar 1ebab5e46 (behaviour only): Kiro CLI plan names keep their plus. "KIRO PRO+" is shown
// as "Kiro Pro+" and is told apart from "Kiro Pro" in both the plan id and the label.
func TestKiroPlanKeepsPlus(t *testing.T) {
	for _, tc := range []struct{ raw, id, name string }{
		{"KIRO PRO+", "kiro-pro+", "Kiro Pro+"},
		{" KIRO PRO+ ", "kiro-pro+", "Kiro Pro+"},
		{"KIRO PRO", "kiro-pro", "Kiro Pro"},
		{"KIRO FREE", "kiro-free", "Kiro Free"},
		{"KIRO POWER", "kiro-power", "Kiro Power"},
		{"Kiro Pro+", "kiro-pro+", "Kiro Pro+"},
	} {
		p := planValue("kiro", tc.raw, "")
		if p.ID != tc.id || p.Name == nil || p.Name.EN != tc.name || p.Name.ZH != tc.name {
			t.Errorf("%q: plan = %+v", tc.raw, p)
		}
		if got := PlanLabel("native:kiro", tc.raw); got != tc.name {
			t.Errorf("%q: label = %q, want %q", tc.raw, got, tc.name)
		}
	}
	// Unknown Kiro words are not invented into plan ids, and other tools are untouched.
	if p := planValue("kiro", "KIRO SOMETHING", ""); p.ID != "unknown" {
		t.Errorf("unknown kiro plan = %+v", p)
	}
	if got := PlanLabel("native:kiro", "KIRO SOMETHING"); got != "KIRO SOMETHING" {
		t.Errorf("unknown kiro label = %q", got)
	}
	if p := planValue("cursor", "KIRO PRO+", ""); p.ID != "unknown" {
		t.Errorf("cursor took a kiro plan: %+v", p)
	}
}
