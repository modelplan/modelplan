package quota

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestGrokChangedInvalidSessionNeverInheritsAccount(t *testing.T) {
	for _, mode := range []string{"expired-B", "unsupported-mode-B", "foreign-issuer-B", "scope-mismatch-B", "missing-user-B", "missing-slot-B", "malformed-B"} {
		t.Run(mode, func(t *testing.T) {
			p := grokTestPaths(t)
			serverMode := "ok"
			hits := 0
			grokTestServer(t, &serverMode, &hits)
			if err := RefreshNative(context.Background(), p, grokNow); err != nil {
				t.Fatal(err)
			}
			root := p.ReaderAccess.Grants["grok"].Profiles[0].Root
			auth := grokAuth{Key: "synthetic-B-access", Mode: "oidc", User: "synthetic-B-user", Issuer: "https://auth.x.ai", Client: grokDefaultClient, Expires: grokNow.Add(time.Hour).Format(time.RFC3339)}
			switch mode {
			case "expired-B":
				auth.Expires = grokNow.Add(-time.Minute).Format(time.RFC3339)
			case "unsupported-mode-B":
				auth.Mode = "api_key"
			case "foreign-issuer-B":
				auth.Issuer = "https://synthetic.invalid"
			case "scope-mismatch-B":
				auth.Client = "synthetic-other-client"
			case "missing-user-B":
				auth.User = ""
			}
			writeGrokAuth(t, root, auth)
			if mode == "missing-slot-B" {
				if err := os.WriteFile(filepath.Join(root, "auth.json"), []byte(`{}`), 0600); err != nil {
					t.Fatal(err)
				}
			}
			if mode == "malformed-B" {
				if err := os.WriteFile(filepath.Join(root, "auth.json"), []byte(`{`), 0600); err != nil {
					t.Fatal(err)
				}
			}
			if err := RefreshNative(context.Background(), p, grokNow.Add(time.Minute)); err != nil {
				t.Fatal(err)
			}
			if hits != 1 {
				t.Fatal("account switch bypassed floor")
			}
			if err := RefreshNative(context.Background(), p, grokNow.Add(5*time.Minute)); err != nil {
				t.Fatal(err)
			}
			s, _ := loadReaderState(p.Cache, "grok")
			if hits != 1 || s.Entries[0].Account != nil || s.Entries[0].Metadata.CredentialKey != "" {
				t.Fatal("invalid B inherited A quota/wallet or made a request")
			}
			r := Report{}
			applyManaged(&r, p, "grok", grokNow.Add(6*time.Minute))
			if len(r.Accounts) != 0 {
				t.Fatal("A numbers still exposed")
			}
		})
	}
}

func TestGrokSameExpiredGenerationRetainsCaptureAndTiming(t *testing.T) {
	p := grokTestPaths(t)
	mode := "ok"
	hits := 0
	grokTestServer(t, &mode, &hits)
	if err := RefreshNative(context.Background(), p, grokNow); err != nil {
		t.Fatal(err)
	}
	writeGrokAuth(t, p.ReaderAccess.Grants["grok"].Profiles[0].Root, grokAuth{Key: "synthetic-grok-access", Mode: "oidc", User: "synthetic-grok-user", Issuer: "https://auth.x.ai", Client: grokDefaultClient, Expires: grokNow.Add(-time.Minute).Format(time.RFC3339)})
	if err := RefreshNative(context.Background(), p, grokNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	s, _ := loadReaderState(p.Cache, "grok")
	if hits != 1 || s.Entries[0].Status != "expired" || s.Entries[0].Account == nil || s.Entries[0].Account.Credits == nil || !s.Entries[0].Account.ObservedAt.Equal(grokNow) || NativeDue(p, grokNow.Add(6*time.Minute)) {
		t.Fatal("same-generation last-good capture or timing lost")
	}
}

func TestGrokOIDCTablesRequireMatchingBase(t *testing.T) {
	for _, tc := range []struct {
		name, config, oidcIssuer, oidcClient, oauthIssuer, oauthClient string
		allowed                                                        bool
	}{
		{name: "oidc-client-only", config: "[grok_com_config.oidc]\nclient_id='" + grokDefaultClient + "'\n"},
		{name: "oidc-issuer-only", config: "[grok_com_config.oidc]\nissuer='https://auth.x.ai'\n"},
		{name: "oidc-empty", config: "[grok_com_config.oidc]\n"},
		{name: "oidc-cannot-use-oauth2-base", config: "[grok_com_config.oidc]\nclient_id='" + grokDefaultClient + "'\n", oauthIssuer: "https://auth.x.ai", oauthClient: grokDefaultClient},
		{name: "oidc-partial-over-env", config: "[grok_com_config.oidc]\nclient_id='" + grokDefaultClient + "'\n", oidcIssuer: "https://auth.x.ai", oidcClient: "synthetic-base-client", allowed: true},
		{name: "oidc-issuer-over-env", config: "[grok_com_config.oidc]\nissuer='https://auth.x.ai'\n", oidcIssuer: "https://synthetic.invalid", oidcClient: grokDefaultClient, allowed: true},
		{name: "oidc-complete", config: "[grok_com_config.oidc]\nissuer='https://auth.x.ai'\nclient_id='" + grokDefaultClient + "'\n", allowed: true},
		{name: "oauth2-partial-over-default", config: "[grok_com_config.oauth2]\nclient_id='" + grokDefaultClient + "'\n", allowed: true},
		{name: "oauth2-cannot-use-oidc-base", config: "[grok_com_config.oauth2]\nclient_id='" + grokDefaultClient + "'\n", oidcIssuer: "https://auth.x.ai", oidcClient: grokDefaultClient},
		{name: "oidc-explicit-empty-not-inherited", config: "[grok_com_config.oidc]\nissuer=''\n", oidcIssuer: "https://auth.x.ai", oidcClient: grokDefaultClient},
		{name: "oidc-invalid-field-type", config: "[grok_com_config.oidc]\nissuer=12\nclient_id='" + grokDefaultClient + "'\n"},
		{name: "alias-incomplete", config: "[auth.oidc]\nclient_id='" + grokDefaultClient + "'\n"},
		{name: "alias-complete", config: "[auth.oidc]\nissuer='https://auth.x.ai'\nclient_id='" + grokDefaultClient + "'\n", allowed: true},
		{name: "explicit-table-wins-alias-without-deep-merge", config: "[auth.oidc]\nissuer='https://auth.x.ai'\nclient_id='" + grokDefaultClient + "'\n[grok_com_config.oidc]\nclient_id='" + grokDefaultClient + "'\n"},
		{name: "alias-helper-is-not-launched", config: "[auth]\nauth_provider_command='synthetic-never-launch'\n"},
		{name: "partial-env-is-unsupported", oidcClient: grokDefaultClient},
	} {
		t.Run(tc.name, func(t *testing.T) {
			p := grokTestPaths(t)
			mode := "ok"
			hits := 0
			grokTestServer(t, &mode, &hits)
			root := p.ReaderAccess.Grants["grok"].Profiles[0].Root
			if err := os.WriteFile(filepath.Join(root, "config.toml"), []byte(tc.config), 0600); err != nil {
				t.Fatal(err)
			}
			t.Setenv("GROK_OIDC_ISSUER", tc.oidcIssuer)
			t.Setenv("GROK_OIDC_CLIENT_ID", tc.oidcClient)
			t.Setenv("GROK_OAUTH2_ISSUER", tc.oauthIssuer)
			t.Setenv("GROK_OAUTH2_CLIENT_ID", tc.oauthClient)
			if err := RefreshNative(context.Background(), p, grokNow); err != nil {
				t.Fatal(err)
			}
			expected := 0
			if tc.allowed {
				expected = 1
			}
			if hits != expected {
				t.Fatal("provider table borrowed wrong base or valid table rejected", hits)
			}
			s, _ := loadReaderState(p.Cache, "grok")
			if tc.allowed != (s.Entries[0].Account != nil) {
				t.Fatal("invalid table exposed a reading")
			}
		})
	}
}
