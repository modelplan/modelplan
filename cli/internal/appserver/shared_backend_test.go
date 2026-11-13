// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"testing"
	"time"
)

func TestSharedProjectionKeepsRuntimeRoute(t *testing.T) {
	now := time.Now()
	in := rows.Input{Now: now}
	appendReportRows(&in, quota.Report{Accounts: []quota.Account{{Source: "codex", Via: "codex-account", ObservedAt: now}}}, false)
	if len(in.Accounts) != 1 || in.Accounts[0].Route != rows.RouteRuntimeRPC {
		t.Fatal("runtime route lost")
	}
}
func TestSharedProjectionKeepsApprovedPOSTOptIn(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "")
	b, err := NewSharedBackend(SharedConfig{
		Detect: func() detect.Report {
			return detect.Report{Tools: []detect.Tool{{Entry: detect.Entry{ProviderID: "claude", Preferred: "native", ReaderID: "native:claude"}, Detected: true}, {Entry: detect.Entry{ProviderID: "gemini", Preferred: "native", ReaderID: "native:gemini"}, Detected: true}}}
		},
		Paths: func(a consent.Admission) quota.Paths { return quota.Paths{Admission: &a} }, Cleanup: func(string, bool) error { return nil },
	})
	if err != nil {
		t.Fatal(err)
	}
	s, _ := consent.Load(consent.Path())
	_, err = consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "fact-mapping", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeClaudeAccountUsageSavedLogin}, Keychain: map[string]string{consent.ScopeClaudeAccountUsageSavedLogin: "allow"}}, consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) {
		return consent.Record{ReaderID: "native:claude", Backend: "native"}, nil
	}})
	if err != nil {
		t.Fatal(err)
	}
	view, err := b.Get(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if view.Consent.TextVersion != consent.TextVersion {
		t.Fatalf("consent facts text version = %d, want producer version %d", view.Consent.TextVersion, consent.TextVersion)
	}
	seen := map[string]wire.ConsentScope{}
	for _, fact := range view.Consent.Scopes {
		seen[fact.Scope] = fact
	}
	if fact := seen[consent.ScopeClaudeAccountUsageSavedLogin]; fact.Keychain == nil || *fact.Keychain != wire.KeychainAllow {
		t.Fatalf("wrong keychain vocabulary: %+v", fact)
	}
	if fact := seen[consent.ScopeGeminiAccountUsageSavedLogin]; fact.Disabled != nil || fact.DefaultCheck || fact.State != wire.ConsentUnset {
		t.Fatal("approved POST scope was disabled or pre-selected")
	}
	for _, scope := range view.Scopes {
		if scope == consent.ScopeGeminiAccountUsageSavedLogin {
			t.Fatal("unset O-class scope admitted")
		}
	}
}

func TestResetCardsTravelFromReportToProjection(t *testing.T) {
	now := time.Now().UTC()
	count := 0
	ref := "0123456789abcdef"
	facts := &rows.ResetCards{State: rows.ResetCardComplete, Count: &count, Sources: []rows.ResetCardSource{{Source: rows.ResetCardCodexAccount, ObservedAt: now}}}
	in := rows.Input{Now: now, ConsentGeneration: 1, Catalogue: []rows.CatalogueEntry{{ToolID: "codex", Detected: true, ReaderExists: true}}, Consents: []rows.ConsentRecord{{ToolID: "codex", Generation: 1, State: rows.ConsentAllowed}}}
	appendReportRows(&in, quota.Report{Accounts: []quota.Account{{Source: "codex", Via: "codex-account", ObservedAt: now, Subscription: &quota.Binding{Ref: ref, Status: "verified"}, ResetCards: facts}}}, false)
	p := rows.Build(in)
	if err := rows.Validate(in, p); err != nil {
		t.Fatal(err)
	}
	if len(p.Rows) != 1 || len(p.Rows[0].Accounts) != 1 {
		t.Fatalf("missing admitted row: %+v", p.Rows)
	}
	got := wire.Project(p).Rows[0].Accounts[0].ResetCards
	if got == nil || got.State != rows.ResetCardComplete || got.Count == nil || *got.Count != 0 || len(got.Sources) != 1 || !got.Sources[0].ObservedAt.Equal(now) {
		t.Fatalf("missing bound observation: %+v", got)
	}
	in.ConsentChanged = true
	for _, row := range rows.Build(in).Rows {
		for _, a := range row.Accounts {
			if a.ResetCards != nil && a.ResetCards.State != rows.ResetCardUnknown {
				t.Fatal("fenced facts were delivered")
			}
		}
	}
}

func TestReportWindowSourcesRemainIndependent(t *testing.T) {
	now := time.Now().UTC()
	old := now.Add(-2 * time.Hour)
	in := rows.Input{Now: now}
	report := quota.Report{Accounts: []quota.Account{{Source: "codex", Via: "codex-account", ObservedAt: now,
		Windows: []quota.Window{{Kind: "five_hour", Origin: "local_history", ObservedAt: old}, {Kind: "weekly", Origin: "runtime", ObservedAt: now}}}}}
	appendReportRows(&in, report, false)
	if len(in.Accounts) != 1 || len(in.Accounts[0].Windows) != 2 {
		t.Fatalf("windows lost: %+v", in.Accounts)
	}
	local, runtime := in.Accounts[0].Windows[0], in.Accounts[0].Windows[1]
	if local.Source != rows.WindowSourceLocalHistory || local.ObservedAt == nil || !local.ObservedAt.Equal(old) {
		t.Fatalf("local provenance lost: %+v", local)
	}
	if runtime.Source != rows.WindowSourceRuntime || runtime.ObservedAt == nil || !runtime.ObservedAt.Equal(now) {
		t.Fatalf("runtime provenance lost: %+v", runtime)

	}
}
