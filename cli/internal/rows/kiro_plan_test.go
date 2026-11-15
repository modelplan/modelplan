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

// Review macrev2-968-2 / glm-968-2: every Kiro tier id the projector emits passes the validator.
func TestKiroPlanIDsRoundTripThroughValidate(t *testing.T) {
	for _, raw := range []string{"KIRO FREE", "KIRO PRO", "KIRO PRO+", "KIRO POWER"} {
		in := sampleInput()
		in.Catalogue[0].ToolID, in.Consents[0].ToolID, in.Profiles[0].ToolID = "kiro", "kiro", "kiro"
		in.Accounts[0].ToolID, in.Accounts[0].PlanID = "kiro", raw
		out := Build(in)
		if err := Validate(in, out); err != nil {
			t.Errorf("%s: %v", raw, err)
		}
		id, name, _ := kiroPlan(raw)
		if p := rowByID(t, out, "kiro").Accounts[0].Plan; p.ID != id || p.Name == nil || p.Name.EN != name {
			t.Errorf("%s: plan = %+v", raw, p)
		}
	}
}
