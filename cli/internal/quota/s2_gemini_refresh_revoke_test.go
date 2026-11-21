// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

// Sampling 11-21 S2 (#928): revoking only the D232 token-refresh extension, through the normal
// grant transaction, must keep the still-fresh saved-login reading visible and must not cause a
// token exchange. Production admission is rebuilt from the real consent store after the revoke.
func TestS2RevokingGeminiRefreshKeepsTheSavedLoginReading(t *testing.T) {
	base := geminiTestPaths(t)
	s, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	hooks := consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) {
		return consent.Record{ReaderID: "native:gemini", Backend: "native"}, nil
	}, Cleanup: func(scope string, forget bool) error { return EraseScope(base, scope, forget) }}
	grant := func(id string, generation uint64, allow, deny []string) {
		t.Helper()
		receipt, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: id, ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: generation, ConsentTextVersion: consent.TextVersion, Allow: allow, Deny: deny}, hooks)
		if err != nil || receipt.Code != "ok" {
			t.Fatal(id, receipt, err)
		}
	}
	grant("saved-login", s.Generation, []string{consent.ScopeGeminiAccountUsageSavedLogin}, nil)
	grant("refresh", s.Generation+1, []string{consent.ScopeGeminiAccountUsageTokenRefresh}, nil)
	production := func() Paths {
		t.Helper()
		p := ProductionPaths(base.Cache, "1.0.0")
		g, ok := p.ReaderAccess.Grants["gemini"]
		if !ok || !g.SavedLogin {
			t.Fatal("production admission has no Gemini saved-login grant", p.ReaderAccess.Grants)
		}
		p.CodexBarFile, p.ConnectionsFile = base.CodexBarFile, base.ConnectionsFile
		return p
	}
	p := production()
	if !p.ReaderAccess.Grants["gemini"].TokenRefresh {
		t.Fatal("separate refresh opt-in not admitted")
	}
	mode, paths := "ok", []string{}
	geminiServer(t, &mode, &paths)
	if err := RefreshNative(context.Background(), p, geminiNow); err != nil {
		t.Fatal(err)
	}
	if len(paths) != 2 {
		t.Fatal("initial read", paths)
	}
	grant("revoke-refresh", s.Generation+2, nil, []string{consent.ScopeGeminiAccountUsageTokenRefresh})
	p = production()
	if p.ReaderAccess.Grants["gemini"].TokenRefresh {
		t.Fatal("refresh still admitted after its revoke")
	}
	visible := func(at time.Time) {
		t.Helper()
		in := rows.Input{Now: at}
		AppendManagedRows(&in, p)
		if len(in.Accounts) != 1 || len(in.Profiles) != 1 || in.Profiles[0].GenerationChanged {
			t.Fatalf("saved-login reading hidden after revoking only refresh: accounts %d profiles %+v", len(in.Accounts), in.Profiles)
		}
	}
	visible(geminiNow.Add(time.Minute))
	// The next due read keeps the reading and uses the still-valid saved token: no token POST.
	if err := RefreshNative(context.Background(), p, geminiNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	for _, path := range paths {
		if strings.Contains(path, "token") {
			t.Fatal("token exchange after the refresh revoke", paths)
		}
	}
	visible(geminiNow.Add(6 * time.Minute))
	// Revoking the saved-login scope itself still discards the reading.
	grant("revoke-login", s.Generation+3, nil, []string{consent.ScopeGeminiAccountUsageSavedLogin})
	if g, ok := ProductionPaths(base.Cache, "1.0.0").ReaderAccess.Grants["gemini"]; ok && g.SavedLogin {
		t.Fatal("saved-login grant survived its revoke")
	}
	if st, _ := loadReaderState(base.Cache, "gemini"); len(st.Entries) != 0 && st.Entries[0].Account != nil {
		t.Fatal("saved-login revoke kept the reading")
	}
}
