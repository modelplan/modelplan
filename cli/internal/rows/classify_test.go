// SPDX-License-Identifier: MIT
package rows

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"strings"
	"testing"
	"time"
)

func ptr[T any](v T) *T { return &v }

var testNow = time.Date(2026, 10, 29, 10, 0, 0, 0, time.UTC)

func baseFacts() classification {
	return classification{Consent: ConsentAllowed, Detected: true, ReaderExists: true, Latest: AttemptResultNever}
}

func TestTotalClassifierAndNamedOverlaps(t *testing.T) {
	tests := []struct {
		name string
		set  func(*classification)
		code Code
	}{
		{"privacy beats current", func(f *classification) { f.Veto = CodePrivacyBlocked; f.Current = 1 }, CodePrivacyBlocked},
		{"outdated beats retained", func(f *classification) { f.Outdated = true; f.Retained = 1 }, CodeConsentOutdated},
		{"unset is reader consent", func(f *classification) { f.Consent = ConsentUnset }, CodeConsentRequired},
		{"denied beats current", func(f *classification) { f.Consent = ConsentDenied; f.Current = 1 }, CodeConsentDenied},
		{"cleanup wins", func(f *classification) { f.Consent = ConsentDenied; f.Cleanup = true; f.Current = 1 }, CodeCleanupPending},
		{"changed before values", func(f *classification) { f.Changed = true; f.Current = 1 }, CodeConsentChanged},
		{"missing beats no reader", func(f *classification) { f.Detected = false; f.ReaderExists = false }, CodeToolNotFound},
		{"retired beats no reader", func(f *classification) { f.Retired = true; f.ReaderExists = false }, CodeCatalogueRetired},
		{"unsupported before pending", func(f *classification) { f.ReaderExists = false }, CodeNoReader},
		{"keychain first failure", func(f *classification) {
			f.Keychain = CodeKeychainUnset
			f.Latest = AttemptResultFailed
			f.Failure = CodeUnsupportedLogin
		}, CodeKeychainUnset},
		{"keychain beats retained", func(f *classification) { f.Keychain = CodeKeychainDenied; f.Retained = 1 }, CodeKeychainDenied},
		{"readable credentials keep current", func(f *classification) { f.Current = 1 }, CodeOK},
		{"a current b none", func(f *classification) {
			f.Current = 1
			f.None = 1
			f.Latest = AttemptResultFailed
			f.Failure = CodeHTTP401
		}, CodeOK},
		{"current plus retained", func(f *classification) { f.Current = 1; f.Retained = 1 }, CodeStaleReading},
		{"unknown observation", func(f *classification) { f.Retained = 1; f.UnknownTime = true }, CodeObservationTimeUnknown},
		{"first parse failure", func(f *classification) { f.Latest = AttemptResultFailed; f.Failure = CodeParseError }, CodeParseError},
		{"expired login", func(f *classification) { f.Latest = AttemptResultFailed; f.Failure = CodeLoginExpired }, CodeLoginExpired},
		{"missing runtime", func(f *classification) { f.Latest = AttemptResultFailed; f.Failure = CodeRuntimeMissing }, CodeRuntimeMissing},
		{"failure before cooldown", func(f *classification) { f.Latest = AttemptResultFailed; f.Failure = CodeHTTP429; f.Busy = true }, CodeHTTP429},
		{"empty success", func(f *classification) { f.Latest = AttemptResultSucceeded }, CodeNoUsageWindows},
		{"no attempt", func(f *classification) {}, CodeNotReadYet},
		{"busy", func(f *classification) { f.Busy = true }, CodeReaderBusy},
		{"estimated", func(f *classification) { f.Current = 1; f.Estimated = true }, CodeEstimated},
		{"declared bypasses tool predicates", func(f *classification) {
			f.Declared = true
			f.Consent = ConsentUnset
			f.ReaderExists = false
			f.Detected = false
			f.Keychain = CodeKeychainDenied
			f.Veto = CodeNotAdmitted
		}, CodeNoManualReading},
		{"declared privacy veto", func(f *classification) { f.Declared = true; f.Current = 1; f.Veto = CodePrivacyBlocked }, CodePrivacyBlocked},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := baseFacts()
			tt.set(&f)
			out := classify(f)
			if out.Code != tt.code {
				t.Fatalf("got %+v, want %s", out, tt.code)
			}
		})
	}
	// All normalized combinations of attempts and C/R/N terminate before row 11.
	for _, attempt := range []AttemptResult{AttemptResultNever, AttemptResultFailed, AttemptResultSucceeded} {
		for c := 0; c < 3; c++ {
			for r := 0; r < 3; r++ {
				for n := 0; n < 3; n++ {
					f := baseFacts()
					f.Latest = attempt
					f.Failure = CodeParseError
					f.Current = c
					f.Retained = r
					f.None = n
					if out := classify(f); out.Code == CodeOther {
						t.Fatalf("reachable default: %+v", f)
					}
				}
			}
		}
	}
}

func TestNormativeReasonTable(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	b, err := os.ReadFile(filepath.Join(filepath.Dir(file), "../../..", "schema/app-cli/rows-design.md"))
	if err != nil {
		t.Fatal(err)
	}
	section := strings.Split(strings.Split(string(b), "## Reason-code mapping (normative)")[1], "A single Go table")[0]
	seen := map[Code]bool{}
	for _, line := range strings.Split(section, "\n") {
		if !strings.HasPrefix(line, "| ") {
			continue
		}
		cells := strings.Split(line, "|")
		if len(cells) < 5 || strings.TrimSpace(cells[1]) == "code" {
			continue
		}
		state := strings.Fields(strings.TrimSpace(cells[2]))[0]
		action := strings.Fields(strings.TrimSpace(cells[3]))[0]
		for _, raw := range strings.Split(cells[1], ",") {
			code := Code(strings.TrimSpace(raw))
			seen[code] = true
			out := Describe(code)
			if out.Code != code || string(out.State) != state || string(out.Action) != action || out.Text.EN == "" || out.Text.ZH == "" {
				t.Errorf("%s: %+v != %s/%s", code, out, state, action)
			}
		}
	}
	if len(seen) != len(outcomes) {
		t.Fatalf("normative/table mismatch: %d vs %d", len(seen), len(outcomes))
	}
}

func TestIntentionalOtherAndUnknownFallback(t *testing.T) {
	count := 0
	for key, code := range signalCodes {
		if code == CodeOther {
			count++
			if !IntentionalOther(key.Channel, key.Value) {
				t.Errorf("unexpected intentional other: %+v", key)
			}
		}
	}
	if count != 1 {
		t.Fatalf("generic outcomes expanded: %d", count)
	}
	for _, channel := range []SignalChannel{SignalStatus, SignalError, SignalBlocked, SignalDetection, SignalKeychain} {
		out, known := MapSignal(channel, "future_provider_error_account_token_123")
		if known || out.Code != CodeOther || out.State != StateFailed || out.Action != ActionRefresh {
			t.Fatalf("unsafe fallback %+v/%v", out, known)
		}
	}
	for _, pair := range []struct {
		channel SignalChannel
		raw     string
		code    Code
	}{
		{SignalStatus, "consent_required", CodeNotAdmitted}, {SignalKeychain, "consent-required", CodeKeychainUnset}, {SignalKeychain, "busy", CodeReaderBusy}, {SignalBlocked, "no-native-reader", CodeNoReader}, {SignalDetection, "unknown", CodeToolNotFound},
	} {
		out, known := MapSignal(pair.channel, pair.raw)
		if !known || out.Code != pair.code {
			t.Errorf("%+v -> %+v", pair, out)
		}
	}
}

func sampleInput() Input {
	return Input{Now: testNow, ConsentGeneration: 7,
		Catalogue: []CatalogueEntry{{ToolID: "codex", Detected: true, ReaderExists: true}},
		Consents:  []ConsentRecord{{ToolID: "codex", Generation: 7, State: ConsentAllowed}},
		Profiles:  []ProfileState{{ToolID: "codex", ProfileKey: "a", LatestAttempt: AttemptResultSucceeded, AttemptedAt: ptr(testNow.Add(-time.Minute)), ObservedAt: ptr(testNow.Add(-time.Minute)), WithinFreshness: true, FreshUntil: ptr(testNow.Add(time.Hour))}},
		Accounts:  []AccountInput{{ToolID: "codex", ProfileKey: "a", SubscriptionRef: ptr("0123456789abcdef"), PlanID: "pro", Windows: []WindowInput{{Kind: "five_hour", DurationSeconds: ptr(int64(18000)), RemainingPercent: ptr(75.0), ResetMode: "fixed", ResetsAt: ptr(testNow.Add(5 * time.Minute)), ObservedAt: ptr(testNow.Add(-time.Minute))}}}},
	}
}
func rowByID(t *testing.T, p Projection, id string) Row {
	t.Helper()
	for _, r := range p.Rows {
		if r.ID == id {
			return r
		}
	}
	t.Fatalf("missing row %s in %+v", id, p)
	return Row{}
}

func TestMembershipAndNoReappearingDeniedValues(t *testing.T) {
	for _, code := range []Code{CodeOK, CodeParseError, CodeRuntimeMissing, CodeLoginExpired, CodeKeychainDenied, CodeNoReader, CodeToolNotFound, CodeCatalogueRetired} {
		in := sampleInput()
		switch code {
		case CodeParseError, CodeRuntimeMissing, CodeLoginExpired:
			in.Accounts = nil
			in.Profiles[0].LatestAttempt = AttemptResultFailed
			in.Profiles[0].LastFailure = &FailureInput{Code: string(code), At: ptr(testNow)}
		case CodeKeychainDenied:
			in.Accounts = nil
			in.Catalogue[0].ToolID = "claude"
			in.Consents[0].ToolID = "claude"
			in.Profiles[0].ToolID = "claude"
			in.KeychainBlocks = []KeychainBlock{{ToolID: "claude", Blocked: true, Status: "denied"}}
		case CodeNoReader:
			in.Catalogue[0].ReaderExists = false
		case CodeToolNotFound:
			in.Catalogue[0].Detected = false
			in.Catalogue[0].ReaderExists = false
		case CodeCatalogueRetired:
			in.Catalogue = nil
		}
		out := Build(in)
		id := "codex"
		if code == CodeKeychainDenied {
			id = "claude"
		}
		row := rowByID(t, out, id)
		if len(out.Rows) != 1 || !reflect.DeepEqual(row.Surfaces, []Surface{SurfaceDock, SurfaceMenu, SurfaceSettings}) || row.Reason.Code != code {
			t.Fatalf("%s lost membership/state: %+v", code, out)
		}
	}
	for _, cleanup := range []bool{false, true} {
		in := sampleInput()
		in.Consents[0].State = ConsentDenied
		in.Consents[0].CleanupPending = cleanup
		row := rowByID(t, Build(in), "codex")
		if len(row.Accounts) != 0 || !reflect.DeepEqual(row.Surfaces, []Surface{SurfaceSettings}) {
			t.Fatal("revoked readings reappeared", row)
		}
	}
	in := sampleInput()
	in.Consents[0].State = ConsentImplicit
	if rowByID(t, Build(in), "codex").State != StateFresh {
		t.Fatal("implicit permission was lost")
	}
	in = sampleInput()
	in.ReadersOff = true
	in.DeclaredPlanIDs = []string{"manual-key"}
	out := Build(in)
	if len(out.Rows) != 1 || out.Rows[0].Kind != KindDeclared || out.RowsSummary.State != SummaryStateReadersOff {
		t.Fatalf("readers off lost declared row %+v", out)
	}
	in.ConsentChanged = true
	out = Build(in)
	if out.RowsSummary.State != SummaryStatePending || out.RowsSummary.Reason.Code != CodeConsentChanged || out.ConsentGeneration != 7 {
		t.Fatalf("bad fail-closed shape %+v", out)
	}
}

func TestProfilesClocksAndPrivacyCanaries(t *testing.T) {
	in := sampleInput()
	// A retained account makes the row stale without suppressing current A's window.
	in.Profiles = append(in.Profiles, ProfileState{ToolID: "codex", ProfileKey: "b", LatestAttempt: AttemptResultFailed, ObservedAt: ptr(testNow.Add(-time.Hour)), WithinFreshness: true, FreshUntil: ptr(testNow.Add(time.Hour)), LastFailure: &FailureInput{Code: "parse_error", At: ptr(testNow)}})
	b := in.Accounts[0]
	b.ProfileKey = "b"
	b.SubscriptionRef = nil
	in.Accounts = append(in.Accounts, b)
	row := rowByID(t, Build(in), "codex")
	if row.State != StateStale || row.Accounts[1].ValueState != ValueStateRetained || row.Accounts[1].LastFailure.Code != CodeParseError || !row.Accounts[0].Windows[0].Current || row.Accounts[1].Windows[0].Current {
		t.Fatalf("wrong C/R projection %+v", row)
	}
	in = sampleInput()
	in.Profiles[0].LoginChanged = true
	row = rowByID(t, Build(in), "codex")
	if row.Accounts[0].ValueState != ValueStateNone || len(row.Accounts[0].Windows) != 0 || row.Accounts[0].SubscriptionRef != nil {
		t.Fatal("old login value/ref survived", row)
	}
	for _, observation := range []*time.Time{nil, ptr(testNow.Add(time.Hour))} {
		in = sampleInput()
		in.Profiles[0].ObservedAt = observation
		row = rowByID(t, Build(in), "codex")
		if row.Reason.Code != CodeObservationTimeUnknown || row.Accounts[0].ObservedAt != nil || row.Accounts[0].Windows[0].Current {
			t.Fatal("unknown/future time became current", row)
		}
	}
	in = sampleInput()
	weekly := in.Accounts[0].Windows[0]
	weekly.Kind = "weekly"
	weekly.DurationSeconds = ptr(int64(604800))
	weekly.ResetsAt = ptr(testNow.Add(2 * time.Hour))
	in.Accounts[0].Windows = append(in.Accounts[0].Windows, weekly)
	row = rowByID(t, Build(in), "codex")
	if row.ExpiresAt == nil || !row.ExpiresAt.Equal(testNow.Add(5*time.Minute)) || row.StateAfterExpiry == nil || row.StateAfterExpiry.State == StateFresh {
		t.Fatalf("missing conservative latch %+v", row)
	}
	// Walking a held snapshot: the session expires, weekly remains current until
	// its account deadline; the row latch never passes through a fresh state.
	for _, elapsed := range []time.Duration{6 * time.Minute, 30 * time.Minute, 2 * time.Hour} {
		at := testNow.Add(elapsed)
		current := 0
		for _, w := range row.Accounts[0].Windows {
			if w.Current && w.ValidUntil != nil && at.Before(*w.ValidUntil) {
				current++
			}
		}
		want := 1
		if elapsed >= time.Hour {
			want = 0
		}
		if current != want || row.StateAfterExpiry.State != StateStale {
			t.Fatalf("deadline %s: current=%d row=%+v", elapsed, current, row)
		}
	}
	in = sampleInput()
	w := in.Accounts[0].Windows[0]
	in.Accounts[0].Windows = append(in.Accounts[0].Windows, w)
	row = rowByID(t, Build(in), "codex")
	if row.Accounts[0].Windows[0].ID == row.Accounts[0].Windows[1].ID {
		t.Fatal("colliding window ids")
	}
	canaries := []string{"me@example.test", "/private/home/credential.json", strings.Repeat("a", 64), "account_token_123", "provider error contains secret"}
	for _, canary := range canaries {
		in = sampleInput()
		in.Accounts[0].PlanID = canary
		in.Accounts[0].ProfileKey = canary
		in.Profiles[0].ProfileKey = canary
		in.Accounts[0].Source = canary
		in.Accounts[0].Windows[0].Limit = canary
		in.Accounts[0].Windows[0].Pool = canary
		in.Sources = []SourceState{{ToolID: "codex", Reason: canary, Status: "ok"}}
		encoded, err := json.Marshal(Build(in))
		if err != nil {
			t.Fatal(err)
		}
		if strings.Contains(string(encoded), canary) {
			t.Fatalf("canary escaped rows: %s", encoded)
		}
	}
}
