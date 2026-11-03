// SPDX-License-Identifier: MIT
package quota

import (
	"github.com/modelplan/modelplan/cli/internal/consent"
	"time"
)

// NarrowMemberPaths binds a managed live reader to the exact existing account
// or profile reference. It never allocates an identity, opens a credential, or
// selects an arbitrary profile when the reference is absent or ambiguous.
// The caller must also match the member to a current consent-fenced rows view.
func NarrowMemberPaths(p Paths, provider, locator, subscription string) (Paths, bool) {
	if locator == "" && subscription == "" {
		return Paths{}, false
	}
	reader := nativeReaders[provider]
	if reader == nil || reader.Managed == nil {
		return p, true // The caller must establish uniqueness for non-managed routes.
	}
	grant, allowed := readerAllowed(p, provider)
	if !allowed || len(grant.Profiles) == 0 || len(grant.Profiles) > 16 {
		return Paths{}, false
	}
	state, err := loadReaderState(p.Cache, provider)
	if err != nil {
		return Paths{}, false
	}
	grantKey := lookupReaderHash(p.Cache, provider+":grant", grant.Generation)
	if grantKey == "" || state.GrantKey != grantKey {
		return Paths{}, false
	}
	matches := []ReaderProfile{}
	for _, profile := range grant.Profiles {
		key := lookupReaderHash(p.Cache, provider+":profile", profile.Root+"\x00"+profile.AccountFile)
		if key == "" || locator != "" && readerProfileLocator(p.Cache, provider, key) != locator {
			continue
		}
		if subscription != "" {
			matched := false
			for _, entry := range state.Entries {
				if entry.ProfileKey == key && entry.Account != nil && existingReaderSubscription(p.Cache, provider, entry.Account.Subscription) == subscription {
					matched = true
				}
			}
			if !matched {
				continue
			}
		}
		matches = append(matches, profile)
	}
	if len(matches) != 1 {
		return Paths{}, false
	}
	grants := make(map[string]ReaderGrant, len(p.ReaderAccess.Grants))
	for key, value := range p.ReaderAccess.Grants {
		grants[key] = value
	}
	grant.Profiles = matches
	grants[provider] = grant
	p.ReaderAccess = &ReaderAccess{Grants: grants}
	return p, true
}

// MemberProfilesAreScoped reports whether the live reader has independent
// profile selection. Other routes are safe only for an unambiguous row/route.
func MemberProfilesAreScoped(provider string) bool {
	reader := nativeReaders[provider]
	return reader != nil && reader.Managed != nil
}

// MemberBudgetReason classifies a known provider deadline without exposing
// provider data. Unknown/adaptive gates remain the conservative budget code.
func MemberBudgetReason(p Paths, scope string, at time.Time) string {
	definition, known := consent.Definition(scope)
	if !known {
		return "budget"
	}
	if scope == consent.ScopeCodexRuntimeUsage {
		if snapshot := loadAccount(p.Cache); snapshot != nil {
			if snapshot.Status != "ok" {
				return "backoff"
			}
			if !at.After(snapshot.ObservedAt.Add(AccountEvery)) {
				return "floor"
			}
		}
		return "budget"
	}
	if reader := nativeReaders[definition.Tool]; reader != nil && reader.Managed != nil {
		if state, err := loadReaderState(p.Cache, definition.Tool); err == nil && !state.AttemptedAt.IsZero() {
			if state.Failures > 0 {
				return "backoff"
			}
			if !at.After(state.AttemptedAt.Add(5 * time.Minute)) {
				return "floor"
			}
		}
	}
	if snapshot := loadNative(p.Cache); snapshot != nil {
		for _, entry := range snapshot.Providers {
			if entry.Provider == definition.Tool && entry.Status != "ok" {
				return "backoff"
			}
		}
	}
	return "budget"
}
