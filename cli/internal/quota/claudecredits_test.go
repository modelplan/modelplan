package quota

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestClaudeCreditsStrictUnits(t *testing.T) {
	isolateHome(t)
	for _, tc := range []struct {
		body      string
		supported bool
		balance   float64
	}{
		{`{"amount":7665,"currency":"usd"}`, true, 76.65},
		{`{"amount":0,"currency":"USD"}`, true, 0},
		{`{"amount":7665,"currency":"eur"}`, false, 0},
		{`{"amount":-1,"currency":"usd"}`, false, 0},
		{`{"currency":"usd"}`, false, 0},
		{`{"amount":"76.65","currency":"usd"}`, false, 0},
		{`{}`, false, 0},
	} {
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path != "/api/oauth/organizations/synthetic-org/prepaid/credits" || r.Method != "GET" {
				t.Error("unexpected prepaid request")
			}
			_, _ = w.Write([]byte(tc.body))
		}))
		old := claudeOAuthHost
		claudeOAuthHost = srv.URL
		credits, state, _ := readClaudeCredits(context.Background(), srv.Client(), "synthetic-org", "synthetic-token", claudeTestNow)
		claudeOAuthHost = old
		srv.Close()
		if tc.supported {
			if state != "" || credits == nil || credits.Balance == nil || *credits.Balance != tc.balance || credits.Currency != "USD" || credits.Unit != "money" {
				t.Fatal("incorrect prepaid conversion")
			}
		} else if credits != nil || state == "" {
			t.Fatal("unsupported wallet guessed a balance")
		}
	}
}

func TestClaudeDoesNotForwardCredentialOnRedirect(t *testing.T) {
	isolateHome(t)
	forwarded := false
	target := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { forwarded = true }))
	defer target.Close()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { http.Redirect(w, r, target.URL, 302) }))
	defer srv.Close()
	old := claudeOAuthHost
	claudeOAuthHost = srv.URL
	defer func() { claudeOAuthHost = old }()
	_, state, _ := readClaudeCredits(context.Background(), srv.Client(), "synthetic-org", "synthetic-token", claudeTestNow)
	if forwarded || state == "" {
		t.Fatal("credential followed a redirect")
	}
}
