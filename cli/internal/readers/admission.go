// SPDX-License-Identifier: MIT

// Package readers provides the admission boundary for compiled read scopes.
// Callers must separately enforce consent, revocation and the shared read budget.
package readers

import (
	"errors"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

var (
	ErrPolicyPending    = errors.New("policy_pending")
	ErrUnsupportedScope = errors.New("unsupported_scope")
)

// CheckAdmission applies the first-batch policy before credential or source I/O.
// A saved-login grant cannot approve a vendor's POST request. Approval requires a
// reviewed policy change; the exact request set and body schema are compiled here.
// Gemini Code Assist and Cursor were approved as pinned on 2026-10-29.
// Local history is independent and remains eligible under its own consent.
func CheckAdmission(scope string) error {
	switch scope {
	case consent.ScopeGeminiAccountUsageSavedLogin, consent.ScopeCursorAccountUsageSavedLogin,
		consent.ScopeGeminiLocalHistory, consent.ScopeCursorLocalHistory,
		consent.ScopeMiniMaxAccountUsageAPIKey, consent.ScopeClaudeAccountUsageSavedLogin,
		consent.ScopeKimiAccountUsageAPIKey, consent.ScopeKimiAccountUsageSavedLogin,
		consent.ScopeZaiAccountUsageAPIKey, consent.ScopeOpenCodeGoAccountUsageAPIKey,
		consent.ScopeGrokAccountUsageSavedLogin:
		return nil
	default:
		return ErrUnsupportedScope
	}
}
