// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestSharedBackendRegrantPreservesLegacyKeychain(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "automatic")
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		return consent.Set(s, "claude", true, "native:claude", "native", time.Now())
	}); err != nil {
		t.Fatal(err)
	}
	b, err := NewSharedBackend(SharedConfig{
		Detect: func() detect.Report {
			return detect.Report{Tools: []detect.Tool{{Entry: detect.Entry{ProviderID: "claude", Preferred: "native", ReaderID: "native:claude"}, Detected: true}}}
		},
		Paths:   func(a consent.Admission) quota.Paths { return quota.Paths{Admission: &a} },
		Cleanup: func(string, bool) error { return nil },
	})
	if err != nil {
		t.Fatal(err)
	}
	before, err := consent.Load(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	params := wire.ConsentGrantParams{RequestID: "legacy-regrant", ExpectStoreEpoch: before.StoreEpoch, ExpectGeneration: before.Generation, TextVersion: consent.TextVersion, Allow: []string{consent.ScopeClaudeAccountUsageSavedLogin}, Deny: []string{}}
	receipt, err := b.Grant(context.Background(), params)
	if err != nil || !receipt.Receipt.Committed {
		t.Fatalf("grant=%+v %v", receipt, err)
	}
	admission := consent.Capture()
	if got := admission.KeychainStatus("claude"); got != "allowed" {
		t.Fatalf("reader admission=%s", got)
	}
	view, err := b.Get(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, fact := range view.Consent.Scopes {
		if fact.Scope == consent.ScopeClaudeAccountUsageSavedLogin {
			found = true
			if fact.Keychain == nil || *fact.Keychain != wire.KeychainAllow {
				t.Fatalf("readback=%+v", fact)
			}
		}
	}
	if !found {
		t.Fatal("missing saved-login scope")
	}
	params.RequestID = "stale-legacy-regrant"
	if _, err := b.Grant(context.Background(), params); err == nil {
		t.Fatal("stale generation accepted")
	}
	after, err := consent.Load(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	if after.Generation != before.Generation+1 || after.KeychainStatus("claude", consent.Automatic) != "allowed" {
		t.Fatalf("stale request changed consent: %+v", after)
	}
}
