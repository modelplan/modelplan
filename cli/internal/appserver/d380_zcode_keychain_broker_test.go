// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// D380: the app's ZCode Keychain result is accepted only under the scope's own Keychain Allow; a
// result without it is refused before any Paths (and so any read) is built.
func TestD380ZCodeCredentialNeedsItsKeychainChoice(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	built := 0
	b := &CredentialBroker{PathsFor: func(consent.Admission) quota.Paths { built++; return quota.Paths{} }}
	value := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
	result := wire.CredentialResult{OperationID: "op-1", Outcome: wire.OutcomeOK, AccessToken: &value}
	need := CredentialNeed{Provider: "zai", Scope: consent.ScopeZaiAccountUsageSavedLogin, Interactive: true}
	err := b.AcceptCredential(context.Background(), credentialStamp(consent.Capture()), need, result)
	if pe, ok := err.(ProtocolError); !ok || pe.Code != wire.CodeCredentialRejected || built != 0 {
		t.Fatalf("err=%v built=%d", err, built)
	}
	if v, status := zcodeCredentialValue(wire.CredentialResult{OperationID: "op-2", Outcome: wire.OutcomeDenied}); v != nil || status != "denied" {
		t.Fatalf("denied result = %q %q", v, status)
	}
}
