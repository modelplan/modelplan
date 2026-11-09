// SPDX-License-Identifier: MIT
package rows

import (
	"testing"
	"time"
)

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

// The walkthrough defect: a tool still waiting on its first read (pending, nothing read yet) has no
// ring either, from the first frame; it still has its Settings and menu listing with the reason.
func TestG338WaitingForFirstReadHasNoRingFromTheStart(t *testing.T) {
	in := Input{Catalogue: []CatalogueEntry{oracleTool("gemini", true), oracleTool("claude", true)},
		Consents: append(oracleAllowed("gemini"), oracleAllowed("claude")...), Now: oracleNow, ConsentGeneration: 7}
	out := Build(in)
	if err := Validate(in, out); err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{"gemini", "claude"} {
		row := oracleRow(t, out, id)
		if row == nil || row.State != StatePending || oracleHas(row, SurfaceDock) || !oracleHas(row, SurfaceSettings) || !oracleHas(row, SurfaceMenu) {
			t.Errorf("%s: want pending, listed, no ring: %+v", id, row)
		}
	}
}

// Normal entry, D-13: launch with an unreadable Gemini (login unsupported) and a Claude Code that
// has not finished its first read. Neither shows a ring at t=0 or after the first read fails; both
// stay listed with their reason. The readable Codex keeps its ring throughout.
func TestG338LaunchWalkNeitherUnreadableToolEverHasARing(t *testing.T) {
	launch := func(at time.Time, profiles ...ProfileState) Input {
		in := sampleInput()
		in.Now = at
		for _, id := range []string{"gemini", "claude"} {
			in.Catalogue = append(in.Catalogue, CatalogueEntry{ToolID: id, Detected: true, ReaderExists: true})
			in.Consents = append(in.Consents, ConsentRecord{ToolID: id, Generation: 7, State: ConsentAllowed})
		}
		in.Profiles = append(in.Profiles, profiles...)
		return in
	}
	check := func(label string, in Input, reasons map[string]Code) {
		out := Build(in)
		if err := Validate(in, out); err != nil {
			t.Fatalf("%s: %v", label, err)
		}
		if !hasSurface(rowByID(t, out, "codex"), SurfaceDock) {
			t.Errorf("%s: the readable tool lost its ring", label)
		}
		for id, code := range reasons {
			row := rowByID(t, out, id)
			if hasSurface(row, SurfaceDock) || !hasSurface(row, SurfaceSettings) || !hasSurface(row, SurfaceMenu) {
				t.Errorf("%s: %s surfaces %v, want menu+settings only", label, id, row.Surfaces)
			}
			if row.Reason.Code != code || row.Reason.Text.EN == "" {
				t.Errorf("%s: %s reason %s, want %s", label, id, row.Reason.Code, code)
			}
		}
	}
	check("t=0", launch(testNow), map[string]Code{"gemini": CodeNotReadYet, "claude": CodeNotReadYet})
	fail := func(id, code string) ProfileState {
		return ProfileState{ToolID: id, ProfileKey: id + "-p", LatestAttempt: AttemptResultFailed, AttemptedAt: ptr(testNow),
			LastFailure: &FailureInput{Code: code, At: ptr(testNow)}}
	}
	check("after first read", launch(testNow.Add(time.Minute), fail("gemini", "unsupported_login"), fail("claude", "expired")),
		map[string]Code{"gemini": CodeUnsupportedLogin, "claude": CodeLoginExpired})
}

// G3-38: with every tool off the Dock, the Dock summary says what is going on. It never claims
// there are no readings while a first read is under way, and it names the user action otherwise.
func TestG338DockSummaryForToolsWithoutARing(t *testing.T) {
	add := func(in *Input, id string, make func(in *Input, id string)) {
		in.Catalogue = append(in.Catalogue, CatalogueEntry{ToolID: id, Detected: true, ReaderExists: true})
		in.Consents = append(in.Consents, ConsentRecord{ToolID: id, Generation: 7, State: ConsentAllowed})
		if make != nil {
			make(in, id)
		}
	}
	build := func(in Input) Projection {
		out := Build(in)
		if err := Validate(in, out); err != nil {
			t.Fatal(err)
		}
		return out
	}
	t.Run("pending only", func(t *testing.T) {
		in := Input{Now: testNow, ConsentGeneration: 7}
		add(&in, "claude", nil)
		add(&in, "zai", nil)
		s := build(in).RowsSummary
		if s.State != SummaryStatePending || s.Reason.Code != CodeNotReadYet || s.NextStep != nil {
			t.Fatalf("%+v", s)
		}
		if s.Text.EN == "" || s.Text.EN[:8] != "Reading " || s.Text.ZH[:len("正在读取 ")] != "正在读取 " {
			t.Fatalf("%+v", s.Text)
		}
	})
	t.Run("action needed", func(t *testing.T) {
		in := Input{Now: testNow, ConsentGeneration: 7}
		add(&in, "claude", func(in *Input, id string) {
			in.KeychainBlocks = append(in.KeychainBlocks, KeychainBlock{ToolID: id, Blocked: true, Status: "denied"})
		})
		s := build(in).RowsSummary
		if s.State != SummaryStateEmpty || s.Reason.Code == CodeNoDockRows || s.NextStep == nil || s.NextStep.Action != ActionOpenSettingsKeychain {
			t.Fatalf("%+v", s)
		}
		if s.Text.EN == summaryTexts[CodeNoDockRows].EN {
			t.Fatalf("names no action: %+v", s.Text)
		}
	})
	t.Run("sign in needed", func(t *testing.T) {
		in := Input{Now: testNow, ConsentGeneration: 7}
		add(&in, "claude", func(in *Input, id string) {
			in.Profiles = append(in.Profiles, ProfileState{ToolID: id, ProfileKey: id + "-p", LatestAttempt: AttemptResultFailed,
				AttemptedAt: ptr(testNow), LastFailure: &FailureInput{Code: "expired", At: ptr(testNow)}})
		})
		s := build(in).RowsSummary
		if s.NextStep == nil || s.NextStep.Action != ActionOpenTool {
			t.Fatalf("%+v", s)
		}
	})
	t.Run("nothing detected or allowed", func(t *testing.T) {
		in := Input{Now: testNow, ConsentGeneration: 7}
		add(&in, "claude", func(in *Input, id string) {
			setReader(in, id, false, false)
			in.Consents[0].State = ConsentDenied
		})
		s := build(in).RowsSummary
		if s.State == SummaryStatePending || (s.State == SummaryStateEmpty && s.Reason.Code != CodeNoDockRows) {
			t.Fatalf("%+v", s)
		}
	})
}

// A true empty / no_dock_rows: an allowed tool that has no reader is neither being read nor does
// it need an action the user can take.
func TestG338NoDockRowsWhenAllowedToolHasNoReader(t *testing.T) {
	in := Input{Now: testNow, ConsentGeneration: 7}
	in.Catalogue = append(in.Catalogue, CatalogueEntry{ToolID: "claude", Detected: true, ReaderExists: false})
	in.Consents = append(in.Consents, ConsentRecord{ToolID: "claude", Generation: 7, State: ConsentAllowed})
	out := Build(in)
	if err := Validate(in, out); err != nil {
		t.Fatal(err)
	}
	s := out.RowsSummary
	if s.State != SummaryStateEmpty || s.Reason.Code != CodeNoDockRows || s.NextStep == nil || s.NextStep.Action != ActionOpenSettingsConsent {
		t.Fatalf("%+v", s)
	}
}
