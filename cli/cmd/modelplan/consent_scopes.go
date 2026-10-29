// SPDX-License-Identifier: MIT
package main

import (
	"errors"
	"io"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func grantScopes(r consentRequest, stdout io.Writer, st *store.Store) int {
	grant := consent.Grant{RequestID: r.RequestID, ExpectStoreEpoch: r.ExpectStoreEpoch, ExpectGeneration: *r.ExpectGeneration, ConsentTextVersion: *r.ConsentTextVersion, Allow: r.Allow, Deny: r.Deny, Forget: r.Forget, Keychain: r.Keychain}
	report := detection(st)
	tools := map[string]detect.Tool{}
	for _, t := range report.Tools {
		if t.Detected {
			tools[t.ProviderID] = t
		}
	}
	receipt, err := consent.ApplyGrant(consent.Path(), grant, consent.GrantHooks{
		Admit: func(d consent.ScopeDefinition) (consent.Record, error) {
			t, ok := tools[d.Tool]
			if !ok {
				return consent.Record{}, errors.New("unknown_tool")
			}
			if t.Preferred != "native" || consentNativeOff() {
				return consent.Record{}, errors.New("reader_unavailable")
			}
			// First-batch POST paths remain disabled until their cards are approved.
			if scope, pending := quota.PolicyPending(d.Tool); pending && scope == d.ID {
				return consent.Record{}, errors.New("policy_pending")
			}
			record := consent.Record{ReaderID: t.ReaderID, Backend: t.Preferred}
			if d.Class == consent.ExplicitKey {
				record.KeyEnv = map[string]string{"kimi": "KIMI_CODE_API_KEY", "zai": "Z_AI_API_KEY", "opencodego": "OPENCODE_API_KEY", "minimax": "MINIMAX_CODING_API_KEY"}[d.Tool]
			}
			return record, nil
		},
		Cleanup: func(scope string, forget bool) error { return cleanupScope(st, scope, forget) },
	})
	if err != nil {
		code := err.Error()
		switch code {
		case "consent_stale", "request_mismatch", "invalid_request", "stale_generation", "stale_consent_text", "readers_off", "unknown_tool", "unknown_scope", "reader_unavailable", "keychain_not_supported", "policy_pending":
		default:
			code = "consent_unavailable"
		}
		return consentFailure(stdout, code)
	}
	if printJSON(stdout, receipt) != 0 || receipt.Code != "ok" {
		return exitErr
	}
	if !receipt.Replayed && r.Keychain[consent.ScopeClaudeAccountUsageSavedLogin] == "allow" {
		keychainGrantRead(consentRequest{Allow: []string{"claude"}, Keychain: map[string]string{"claude": "allow"}}, st)
	}
	return 0
}

func cleanupScope(st *store.Store, scope string, forget bool) error {
	if !strings.Contains(scope, ".") {
		state, err := consent.Load(consent.Path())
		if err != nil {
			return err
		}
		if state.Tools[scope].BrowserCookieCache {
			return errors.New("cookie cleanup requires explicit action")
		}
		return forgetConsentTool(st, scope, false)
	}
	return quota.EraseScope(quotaPaths(st), scope, forget)
}
