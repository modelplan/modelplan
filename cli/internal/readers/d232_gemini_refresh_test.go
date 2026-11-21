// SPDX-License-Identifier: MIT
package readers

import (
	"net/http"
	"net/url"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// D232: the opt-in Gemini token refresh is one pinned POST with a closed form body,
// the published Gemini CLI client and no bearer header.
func TestD232GeminiRefreshPin(t *testing.T) {
	form := func(extra map[string]string, drop ...string) string {
		v := url.Values{"client_id": {GeminiCLIClientID}, "client_secret": {GeminiCLIClientSecret}, "grant_type": {"refresh_token"}, "refresh_token": {"1//synthetic-refresh_token-0"}}
		for k, val := range extra {
			v.Set(k, val)
		}
		for _, k := range drop {
			v.Del(k)
		}
		return v.Encode()
	}
	for _, tc := range []struct {
		name, body string
		valid      bool
	}{
		{"pinned", form(nil), true},
		{"extra scope", form(map[string]string{"scope": "openid"}), false},
		{"authorization code grant", form(map[string]string{"grant_type": "authorization_code"}), false},
		{"other client", form(map[string]string{"client_id": "other.apps.googleusercontent.com"}), false},
		{"secret from elsewhere", form(map[string]string{"client_secret": "synthetic-client-secret-never-use"}), false},
		{"missing token", form(nil, "refresh_token"), false},
		{"token with space", form(map[string]string{"refresh_token": "a b"}), false},
		{"oversized token", form(map[string]string{"refresh_token": strings.Repeat("a", 2049)}), false},
		{"duplicate field", form(nil) + "&grant_type=refresh_token", false},
		{"json", `{"grant_type":"refresh_token"}`, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if validPOSTBody("gemini_refresh", []byte(tc.body)) != tc.valid {
				t.Fatal("body schema mismatch")
			}
		})
	}
	if CheckAdmission(consent.ScopeGeminiAccountUsageTokenRefresh) != nil {
		t.Fatal("approved refresh scope blocked")
	}
	r, _ := http.NewRequest(http.MethodPost, "https://oauth2.googleapis.com/token", strings.NewReader(form(nil)))
	r.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	r.Header.Set("Accept", "application/json")
	r.Header.Set("User-Agent", "modelplan")
	pin, ok := requestSet(consent.ScopeGeminiAccountUsageTokenRefresh, r)
	if !ok || !pin.validHeaders(r) || !pin.validBody(r) || pin.limit != 1 {
		t.Fatal("pinned refresh rejected")
	}
	r.Header.Set("Authorization", "Bearer synthetic")
	if pin.validHeaders(r) {
		t.Fatal("bearer header accepted on the token endpoint")
	}
	r.Header.Del("Authorization")
	r.Header.Set("Content-Type", "application/json")
	if pin.validHeaders(r) {
		t.Fatal("JSON framing accepted for the form body")
	}
	for _, endpoint := range []string{"https://oauth2.googleapis.com/revoke", "https://accounts.google.com/o/oauth2/token", "https://oauth2.googleapis.com/token?x=1"} {
		r, _ := http.NewRequest(http.MethodPost, endpoint, strings.NewReader(form(nil)))
		if _, ok := requestSet(consent.ScopeGeminiAccountUsageTokenRefresh, r); ok {
			t.Fatalf("%s accepted", endpoint)
		}
	}
	// The saved-login scope cannot reach the token endpoint, nor the refresh scope Code Assist.
	if _, ok := requestSet(consent.ScopeGeminiAccountUsageSavedLogin, r); ok {
		t.Fatal("saved-login scope reached the token endpoint")
	}
	q, _ := http.NewRequest(http.MethodPost, "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota", strings.NewReader(`{"project":"p"}`))
	if _, ok := requestSet(consent.ScopeGeminiAccountUsageTokenRefresh, q); ok {
		t.Fatal("refresh scope reached Code Assist")
	}
}
