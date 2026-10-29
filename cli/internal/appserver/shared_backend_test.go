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
func TestSharedProjectionNormalizesKeychainAndPolicyFacts(t *testing.T) {
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
	seen := map[string]wire.ConsentScope{}
	for _, fact := range view.Consent.Scopes {
		seen[fact.Scope] = fact
	}
	if fact := seen[consent.ScopeClaudeAccountUsageSavedLogin]; fact.Keychain == nil || *fact.Keychain != wire.KeychainAllow {
		t.Fatalf("wrong keychain vocabulary: %+v", fact)
	}
	if fact := seen[consent.ScopeGeminiAccountUsageSavedLogin]; fact.Disabled == nil || *fact.Disabled != wire.ScopePolicyPending {
		t.Fatal("policy pending not exposed")
	}
	for _, scope := range view.Scopes {
		if scope == consent.ScopeGeminiAccountUsageSavedLogin {
			t.Fatal("policy pending scope admitted")
		}
	}
}
