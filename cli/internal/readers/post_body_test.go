// SPDX-License-Identifier: MIT
package readers

import (
	"net/http"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// These tests validate dormant pins directly; they never approve a POST scope
// or substitute the production admission policy.
func TestDormantPOSTBodySchemas(t *testing.T) {
	for _, tc := range []struct {
		kind, body string
		valid      bool
	}{
		{"cursor", `{}`, true}, {"cursor", ` {}`, false}, {"cursor", `null`, false}, {"cursor", `{"refresh":true}`, false},
		{"gemini_load", `{"mode":"HEALTH_CHECK","metadata":{"ideType":"GEMINI_CLI","pluginType":"GEMINI"}}`, true},
		{"gemini_load", `{"mode":"HEALTH_CHECK","metadata":{"ideType":"GEMINI_CLI","pluginType":"GEMINI"},"cloudaicompanionProject":"projects/example-1"}`, true},
		{"gemini_load", `{"mode":"ONBOARD","metadata":{"ideType":"GEMINI_CLI","pluginType":"GEMINI"}}`, false},
		{"gemini_load", `{"mode":"HEALTH_CHECK","mode":"HEALTH_CHECK","metadata":{"ideType":"GEMINI_CLI","pluginType":"GEMINI"}}`, false},
		{"gemini_load", `{"mode":"HEALTH_CHECK","metadata":{"ideType":"GEMINI_CLI","ideType":"GEMINI_CLI","pluginType":"GEMINI"}}`, false},
		{"gemini_load", `{"mode":"HEALTH_CHECK","metadata":{"ideType":"GEMINI_CLI","pluginType":"GEMINI","userAgent":"extra"}}`, false},
		{"gemini_load", `{"mode":"HEALTH_CHECK","metadata":null}`, false},
		{"gemini_load", `{"mode":"HEALTH_CHECK","metadata":{"ideType":"GEMINI_CLI","pluginType":"GEMINI"},"cloudaicompanionProject":null}`, false},
		{"gemini_quota", `{"project":"example-1"}`, true}, {"gemini_quota", `{"project":"p"} {}`, false},
		{"gemini_quota", `{"project":""}`, false}, {"gemini_quota", `{"project":null}`, false}, {"gemini_quota", `{"project":"p","userAgent":"extra"}`, false},
		{"gemini_quota", `{"project":"p","project":"q"}`, false}, {"gemini_quota", `{"project":"p?extra"}`, false},
		{"gemini_quota", `{"project":"` + strings.Repeat("p", 201) + `"}`, false},
	} {
		t.Run(tc.kind+"/"+tc.body, func(t *testing.T) {
			if validPOSTBody(tc.kind, []byte(tc.body)) != tc.valid {
				t.Fatal("body schema mismatch")
			}
		})
	}
}

func TestDormantPOSTPinsAndCredentialPlacement(t *testing.T) {
	for _, tc := range []struct {
		scope, endpoint, body string
		headers               http.Header
	}{
		{consent.ScopeGeminiAccountUsageSavedLogin, "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist", `{"mode":"HEALTH_CHECK","metadata":{"ideType":"GEMINI_CLI","pluginType":"GEMINI"}}`, http.Header{"Authorization": {"Bearer synthetic"}}},
		{consent.ScopeGeminiAccountUsageSavedLogin, "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota", `{"project":"synthetic-project"}`, http.Header{"Authorization": {"Bearer synthetic"}}},
		{consent.ScopeCursorAccountUsageSavedLogin, "https://cursor.com/api/dashboard/get-plan-info", `{}`, http.Header{"Cookie": {"WorkosCursorSessionToken=synthetic"}, "Origin": {"https://cursor.com"}}},
		{consent.ScopeCursorAccountUsageSavedLogin, "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage", `{}`, http.Header{"Authorization": {"Bearer synthetic"}, "Connect-Protocol-Version": {"1"}}},
	} {
		t.Run(tc.endpoint, func(t *testing.T) {
			r, err := http.NewRequest("POST", tc.endpoint, strings.NewReader(tc.body))
			if err != nil {
				t.Fatal(err)
			}
			r.Header = tc.headers.Clone()
			r.Header.Set("Content-Type", "application/json")
			r.Header.Set("Accept", "application/json")
			r.Header.Set("User-Agent", "modelplan")
			pin, ok := requestSet(tc.scope, r)
			if !ok || !pin.validHeaders(r) || !pin.validBody(r) {
				t.Fatal("reviewed request rejected")
			}
			if CheckAdmission(tc.scope) != ErrPolicyPending {
				t.Fatal("dormant pin enabled scope")
			}
			r.Header.Add("User-Agent", "extra")
			if pin.validHeaders(r) {
				t.Fatal("duplicate header accepted")
			}
			r.Header.Set("User-Agent", "modelplan")
			r.Header.Del("Accept")
			if pin.validHeaders(r) {
				t.Fatal("missing pinned header accepted")
			}
			r.Header.Set("Accept", "application/json")
			r.Header.Set("X-Unreviewed-Identity", "synthetic")
			if pin.validHeaders(r) {
				t.Fatal("extra header accepted")
			}
			r.Header.Del("X-Unreviewed-Identity")
			if tc.scope == consent.ScopeCursorAccountUsageSavedLogin {
				if pin.stage == 0 {
					r.Header.Set("Authorization", "Bearer synthetic")
				} else {
					r.Header.Set("Cookie", "WorkosCursorSessionToken=synthetic")
				}
				if pin.validHeaders(r) {
					t.Fatal("credential forwarded between Cursor authorities")
				}
			}
			r.URL.Host = "unreviewed.invalid"
			if _, ok := requestSet(tc.scope, r); ok {
				t.Fatal("off-host POST pin accepted")
			}
		})
	}
}
