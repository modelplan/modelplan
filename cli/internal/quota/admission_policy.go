// SPDX-License-Identifier: MIT
package quota

import (
	"errors"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/readers"
)

// Compiled scope bindings. These cannot be changed by connections, consent,
// catalogue data, an environment variable, or a user refresh.
var nativeAdmissionScopes = map[string]string{
	"gemini": consent.ScopeGeminiAccountUsageSavedLogin,
	"cursor": consent.ScopeCursorAccountUsageSavedLogin,
}

// PolicyPending reports a compiled account-usage scope awaiting POST approval.
// It is a policy veto, never a consent grant. Unknown or unrelated providers
// return an empty scope and false; their normal consent gates still apply.
func PolicyPending(provider string) (scope string, pending bool) {
	scope, known := nativeAdmissionScopes[provider]
	if !known {
		return "", false
	}
	return scope, errors.Is(readers.CheckAdmission(scope), readers.ErrPolicyPending)
}

func nativeAdmissionError(provider string) error {
	if _, pending := PolicyPending(provider); pending {
		return readers.ErrPolicyPending
	}
	return nil
}

func policyPendingSource(provider string) SourceStatus {
	return SourceStatus{Beta: true, Source: "native:" + provider, Status: "unavailable", Reason: "policy_pending", ErrorCode: "policy_pending"}
}
