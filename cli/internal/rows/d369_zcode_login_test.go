// SPDX-License-Identifier: MIT
package rows

import "testing"

// D369: ZCode's QR-code sign-in. A detected sign-in whose own scope is off shows the consent state
// with the Settings action and no numbers; an ended sign-in asks to sign in to ZCode again.
func TestD369ZCodeLoginRowStates(t *testing.T) {
	for _, c := range []struct {
		word   string
		code   Code
		state  State
		action Action
	}{
		{"consent_required", CodeConsentRequired, StateNeedsConsent, ActionOpenSettingsConsent},
		{"login_expired", CodeLoginExpired, StateNeedsAction, ActionOpenTool},
	} {
		in := sampleInput()
		in.Catalogue = append(in.Catalogue, CatalogueEntry{ToolID: "zai", Detected: true, ReaderExists: true})
		in.Consents = append(in.Consents, ConsentRecord{ToolID: "zai", Generation: 7, State: ConsentImplicit})
		in.Sources = append(in.Sources, SourceState{ToolID: "zai", Source: "native:zai", Status: "unavailable", ErrorCode: c.word})
		out := Build(in)
		if err := Validate(in, out); err != nil {
			t.Fatalf("%s: %v", c.word, err)
		}
		row := rowByID(t, out, "zai")
		if row.State != c.state || row.Reason.Code != c.code || row.NextStep == nil || row.NextStep.Action != c.action {
			t.Fatalf("%s: state=%s code=%s next=%+v", c.word, row.State, row.Reason.Code, row.NextStep)
		}
		if row.NextStep.Text.EN == actionTexts[c.action].EN || row.NextStep.Text.ZH == "" {
			t.Fatalf("%s: generic next step %+v", c.word, row.NextStep.Text)
		}
		if len(row.Accounts) != 0 {
			t.Fatalf("%s: numbers shown: %+v", c.word, row.Accounts)
		}
	}
}
