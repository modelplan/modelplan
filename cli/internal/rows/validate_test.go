// SPDX-License-Identifier: MIT
package rows

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"
	"time"
)

func TestFieldSpecificValidationAndMutationCanaries(t *testing.T) {
	in := sampleInput()
	if err := Validate(in, Build(in)); err != nil {
		t.Fatal(err)
	}
	for _, mutate := range []struct {
		name string
		edit func(*Projection)
	}{
		{"route canary", func(p *Projection) { p.Rows[0].Accounts[0].Route = Route("private_token@example.test") }},
		{"route missing", func(p *Projection) { p.Rows[0].Accounts[0].Route = "" }},
		{"id provenance", func(p *Projection) { p.Rows[0].ID = "deadbeefdeadbeef" }},
		{"title table", func(p *Projection) { p.Rows[0].Name.EN = "me@example.test" }},
		{"art key", func(p *Projection) { p.Rows[0].VendorKey = ptr("/private/account") }},
		{"reason text", func(p *Projection) { p.Rows[0].Reason.Text.ZH = "provider error account_token_123" }},
		{"reference membership", func(p *Projection) { p.Rows[0].Accounts[0].SubscriptionRef = ptr("deadbeefdeadbeef") }},
		{"locator", func(p *Projection) { p.Rows[0].Accounts[0].AccountLocator = ptr(strings.Repeat("a", 64)) }},
		{"plan name", func(p *Projection) { p.Rows[0].Accounts[0].Plan.Name.EN = "account name" }},
		{"window id", func(p *Projection) { p.Rows[0].Accounts[0].Windows[0].ID = "account_token_123" }},
		{"window label", func(p *Projection) { p.Rows[0].Accounts[0].Windows[0].Label.EN = "me@example.test" }},
		{"limit key", func(p *Projection) { p.Rows[0].Accounts[0].Windows[0].LimitKey = "account_token_123" }},
		{"pool key", func(p *Projection) { p.Rows[0].Accounts[0].Windows[0].PoolKey = "profile_hash_123" }},
		{"clock", func(p *Projection) { p.Rows[0].Accounts[0].Windows[0].ObservedAt = ptr(testNow.Add(time.Minute)) }},
		{"percentage", func(p *Projection) { p.Rows[0].Accounts[0].Windows[0].RemainingPercent = ptr(101.0) }},
		{"reset mode", func(p *Projection) { p.Rows[0].Accounts[0].Windows[0].ResetMode = ResetMode("provider secret") }},
		{"summary", func(p *Projection) { p.RowsSummary.Text.EN = "provider account name" }},
	} {
		t.Run(mutate.name, func(t *testing.T) {
			out := Build(in)
			mutate.edit(&out)
			if Validate(in, out) == nil {
				t.Fatal("mutation escaped field-specific validation")
			}
		})
	}
	// Input evidence is copied: mutating the output must not mutate the input.
	original := sampleInput()
	before, _ := json.Marshal(original.Profiles)
	_ = Build(original)
	after, _ := json.Marshal(original.Profiles)
	if string(before) != string(after) {
		t.Fatal("projection mutated profile facts")
	}
}

func TestDeclarationIdentityOffAndCooldown(t *testing.T) {
	in := sampleInput()
	in.DeclaredPlanIDs = []string{"second plan", "first/plan"}
	one := Build(in)
	in.DeclaredPlanIDs = []string{"first/plan", "second plan"}
	two := Build(in)
	if !reflect.DeepEqual(one, two) {
		t.Fatal("declaration order changed identities/preferences")
	}
	for _, row := range one.Rows {
		if row.Kind == KindDeclared && (row.Consent != ConsentNotRequired || !row.Name.UserAuthored || row.Reason.Code != CodeNoManualReading || row.NextStep.Action != ActionNone) {
			t.Fatal("declaration acquired tool predicates", row)
		}
	}
	if err := Validate(in, two); err != nil {
		t.Fatal(err)
	}
	in = sampleInput()
	in.IdentityOff = true
	in.Profiles[0].AccountLocator = ptr("fedcba9876543210")
	row := rowByID(t, Build(in), "codex")
	if row.Accounts[0].SubscriptionRef != nil || row.Accounts[0].AccountLocator != nil {
		t.Fatal("identity-off exported references")
	}
	in = sampleInput()
	in.Profiles[0].LatestAttempt = AttemptResultFailed
	in.Profiles[0].LastFailure = &FailureInput{Code: "parse_error", At: ptr(testNow)}
	in.Profiles[0].NextAttemptAt = ptr(testNow.Add(5 * time.Minute))
	for _, mode := range []DisabledReason{DisabledReasonCooldown, DisabledReasonReadOnly, DisabledReasonOffline} {
		in.ReadOnly = mode == DisabledReasonReadOnly
		in.Offline = mode == DisabledReasonOffline
		out := Build(in)
		row := rowByID(t, out, "codex")
		if row.NextStep.Action != ActionRefresh || row.NextStep.DisabledReason == nil || *row.NextStep.DisabledReason != mode || row.NextStep.AvailableAt == nil {
			t.Fatalf("refresh bypassed %s: %+v", mode, row.NextStep)
		}
		if err := Validate(in, out); err != nil {
			t.Fatal(err)
		}
	}
}

func TestSourceOnlyFailureAndCredentialStoreSeparation(t *testing.T) {
	in := Input{Now: testNow, ConsentGeneration: 1, Catalogue: []CatalogueEntry{{ToolID: "grok", Detected: true, ReaderExists: true}}, Consents: []ConsentRecord{{ToolID: "grok", Generation: 1, State: ConsentAllowed}}, Sources: []SourceState{{ToolID: "grok", Source: "native:grok", Status: "error", ErrorCode: "parse_error"}}}
	row := rowByID(t, Build(in), "grok")
	if row.State != StateFailed || row.Reason.Code != CodeParseError || row.NextStep.Action != ActionRefresh || len(row.Accounts) != 0 {
		t.Fatalf("first failure lost its row %+v", row)
	}
	if err := Validate(in, Build(in)); err != nil {
		t.Fatal(err)
	}
	in = sampleInput()
	in.Catalogue[0].ToolID = "claude"
	in.Consents[0].ToolID = "claude"
	in.Profiles[0].ToolID = "claude"
	in.Accounts[0].ToolID = "claude"
	in.KeychainBlocks = []KeychainBlock{{ToolID: "claude", Status: "unset", Blocked: false}}
	in.Sources = []SourceState{{ToolID: "claude", Status: "consent_required"}}
	if rowByID(t, Build(in), "claude").State != StateFresh {
		t.Fatal("saved Keychain choice hid a readable credentials file")
	}
	in.Accounts = nil
	in.KeychainBlocks[0].Blocked = true
	for _, tc := range []struct {
		status string
		code   Code
	}{{"unset", CodeKeychainUnset}, {"denied", CodeKeychainDenied}, {"keychain-confirmation-needed", CodeKeychainConfirmationNeeded}, {"busy", CodeReaderBusy}} {
		in.KeychainBlocks[0].Status = tc.status
		row = rowByID(t, Build(in), "claude")
		if row.Reason.Code != tc.code {
			t.Fatalf("credential state %s: %+v", tc.status, row)
		}
	}
}

func TestExpiryGuidanceAndCollisionOrdering(t *testing.T) {
	in := sampleInput()
	in.Profiles[0].CoolingDown = false
	in.Profiles[0].NextAttemptAt = ptr(testNow.Add(2 * time.Minute))
	row := rowByID(t, Build(in), "codex")
	if row.StateAfterExpiry.NextStep.DisabledReason != nil || row.StateAfterExpiry.NextStep.AvailableAt != nil {
		t.Fatal("latch retained an already elapsed cooldown")
	}
	in.Profiles[0].CoolingDown = true
	row = rowByID(t, Build(in), "codex")
	if row.StateAfterExpiry.NextStep.DisabledReason == nil {
		t.Fatal("elapsed time bound bypassed an observed budget hold")
	}

	in.Profiles[0].NextAttemptAt = nil
	in.Profiles[0].LatestAttempt = AttemptResultFailed
	in.Profiles[0].LastFailure = &FailureInput{Code: "network", At: ptr(testNow)}
	row = rowByID(t, Build(in), "codex")
	if row.NextStep.DisabledReason == nil || *row.NextStep.DisabledReason != DisabledReasonCooldown {
		t.Fatal("unknown cooldown deadline enabled refresh")
	}
	in = sampleInput()
	a := in.Accounts[0].Windows[0]
	a.ResetsAt = nil
	b := a
	b.RemainingPercent = ptr(40.0)
	in.Accounts[0].Windows = []WindowInput{a, b}
	first := Build(in)
	in.Accounts[0].Windows = []WindowInput{b, a}
	second := Build(in)
	if !reflect.DeepEqual(first, second) {
		t.Fatal("window collision ids depend on input positions")
	}
	for _, changed := range []string{"login", "generation"} {
		in = sampleInput()
		in.Profiles[0].LoginChanged = changed == "login"
		in.Profiles[0].GenerationChanged = changed == "generation"
		projected := Build(in)
		row = rowByID(t, projected, "codex")
		if row.Accounts[0].ValueState != ValueStateNone || len(row.Accounts[0].Windows) != 0 {
			t.Fatal("discarded account retained numbers")
		}
		if err := Validate(in, projected); err != nil {
			t.Fatal(err)
		}
	}
}

func TestCaptureDoesNotBlessUnknownAsIntentionalOther(t *testing.T) {
	in := sampleInput()
	in.Profiles[0].LatestAttempt = AttemptResultFailed
	in.Profiles[0].LastFailure = &FailureInput{Code: "other", At: ptr(testNow)}
	if err := ValidateCapture(in, Build(in)); err != nil {
		t.Fatal(err)
	}
	in.Profiles[0].LastFailure.Code = "provider_unmapped_secret_error"
	out := Build(in)
	if out.Rows[0].Accounts[0].LastFailure.Code != CodeOther {
		t.Fatal("unknown failure did not degrade conservatively")
	}
	if ValidateCapture(in, out) == nil {
		t.Fatal("unknown fallback became a permitted generic capture")
	}
}

func TestMixedGenerationAndUnsupportedKeychainFactsFailClosed(t *testing.T) {
	in := sampleInput()
	in.Consents[0].Generation = 6
	in.DeclaredPlanIDs = []string{"my-manual-plan"}
	out := Build(in)
	if len(out.Rows) != 1 || out.Rows[0].Kind != KindDeclared || out.RowsSummary.State != SummaryStatePending || out.RowsSummary.Reason.Code != CodeConsentChanged {
		t.Fatalf("mixed permission views leaked tool rows: %+v", out)
	}
	in = sampleInput()
	in.KeychainBlocks = []KeychainBlock{{ToolID: "codex", Blocked: true, Status: "denied"}}
	if rowByID(t, Build(in), "codex").State != StateFresh {
		t.Fatal("unsupported tool acquired Keychain guidance")
	}
	in.Consents[0].State = Consent("future-unknown")
	row := rowByID(t, Build(in), "codex")
	if len(row.Accounts) != 0 || row.Reason.Code != CodeConsentRequired {
		t.Fatal("unknown consent became permission")
	}
}

func TestEmptySuccessAndBusyRetainedGuidance(t *testing.T) {
	in := sampleInput()
	in.Accounts[0].Windows = nil
	out := Build(in)
	if rowByID(t, out, "codex").Reason.Code != CodeNoUsageWindows {
		t.Fatal("empty success stayed pending")
	}
	if err := Validate(in, out); err != nil {
		t.Fatal(err)
	}
	in = sampleInput()
	in.Profiles = nil
	in.Accounts = nil
	in.Sources = []SourceState{{ToolID: "codex", Status: "ok"}}
	if rowByID(t, Build(in), "codex").Reason.Code != CodeNoUsageWindows {
		t.Fatal("legacy empty success stayed pending")
	}
	in = sampleInput()
	in.Profiles[0].LatestAttempt = AttemptResultFailed
	in.Profiles[0].LastFailure = &FailureInput{Code: "network", At: ptr(testNow)}
	in.Profiles[0].Busy = true
	row := rowByID(t, Build(in), "codex")
	if row.State != StateStale || row.NextStep.DisabledReason == nil {
		t.Fatal("busy retained row allowed another refresh")
	}
	in.Profiles[0].LoginChanged = true
	row = rowByID(t, Build(in), "codex")
	if row.Accounts[0].Plan.ID != "unknown" {
		t.Fatal("discarded login retained its old plan label")
	}
}
