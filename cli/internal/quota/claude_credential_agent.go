// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"sync"
	"time"
)

const claudeAppRequired = "Open the app, or use a credentials file"

// Credential callbacks are a capability boundary. Only this closed vocabulary
// reaches retained state, diagnostics and rows; arbitrary callback errors never do.
func claudeCredentialFailure(status string) readerOutcome {
	next := "Allow in Settings"
	switch status {
	case "canceled", "denied", "not-found", "unavailable", "keychain-confirmation-needed", "consent-required", "busy":
	case "not_found":
		status = "not-found"
	case "interaction_required", "confirmation-needed":
		status = "keychain-confirmation-needed"
	case "timeout":
		status = "keychain-confirmation-needed"
	case "app_required":
		status, next = "keychain-confirmation-needed", claudeAppRequired
	default:
		status = "unavailable"
	}
	return readerOutcome{Entry: readerEntry{Status: status, NextStep: next, CredentialReadState: status}}
}

// WithClaudeCredential supplies one app result to one reader invocation. The
// caller releases it even if the remote budget is closed and no reader runs.
// The returned paths retain the original admission, locks and shared budgets.
func WithClaudeCredential(p Paths, outcome, token string, expiresAt *time.Time) (Paths, func()) {
	status := outcome
	var payload []byte
	if outcome == "ok" {
		expires := time.Now().Add(30 * time.Second)
		if expiresAt != nil {
			expires = *expiresAt
		}
		if token == "" || len(token) > 16<<10 || strings.ContainsAny(token, "\r\n") || !expires.After(time.Now()) {
			status = "unavailable"
		} else {
			payload, _ = json.Marshal(map[string]any{"claudeAiOauth": map[string]any{"accessToken": token, "expiresAt": expires.UnixMilli(), "scopes": []string{"user:profile"}}})
			status = ""
		}
	}
	var mu sync.Mutex
	used := false
	release := func() { mu.Lock(); defer mu.Unlock(); clear(payload); payload = nil; used = true }
	grants := map[string]ReaderGrant{}
	if p.ReaderAccess != nil {
		for provider, g := range p.ReaderAccess.Grants {
			grants[provider] = g
		}
	}
	if g, ok := grants["claude"]; ok {
		g.Credential = func(ctx context.Context) ([]byte, string) {
			mu.Lock()
			defer mu.Unlock()
			if used || ctx.Err() != nil || !g.Keychain || (g.StillValid != nil && !g.StillValid()) {
				return nil, "unavailable"
			}
			used = true
			value := append([]byte(nil), payload...)
			clear(payload)
			payload = nil
			return value, status
		}
		grants["claude"] = g
	}
	p.ReaderAccess = &ReaderAccess{Grants: grants}
	return p, release
}

// recordClaudeCredentialOutcome updates the actual credential-read fact without
// changing the retained value's stamp or the remote attempt/budget. The caller
// holds ReaderLock, and Publish fences the status against a concurrent revoke.
func recordClaudeCredentialOutcome(p Paths, g ReaderGrant, profileKey, status string, now time.Time) error {
	unlock, ok := lockFile(readerPath(p.Cache, "claude")+".lock", now, time.Minute)
	if !ok {
		return errors.New("another provider read is running")
	}
	defer unlock()
	s, err := loadReaderState(p.Cache, "claude")
	if err != nil {
		return err
	}
	fact := claudeCredentialFailure(status).Entry
	s.GrantKey = readerHash(p.Cache, "claude:grant", g.Generation)
	if s.GrantKey == "" {
		return errors.New("identity key unavailable")
	}
	found := false
	for i := range s.Entries {
		e := &s.Entries[i]
		if e.ProfileKey == profileKey {
			if status == "ok" {
				if e.CredentialReadState != "" {
					e.Status = ""
					if e.Account != nil {
						e.Status = "ok"
					}
					if e.LastFailure != nil && strings.HasPrefix(e.LastFailure.Code, "keychain_") {
						e.LastFailure = nil
					}
				}
				e.CredentialReadState, e.NextStep = "", ""
			} else {
				e.Status, e.NextStep, e.CredentialReadState = fact.Status, fact.NextStep, fact.CredentialReadState
			}
			found = true
		}
	}
	if !found && status != "ok" {
		if len(s.Entries) >= 16 {
			return errors.New("reader cache unavailable")
		}
		fact.ProfileKey = profileKey
		s.Entries = append(s.Entries, fact)
	}
	if g.StillValid != nil && !g.StillValid() {
		return errors.New("reader consent changed")
	}
	if g.Publish != nil {
		return g.Publish(func() error { return saveReaderState(p.Cache, s) })
	}
	return saveReaderState(p.Cache, s)
}
