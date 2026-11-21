// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/readers"
)

// geminiExpiredLogin rewrites the synthetic login so its access token lapsed an hour ago.
func geminiExpiredLogin(t *testing.T, p Paths) string {
	t.Helper()
	root := p.ReaderAccess.Grants["gemini"].Profiles[0].Root
	claims, _ := json.Marshal(map[string]any{"iss": "https://accounts.google.com", "sub": "synthetic-google-subject", "exp": geminiNow.Add(-time.Hour).Unix()})
	id := "e30." + base64.RawURLEncoding.EncodeToString(claims) + ".synthetic-signature"
	b, _ := json.Marshal(map[string]any{"access_token": "synthetic-google-access", "expiry_date": geminiNow.Add(-time.Hour).UnixMilli(), "id_token": id, "refresh_token": "synthetic-google-refresh-never-use", "client_secret": "synthetic-client-secret-never-use"})
	path := filepath.Join(root, "oauth_creds.json")
	if err := os.WriteFile(path, b, 0o600); err != nil {
		t.Fatal(err)
	}
	return path
}

// geminiRefreshServer is a fake Google token endpoint plus Code Assist. It records each path.
func geminiRefreshServer(t *testing.T, mode *string, paths *[]string) {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		*paths = append(*paths, r.Host+r.URL.Path)
		if r.URL.Path == "/token" {
			if r.Header.Get("Authorization") != "" || r.Header.Get("Content-Type") != "application/x-www-form-urlencoded" || r.Method != http.MethodPost {
				t.Error("token request carries a bearer or the wrong framing")
			}
			if err := r.ParseForm(); err != nil {
				t.Error(err)
			}
			if len(r.PostForm) != 4 || r.PostForm.Get("grant_type") != "refresh_token" || r.PostForm.Get("refresh_token") != "synthetic-google-refresh-never-use" ||
				r.PostForm.Get("client_id") != readers.GeminiCLIClientID || r.PostForm.Get("client_secret") != readers.GeminiCLIClientSecret {
				t.Error("token request is not the pinned refresh grant (the file's client secret must never be used)")
			}
			switch *mode {
			case "revoked":
				w.WriteHeader(400)
				_, _ = w.Write([]byte(`{"error":"invalid_grant","error_description":"secret provider text"}`))
				return
			case "bad-reply":
				_, _ = w.Write([]byte(`{"access_token":"x y","token_type":"Bearer","expires_in":3599}`))
				return
			}
			claims, _ := json.Marshal(map[string]any{"iss": "https://accounts.google.com", "sub": "synthetic-google-subject", "exp": geminiNow.Add(time.Hour).Unix()})
			_ = json.NewEncoder(w).Encode(map[string]any{"access_token": "synthetic-refreshed-bearer", "token_type": "Bearer", "expires_in": 3599, "id_token": "e30." + base64.RawURLEncoding.EncodeToString(claims) + ".sig"})
			return
		}
		if r.Header.Get("Authorization") != "Bearer synthetic-refreshed-bearer" {
			t.Error("Code Assist did not get the refreshed in-memory token")
		}
		name := "assist.json"
		if r.URL.Path == "/v1internal:retrieveUserQuota" {
			name = "quota.json"
		}
		b, err := os.ReadFile(filepath.Join("testdata", "gemini", name))
		if err != nil {
			t.Error(err)
		}
		_, _ = w.Write(b)
	}))
	oldClient := nativeClient
	nativeClient = readerFixtureClient(t, srv, "cloudcode-pa.googleapis.com", "oauth2.googleapis.com")
	t.Cleanup(func() { srv.Close(); nativeClient = oldClient })
	geminiTokens.Lock()
	geminiTokens.values = map[string]geminiToken{}
	geminiTokens.Unlock()
}

func TestD232GeminiLapsedTokenWithoutRefreshConsentMakesNoRequest(t *testing.T) {
	p := geminiTestPaths(t)
	geminiExpiredLogin(t, p)
	mode, paths := "ok", []string{}
	geminiRefreshServer(t, &mode, &paths)
	if err := RefreshNative(context.Background(), p, geminiNow); err != nil {
		t.Fatal(err)
	}
	s, _ := loadReaderState(p.Cache, "gemini")
	if len(paths) != 0 || s.Entries[0].Status != "expired" {
		t.Fatalf("paths %v entry %+v", paths, s.Entries[0])
	}
}

func TestD232GeminiRefreshesLapsedTokenInMemoryOnly(t *testing.T) {
	p := geminiTestPaths(t)
	g := p.ReaderAccess.Grants["gemini"]
	g.TokenRefresh = true
	p.ReaderAccess.Grants["gemini"] = g
	path := geminiExpiredLogin(t, p)
	before, _ := os.ReadFile(path)
	infoBefore, _ := os.Stat(path)
	mode, paths := "ok", []string{}
	geminiRefreshServer(t, &mode, &paths)
	if err := RefreshNative(context.Background(), p, geminiNow); err != nil {
		t.Fatal(err)
	}
	if strings.Join(paths, " ") != "oauth2.googleapis.com/token cloudcode-pa.googleapis.com/v1internal:loadCodeAssist cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota" {
		t.Fatal(paths)
	}
	s, _ := loadReaderState(p.Cache, "gemini")
	if a := s.Entries[0].Account; s.Entries[0].Status != "ok" || a == nil || len(a.Windows) != 2 || a.Subscription == nil {
		t.Fatalf("refreshed read %+v", s.Entries[0])
	}
	after, _ := os.ReadFile(path)
	infoAfter, _ := os.Stat(path)
	if string(before) != string(after) || infoBefore.Mode() != infoAfter.Mode() || !infoBefore.ModTime().Equal(infoAfter.ModTime()) {
		t.Fatal("the Gemini CLI login file was written")
	}
	assertGeminiCachePrivate(t, p.Cache)
	assertNotInCache(t, p.Cache, "synthetic-refreshed-bearer")
	// The next due read reuses the in-memory token: no second exchange.
	if err := RefreshNative(context.Background(), p, geminiNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if len(paths) != 4 || paths[3] != "cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota" {
		t.Fatalf("token not reused: %v", paths)
	}
	// A new grant generation (consent change) drops the in-memory token.
	g.Generation = "synthetic-grant-002"
	p.ReaderAccess.Grants["gemini"] = g
	if err := RefreshNative(context.Background(), p, geminiNow.Add(20*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(strings.Join(paths[4:], " "), "oauth2.googleapis.com/token") {
		t.Fatalf("token survived a consent change: %v", paths)
	}
	// Revoking only the refresh extension keeps the saved-login readings.
	if err := EraseScope(p, consent.ScopeGeminiAccountUsageTokenRefresh, true); err != nil {
		t.Fatal(err)
	}
	if s, _ := loadReaderState(p.Cache, "gemini"); len(s.Entries) == 0 || s.Entries[0].Account == nil {
		t.Fatal("revoking the refresh extension erased the saved-login reading")
	}
}

func TestD232GeminiRefreshFailuresStopBeforeCodeAssist(t *testing.T) {
	for _, c := range []struct{ mode, status, code string }{{"revoked", "expired", "http_401"}, {"bad-reply", "unsupported_schema", "schema_changed"}} {
		t.Run(c.mode, func(t *testing.T) {
			p := geminiTestPaths(t)
			g := p.ReaderAccess.Grants["gemini"]
			g.TokenRefresh = true
			p.ReaderAccess.Grants["gemini"] = g
			geminiExpiredLogin(t, p)
			mode, paths := c.mode, []string{}
			geminiRefreshServer(t, &mode, &paths)
			if err := RefreshNative(context.Background(), p, geminiNow); err != nil {
				t.Fatal(err)
			}
			s, _ := loadReaderState(p.Cache, "gemini")
			if strings.Join(paths, " ") != "oauth2.googleapis.com/token" || s.Entries[0].Status != c.status || s.Entries[0].ErrorCode != c.code {
				t.Fatalf("paths %v entry %+v", paths, s.Entries[0])
			}
			assertGeminiCachePrivate(t, p.Cache)
			assertNotInCache(t, p.Cache, "secret provider text")
		})
	}
}

func assertNotInCache(t *testing.T, cache, canary string) {
	t.Helper()
	_ = filepath.WalkDir(cache, func(path string, d os.DirEntry, err error) error {
		if err == nil && !d.IsDir() {
			if b, _ := os.ReadFile(path); strings.Contains(string(b), canary) {
				t.Fatalf("%q persisted in %s", canary, path)
			}
		}
		return nil
	})
}
