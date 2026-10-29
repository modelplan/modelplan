// SPDX-License-Identifier: MIT
package quota

import (
	"github.com/modelplan/modelplan/cli/internal/consent"
	"testing"
)

// Historical parser/identity/budget fixtures exercise the dormant POST protocol
// against synthetic transports. They explicitly remove its compiled policy gate
// for this test only. Production gate regressions in internal/readers use the
// unchanged bindings and valid synthetic logins through ProductionPaths.
func allowPOSTProtocolFixture(t *testing.T, provider string) {
	t.Helper()
	scope, exists := nativeAdmissionScopes[provider]
	if !exists {
		return
	}
	delete(nativeAdmissionScopes, provider)
	t.Cleanup(func() { nativeAdmissionScopes[provider] = scope })
}

func TestPolicyPendingEntryPoint(t *testing.T) {
	for _, tc := range []struct {
		provider, scope string
		pending         bool
	}{
		{"gemini", consent.ScopeGeminiAccountUsageSavedLogin, true},
		{"cursor", consent.ScopeCursorAccountUsageSavedLogin, true},
		{"minimax", "", false}, {"claude", "", false}, {"", "", false},
		{"gemini.local_history", "", false}, {"cursor.local_history", "", false},
		{"future-provider", "", false},
	} {
		scope, pending := PolicyPending(tc.provider)
		if scope != tc.scope || pending != tc.pending {
			t.Errorf("%s: got (%q,%t), want (%q,%t)", tc.provider, scope, pending, tc.scope, tc.pending)
		}
	}
}
