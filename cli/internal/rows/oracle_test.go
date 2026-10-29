// SPDX-License-Identifier: MIT
package rows

// Oracle: written by the coordinator from schema/app-cli/rows-design.md, not from
// this package's implementation. Each case is a design rule or a named overlap;
// Build is exercised as a black box. If a case fails, the design wins unless the
// coordinator changes the design.

import (
	"testing"
	"time"
)

var oracleNow = time.Date(2026, 10, 29, 12, 0, 0, 0, time.UTC)

func oracleTime(d time.Duration) *time.Time { t := oracleNow.Add(d); return &t }
func oracleF(v float64) *float64          { return &v }
func oracleI(v int64) *int64              { return &v }
func oracleS(v string) *string            { return &v }

func oracleTool(id string, detected bool) CatalogueEntry {
	return CatalogueEntry{ToolID: id, ReaderID: "native:" + id, Backend: "native", Detected: detected, ReaderExists: true}
}

func oracleWindow() WindowInput {
	return WindowInput{Kind: "five_hour", DurationSeconds: oracleI(18000), RemainingPercent: oracleF(40), ResetsAt: oracleTime(2 * time.Hour), ObservedAt: oracleTime(-5 * time.Minute)}
}

func oracleAccount(tool, profile string, windows ...WindowInput) AccountInput {
	return AccountInput{ToolID: tool, ProfileKey: profile, Source: "native:" + tool, PlanID: "unknown", Windows: windows}
}

func oracleFresh(tool, profile string) ProfileState {
	return ProfileState{ToolID: tool, ProfileKey: profile, LatestAttempt: AttemptResultSucceeded, AttemptedAt: oracleTime(-5 * time.Minute),
		ObservedAt: oracleTime(-5 * time.Minute), WithinFreshness: true, FreshUntil: oracleTime(time.Hour)}
}

func oracleAllowed(ids ...string) []ConsentRecord {
	out := []ConsentRecord{}
	for _, id := range ids {
		out = append(out, ConsentRecord{ToolID: id, Generation: 7, State: ConsentAllowed})
	}
	return out
}

func oracleRow(t *testing.T, p Projection, id string) *Row {
	t.Helper()
	var found *Row
	for i := range p.Rows {
		if p.Rows[i].ID == id {
			if found != nil {
				t.Fatalf("row %s appears twice", id)
			}
			found = &p.Rows[i]
		}
	}
	return found
}

func oracleHas(r *Row, s Surface) bool {
	for _, x := range r.Surfaces {
		if x == s {
			return true
		}
	}
	return false
}

type oracleWant struct {
	row     string
	absent  bool
	state   State
	code    Code
	action  Action // "" = do not check
	dock    bool
	noAcc   bool // accounts must be empty
	consent Consent
}

func TestDesignOracle(t *testing.T) {
	cases := []struct {
		name    string
		in      Input
		want    []oracleWant
		summary SummaryState
	}{
		{name: "fresh reading", in: Input{Catalogue: []CatalogueEntry{oracleTool("codex", true)}, Consents: oracleAllowed("codex"),
			Profiles: []ProfileState{oracleFresh("codex", "p1")}, Accounts: []AccountInput{oracleAccount("codex", "p1", oracleWindow())}},
			want: []oracleWant{{row: "codex", state: StateFresh, code: CodeOK, dock: true}}, summary: SummaryStateOK},

		{name: "first read failed, no account (grok P1)", in: Input{Catalogue: []CatalogueEntry{oracleTool("grok", true)}, Consents: oracleAllowed("grok"),
			Profiles: []ProfileState{{ToolID: "grok", ProfileKey: "g1", LatestAttempt: AttemptResultFailed, AttemptedAt: oracleTime(-time.Minute), LastFailure: &FailureInput{Code: "parse_error", At: oracleTime(-time.Minute)}}}},
			want: []oracleWant{{row: "grok", state: StateFailed, code: CodeParseError, action: ActionRefresh, dock: true}}},

		{name: "keychain actually blocks claude read", in: Input{Catalogue: []CatalogueEntry{oracleTool("claude", true)}, Consents: oracleAllowed("claude"),
			Profiles:       []ProfileState{{ToolID: "claude", ProfileKey: "c1", LatestAttempt: AttemptResultFailed, AttemptedAt: oracleTime(-time.Minute), LastFailure: &FailureInput{Code: "keychain-confirmation-needed", At: oracleTime(-time.Minute)}}},
			KeychainBlocks: []KeychainBlock{{ToolID: "claude", Blocked: true, Status: "keychain-confirmation-needed"}}},
			want: []oracleWant{{row: "claude", state: StateNeedsKeychain, code: CodeKeychainConfirmationNeeded, action: ActionOpenSettingsKeychain, dock: true}}},

		{name: "keychain choice unset but credentials file works stays fresh", in: Input{Catalogue: []CatalogueEntry{oracleTool("claude", true)}, Consents: oracleAllowed("claude"),
			Profiles: []ProfileState{oracleFresh("claude", "c1")}, Accounts: []AccountInput{oracleAccount("claude", "c1", oracleWindow())},
			KeychainBlocks: []KeychainBlock{{ToolID: "claude", Blocked: false, Status: "unset"}}},
			want: []oracleWant{{row: "claude", state: StateFresh, code: CodeOK, dock: true}}},

		{name: "A current + B retained after a failed refresh is stale", in: Input{Catalogue: []CatalogueEntry{oracleTool("codex", true)}, Consents: oracleAllowed("codex"),
			Profiles: []ProfileState{oracleFresh("codex", "a"), {ToolID: "codex", ProfileKey: "b", LatestAttempt: AttemptResultFailed, AttemptedAt: oracleTime(-time.Minute),
				ObservedAt: oracleTime(-30 * time.Minute), WithinFreshness: true, FreshUntil: oracleTime(30 * time.Minute), LastFailure: &FailureInput{Code: "network", At: oracleTime(-time.Minute)}}},
			Accounts: []AccountInput{oracleAccount("codex", "a", oracleWindow()), oracleAccount("codex", "b", oracleWindow())}},
			want: []oracleWant{{row: "codex", state: StateStale, code: CodeStaleReading, dock: true}}},

		{name: "A current + B never read is fresh", in: Input{Catalogue: []CatalogueEntry{oracleTool("codex", true)}, Consents: oracleAllowed("codex"),
			Profiles: []ProfileState{oracleFresh("codex", "a"), {ToolID: "codex", ProfileKey: "b", LatestAttempt: AttemptResultNever}},
			Accounts: []AccountInput{oracleAccount("codex", "a", oracleWindow())}},
			want: []oracleWant{{row: "codex", state: StateFresh, code: CodeOK, dock: true}}},

		{name: "future observation time is never current", in: Input{Catalogue: []CatalogueEntry{oracleTool("codex", true)}, Consents: oracleAllowed("codex"),
			Profiles: []ProfileState{{ToolID: "codex", ProfileKey: "p1", LatestAttempt: AttemptResultSucceeded, AttemptedAt: oracleTime(-time.Minute), ObservedAt: oracleTime(time.Hour), WithinFreshness: true, FreshUntil: oracleTime(2 * time.Hour)}},
			Accounts: []AccountInput{oracleAccount("codex", "p1", oracleWindow())}},
			want: []oracleWant{{row: "codex", state: StateStale, code: CodeObservationTimeUnknown, dock: true}}},

		{name: "successful read with no windows is empty", in: Input{Catalogue: []CatalogueEntry{oracleTool("kimi", true)}, Consents: oracleAllowed("kimi"),
			Profiles: []ProfileState{oracleFresh("kimi", "k1")}, Accounts: []AccountInput{oracleAccount("kimi", "k1")}},
			want: []oracleWant{{row: "kimi", state: StateEmpty, code: CodeNoUsageWindows, dock: true}}},

		{name: "allowed, never read is pending", in: Input{Catalogue: []CatalogueEntry{oracleTool("gemini", true)}, Consents: oracleAllowed("gemini")},
			want: []oracleWant{{row: "gemini", state: StatePending, code: CodeNotReadYet, dock: true}}},

		{name: "allowed but uninstalled and readerless: tool_not_found beats no_reader", in: Input{Catalogue: []CatalogueEntry{{ToolID: "amp", Detected: false, ReaderExists: false}}, Consents: oracleAllowed("amp")},
			want: []oracleWant{{row: "amp", state: StateNeedsAction, code: CodeToolNotFound, dock: true}}},

		{name: "allowed, installed, no reader is unsupported", in: Input{Catalogue: []CatalogueEntry{{ToolID: "amp", Detected: true, ReaderExists: false}}, Consents: oracleAllowed("amp")},
			want: []oracleWant{{row: "amp", state: StateUnsupported, code: CodeNoReader, dock: true}}},

		{name: "allowed but retired from the catalogue keeps its row", in: Input{Consents: oracleAllowed("droid")},
			want: []oracleWant{{row: "droid", state: StateNeedsAction, code: CodeCatalogueRetired, dock: true}}},

		{name: "denied tool exports no accounts and has no dock row", in: Input{Catalogue: []CatalogueEntry{oracleTool("cursor", true)},
			Consents: []ConsentRecord{{ToolID: "cursor", Generation: 7, State: ConsentDenied}},
			Profiles: []ProfileState{oracleFresh("cursor", "u1")}, Accounts: []AccountInput{oracleAccount("cursor", "u1", oracleWindow())}},
			want: []oracleWant{{row: "cursor", dock: false, noAcc: true}}, summary: SummaryStateNoConsent},

		{name: "cleanup pending is settings only and hides accounts", in: Input{Catalogue: []CatalogueEntry{oracleTool("cursor", true)},
			Consents: []ConsentRecord{{ToolID: "cursor", Generation: 7, State: ConsentDenied, CleanupPending: true}},
			Profiles: []ProfileState{oracleFresh("cursor", "u1")}, Accounts: []AccountInput{oracleAccount("cursor", "u1", oracleWindow())}},
			want: []oracleWant{{row: "cursor", dock: false, noAcc: true}}},

		{name: "admission veto beats a fresh value", in: Input{Catalogue: []CatalogueEntry{oracleTool("copilot", true)}, Consents: oracleAllowed("copilot"),
			Profiles: []ProfileState{oracleFresh("copilot", "p1")}, Accounts: []AccountInput{oracleAccount("copilot", "p1", oracleWindow())},
			Admissions: []Admission{{ToolID: "copilot", Veto: "codexbar-not-audited"}}},
			want: []oracleWant{{row: "copilot", state: StateOff, code: CodeCodexBarNotAudited, dock: true}}},

		{name: "implicit consent behaves like allowed", in: Input{Catalogue: []CatalogueEntry{oracleTool("codex", true)},
			Consents: []ConsentRecord{{ToolID: "codex", Generation: 7, State: ConsentImplicit}},
			Profiles: []ProfileState{oracleFresh("codex", "p1")}, Accounts: []AccountInput{oracleAccount("codex", "p1", oracleWindow())}},
			want: []oracleWant{{row: "codex", state: StateFresh, code: CodeOK, dock: true}}},

		{name: "expired login needs the tool", in: Input{Catalogue: []CatalogueEntry{oracleTool("claude", true)}, Consents: oracleAllowed("claude"),
			Profiles: []ProfileState{{ToolID: "claude", ProfileKey: "c1", LatestAttempt: AttemptResultFailed, AttemptedAt: oracleTime(-time.Minute), LastFailure: &FailureInput{Code: "expired", At: oracleTime(-time.Minute)}}}},
			want: []oracleWant{{row: "claude", state: StateNeedsAction, code: CodeLoginExpired, action: ActionOpenTool, dock: true}}},

		{name: "readers off: no tool rows, declared plan still shows", in: Input{ReadersOff: true, Catalogue: []CatalogueEntry{oracleTool("codex", true)}, Consents: oracleAllowed("codex"),
			DeclaredPlanIDs: []string{"team-plan"}},
			want: []oracleWant{{row: "codex", absent: true}, {row: "declared:team-plan", dock: true}}, summary: SummaryStateReadersOff},

		{name: "detected but unset only in settings", in: Input{Catalogue: []CatalogueEntry{oracleTool("zai", true)}},
			want: []oracleWant{{row: "zai", dock: false}}, summary: SummaryStateNoConsent},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			in := tc.in
			in.Now, in.ConsentGeneration = oracleNow, 7
			p := Build(in)
			for _, w := range tc.want {
				r := oracleRow(t, p, w.row)
				if w.absent {
					if r != nil {
						t.Fatalf("row %s must be absent, got %+v", w.row, r)
					}
					continue
				}
				if r == nil {
					t.Fatalf("row %s missing; rows=%v", w.row, rowIDs(p))
				}
				if oracleHas(r, SurfaceDock) != w.dock {
					t.Fatalf("row %s dock surface = %v, want %v (%v)", w.row, !w.dock, w.dock, r.Surfaces)
				}
				if w.state != "" && r.State != w.state {
					t.Fatalf("row %s state = %s, want %s (code %s)", w.row, r.State, w.state, r.Reason.Code)
				}
				if w.code != "" && r.Reason.Code != w.code {
					t.Fatalf("row %s code = %s, want %s", w.row, r.Reason.Code, w.code)
				}
				if w.action != "" && (r.NextStep == nil || r.NextStep.Action != w.action) {
					t.Fatalf("row %s next step = %+v, want %s", w.row, r.NextStep, w.action)
				}
				if w.noAcc && len(r.Accounts) != 0 {
					t.Fatalf("row %s exported %d accounts for a non-allowed tool", w.row, len(r.Accounts))
				}
				if w.dock && r.State != StateFresh && (r.Reason.Text.EN == "" || r.NextStep == nil) {
					t.Fatalf("non-fresh dock row %s lacks a reason text or next step", w.row)
				}
			}
			if tc.summary != "" && p.RowsSummary.State != tc.summary {
				t.Fatalf("summary = %s, want %s", p.RowsSummary.State, tc.summary)
			}
			// Membership invariant: every allowed or implicit tool has exactly one Dock row unless readers are off.
			if !in.ReadersOff {
				for _, c := range in.Consents {
					if c.State != ConsentAllowed && c.State != ConsentImplicit {
						continue
					}
					r := oracleRow(t, p, CanonicalTool(c.ToolID))
					if r == nil || !oracleHas(r, SurfaceDock) {
						t.Fatalf("allowed tool %s has no Dock row", c.ToolID)
					}
				}
			}
		})
	}
}

func rowIDs(p Projection) []string {
	ids := []string{}
	for _, r := range p.Rows {
		ids = append(ids, r.ID)
	}
	return ids
}
