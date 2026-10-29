// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// CredentialBroker binds the app operation to the existing production reader.
// Bind Request to Server.ReadCredential before Serve; PathsFor is the original
// production constructor, never the wrapped Paths method. It stores no tokens.
type CredentialBroker struct {
	Request           func(context.Context, CredentialNeed) (wire.CredentialResult, error)
	PathsFor          func(consent.Admission) quota.Paths
	Changed           func()
	Offline, ReadOnly bool
}

// Paths supplies a noninteractive callback; the managed reader invokes it only
// after reserving the shared budget. It never issues a second remote reading.
func (b *CredentialBroker) Paths(a consent.Admission) quota.Paths {
	p := b.PathsFor(a)
	if p.ReaderAccess == nil {
		return p
	}
	grants := map[string]quota.ReaderGrant{}
	for provider, g := range p.ReaderAccess.Grants {
		if provider == "claude" {
			g.Credential = func(ctx context.Context) ([]byte, string) {
				if b.Request == nil || b.Offline || b.ReadOnly || !credentialAdmission(a) {
					return nil, "app_required"
				}
				result, err := b.Request(ctx, CredentialNeed{Provider: "claude", Scope: consent.ScopeClaudeAccountUsageSavedLogin})
				if err != nil {
					if ctx.Err() != nil {
						return nil, "timeout"
					}
					return nil, "unavailable"
				}
				defer func() { result.AccessToken = nil }()
				if !validCredential(result) || !credentialCurrent(a) {
					return nil, "unavailable"
				}
				token := ""
				if result.AccessToken != nil {
					token = *result.AccessToken
				}
				paths, release := quota.WithClaudeCredential(p, string(result.Outcome), token, result.ExpiresAt)
				defer release()
				grant, ok := paths.ReaderAccessGrant("claude")
				if !ok || grant.Credential == nil {
					return nil, "unavailable"
				}
				return grant.Credential(ctx)
			}
		}
		grants[provider] = g
	}
	p.ReaderAccess = &quota.ReaderAccess{Grants: grants}
	return p
}

// AcceptCredential consumes the explicit grant's operation. The result itself
// is transient; status and measurements use the reader's fenced writers. The
// interactive operation has already happened even when the remote budget is shut.
func (b *CredentialBroker) AcceptCredential(ctx context.Context, stamp Stamp, need CredentialNeed, result wire.CredentialResult) error {
	defer func() {
		result.AccessToken = nil
		if b.Changed != nil {
			b.Changed()
		}
	}()
	if !validCredential(result) || need.Provider != "claude" || need.Scope != consent.ScopeClaudeAccountUsageSavedLogin || !need.Interactive || b.PathsFor == nil {
		return ProtocolError{wire.CodeCredentialRejected}
	}
	a := consent.Capture()
	if credentialStamp(a) != stamp || !credentialAdmission(a) || !credentialCurrent(a) {
		return ProtocolError{wire.CodeCredentialRejected}
	}
	if b.Offline || b.ReadOnly {
		return nil
	}
	token := ""
	if result.AccessToken != nil {
		token = *result.AccessToken
	}
	p, release := quota.WithClaudeCredential(b.PathsFor(a), string(result.Outcome), token, result.ExpiresAt)
	defer release()
	return quota.KeychainGrantRead(ctx, p, "claude", time.Now())
}
func credentialStamp(a consent.Admission) Stamp {
	f := a.Fence()
	return Stamp{Epoch: f.StoreEpoch, Generation: f.Generation}
}
func credentialAdmission(a consent.Admission) bool {
	return a.Allows("claude", consent.Credential) && a.KeychainStatus("claude") == "allowed"
}
func credentialCurrent(a consent.Admission) bool {
	current := consent.Capture()
	return current.Fence() == a.Fence() && credentialAdmission(current)
}
