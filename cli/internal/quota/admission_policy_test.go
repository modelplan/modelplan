// SPDX-License-Identifier: MIT
package quota

import (
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestPolicyPendingEntryPoint(t *testing.T) {
	for _, tc := range []struct {
		provider, scope string
		pending         bool
	}{
		{"gemini", consent.ScopeGeminiAccountUsageSavedLogin, false},
		{"cursor", consent.ScopeCursorAccountUsageSavedLogin, false},
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
