package quota

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestClaudeCreditsContractGateMakesNoRequest(t *testing.T) {
	isolateHome(t)
	called := false
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		_, _ = w.Write([]byte(`{"amount":7665,"currency":"usd"}`))
	}))
	defer srv.Close()
	old := claudeOAuthHost
	claudeOAuthHost = srv.URL
	defer func() { claudeOAuthHost = old }()
	credits, state, _ := readClaudeCredits(context.Background(), srv.Client(), "synthetic-org", "synthetic-token", claudeTestNow)
	if called || credits != nil || state != "not-supported" {
		t.Fatal("unverified OAuth wallet contract was used")
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
	var profile claudeOAuthProfile
	state, _ := claudeGet(context.Background(), srv.Client(), "/api/oauth/profile", "synthetic-token", &profile, claudeTestNow)
	if forwarded || state == "" {
		t.Fatal("credential followed a redirect")
	}
}
