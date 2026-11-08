// SPDX-License-Identifier: MIT
package rows

import (
	"testing"
	"time"
)

func hasSurface(r Row, s Surface) bool {
	for _, x := range r.Surfaces {
		if x == s {
			return true
		}
	}
	return false
}

// G3-38 (owner decision D76): a detected subscription that cannot be read has no Dock ring, for
// every unreadable reason. First run, Settings and the menu keep listing it with its reason.
// One synthetic profile: Codex readable, Claude Code and ZCode unreadable for the same reason.
func TestG338UnreadableToolsHaveNoDockRing(t *testing.T) {
	type unreadable func(in *Input, id string)
	failed := func(code string) unreadable {
		return func(in *Input, id string) {
			in.Profiles = append(in.Profiles, ProfileState{ToolID: id, ProfileKey: id + "-p", LatestAttempt: AttemptResultFailed,
				AttemptedAt: ptr(testNow), LastFailure: &FailureInput{Code: code, At: ptr(testNow)}})
		}
	}
	cases := map[string]unreadable{
		"login_expired":     failed("expired"),
		"unsupported_login": failed("unsupported_login"),
		"parse_error":       failed("parse_error"),
		"runtime_missing":   failed("runtime_missing"),
		"http_401":          failed("http_401"),
		"keychain_denied": func(in *Input, id string) {
			in.KeychainBlocks = append(in.KeychainBlocks, KeychainBlock{ToolID: id, Blocked: true, Status: "denied"})
		},
		"keychain_unset": func(in *Input, id string) {
			in.KeychainBlocks = append(in.KeychainBlocks, KeychainBlock{ToolID: id, Blocked: true, Status: "consent-required"})
		},
		"admission_veto": func(in *Input, id string) {
			in.Admissions = append(in.Admissions, Admission{ToolID: id, Veto: "codexbar-not-audited"})
		},
		"no_reader":      func(in *Input, id string) { setReader(in, id, true, false) },
		"tool_not_found": func(in *Input, id string) { setReader(in, id, false, false) },
		"consent_unset": func(in *Input, id string) {
			for i := range in.Consents {
				if in.Consents[i].ToolID == id {
					in.Consents[i].State = ConsentUnset
				}
			}
		},
	}
	for name, make := range cases {
		in := sampleInput() // Codex: readable, fresh
		for _, id := range []string{"claude", "zai"} {
			in.Catalogue = append(in.Catalogue, CatalogueEntry{ToolID: id, Detected: true, ReaderExists: true})
			in.Consents = append(in.Consents, ConsentRecord{ToolID: id, Generation: 7, State: ConsentAllowed})
			make(&in, id)
		}
		out := Build(in)
		if err := Validate(in, out); err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		if codex := rowByID(t, out, "codex"); !hasSurface(codex, SurfaceDock) {
			t.Fatalf("%s: the readable tool lost its ring", name)
		}
		for _, id := range []string{"claude", "zai"} {
			row := rowByID(t, out, id)
			if row.State == StatePending {
				continue // the reason does not apply to this tool; a first read is under way
			}
			if hasSurface(row, SurfaceDock) {
				t.Errorf("%s: unreadable %s keeps a Dock ring (state %s, code %s)", name, id, row.State, row.Reason.Code)
			}
			if !hasSurface(row, SurfaceSettings) || row.Reason.Code == CodeOK || row.Reason.Text.EN == "" {
				t.Errorf("%s: %s lost its Settings listing or reason: %+v", name, id, row)
			}
			if row.Consent != ConsentUnset && !hasSurface(row, SurfaceMenu) {
				t.Errorf("%s: %s left the menu", name, id)
			}
		}
	}
}

func setReader(in *Input, id string, detected, reader bool) {
	for i := range in.Catalogue {
		if in.Catalogue[i].ToolID == id {
			in.Catalogue[i].Detected, in.Catalogue[i].ReaderExists = detected, reader
		}
	}
}

// The other side of G3-38: rows that are not unreadable keep their ring.
func TestG338RowsThatAreNotUnreadableKeepTheirRing(t *testing.T) {
	failedWithReading := Input{Catalogue: []CatalogueEntry{oracleTool("cursor", true)}, Consents: oracleAllowed("cursor"),
		Profiles: []ProfileState{{ToolID: "cursor", ProfileKey: "u1", LatestAttempt: AttemptResultFailed, AttemptedAt: oracleTime(-time.Minute),
			ObservedAt: oracleTime(-10 * time.Minute), WithinFreshness: true, FreshUntil: oracleTime(time.Hour),
			LastFailure: &FailureInput{Code: "network", At: oracleTime(-time.Minute)}}},
		Accounts: []AccountInput{oracleAccount("cursor", "u1", oracleWindow())}}
	stale := Input{Catalogue: []CatalogueEntry{oracleTool("kimi", true)}, Consents: oracleAllowed("kimi"),
		Profiles: []ProfileState{{ToolID: "kimi", ProfileKey: "k1", LatestAttempt: AttemptResultSucceeded, AttemptedAt: oracleTime(-5 * time.Hour),
			ObservedAt: oracleTime(-5 * time.Hour), WithinFreshness: false, FreshUntil: oracleTime(-time.Hour)}},
		Accounts: []AccountInput{oracleAccount("kimi", "k1", oracleWindow())}}
	for _, tc := range []struct {
		name string
		in   Input
		row  string
	}{
		{"pending first read", Input{Catalogue: []CatalogueEntry{oracleTool("gemini", true)}, Consents: oracleAllowed("gemini")}, "gemini"},
		{"failed read that kept a reading", failedWithReading, "cursor"},
		{"stale reading", stale, "kimi"},
		{"manual plan", Input{DeclaredPlanIDs: []string{"team-plan"}}, "declared:team-plan"},
	} {
		in := tc.in
		in.Now, in.ConsentGeneration = oracleNow, 7
		out := Build(in)
		if err := Validate(in, out); err != nil {
			t.Fatalf("%s: %v", tc.name, err)
		}
		row := oracleRow(t, out, tc.row)
		if row == nil || !oracleHas(row, SurfaceDock) {
			t.Errorf("%s: lost its ring: %+v", tc.name, row)
		}
	}
}
