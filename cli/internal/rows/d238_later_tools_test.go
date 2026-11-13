// SPDX-License-Identifier: MIT
package rows

import "testing"

// D238: a tool installed after the first run that the user has not decided on is offered in
// the status menu as detected-not-enabled (reason consent_required, next step: open Settings to
// enable). No reader runs and no values are exported; it has no Dock ring (G3-38, owner D76).
func TestD238ToolInstalledLaterIsOfferedInTheMenuWithoutValues(t *testing.T) {
	in := sampleInput()
	in.Catalogue = append(in.Catalogue, CatalogueEntry{ToolID: "cursor", Detected: true, ReaderExists: true, InstalledLater: true})
	out := Build(in)
	if err := Validate(in, out); err != nil {
		t.Fatal(err)
	}
	row := rowByID(t, out, "cursor")
	if row.Consent != ConsentUnset || row.State != StateNeedsConsent || row.Reason.Code != CodeConsentRequired ||
		row.NextStep == nil || row.NextStep.Action != ActionOpenSettingsConsent {
		t.Fatalf("offer row: %+v", row)
	}
	if !hasSurface(row, SurfaceMenu) || !hasSurface(row, SurfaceSettings) || hasSurface(row, SurfaceDock) {
		t.Fatalf("offer surfaces: %v", row.Surfaces)
	}
	if len(row.Accounts) != 0 {
		t.Fatalf("an undecided tool exported values: %+v", row.Accounts)
	}
	if codex := rowByID(t, out, "codex"); !hasSurface(codex, SurfaceDock) {
		t.Fatal("the readable tool lost its ring")
	}
}

// The offer is only for an undecided, detected, readable tool installed after the baseline.
// A first-run tool left unset, a denied tool, an uninstalled tool and a tool without a reader
// keep today's Settings-only (or no) row.
func TestD238NoOfferOutsideTheInstalledLaterUndecidedCase(t *testing.T) {
	cases := map[string]func(in *Input){
		"baseline tool": func(in *Input) { in.Catalogue[1].InstalledLater = false },
		"denied": func(in *Input) {
			in.Consents = append(in.Consents, ConsentRecord{ToolID: "cursor", Generation: 7, State: ConsentDenied})
		},
		"uninstalled":  func(in *Input) { in.Catalogue[1].Detected = false },
		"no reader":    func(in *Input) { in.Catalogue[1].ReaderExists = false },
		"privacy veto": func(in *Input) { in.PrivacyBlocked = true },
		"admission veto": func(in *Input) {
			in.Admissions = append(in.Admissions, Admission{ToolID: "cursor", Veto: "codexbar-not-audited"})
		},
	}
	for name, change := range cases {
		in := sampleInput()
		in.Catalogue = append(in.Catalogue, CatalogueEntry{ToolID: "cursor", Detected: true, ReaderExists: true, InstalledLater: true})
		change(&in)
		out := Build(in)
		if err := Validate(in, out); err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		for _, row := range out.Rows {
			if row.ID == "cursor" && (hasSurface(row, SurfaceMenu) || hasSurface(row, SurfaceDock)) {
				t.Errorf("%s: offered anyway: %+v", name, row)
			}
		}
	}
}
