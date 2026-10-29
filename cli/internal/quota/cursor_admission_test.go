package quota

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func cursorAdmittedPaths(t *testing.T) (Paths, string) {
	t.Helper()
	allowPOSTProtocolFixture(t, "cursor")
	isolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_NATIVE", "")
	p := nativePaths(t)
	token := syntheticCursorToken("synthetic-cursor-account", cursorNow.Add(72*time.Hour))
	cursorDB(t, token, false)
	p.ReaderAccess = &ReaderAccess{Grants: map[string]ReaderGrant{"cursor": {SavedLogin: true, Generation: "synthetic-consent-1", Profiles: cursorProfiles()}}}
	return p, token
}

func cursorPeriodServer(t *testing.T, token string, mode *string, paths *[]string) {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		*paths = append(*paths, r.URL.Path)
		if r.Method != "POST" {
			t.Error("non-POST request")
		}
		if *mode == "rejected" {
			w.WriteHeader(401)
			_, _ = w.Write([]byte(token))
			return
		}
		if *mode == "limited" {
			w.Header().Set("Retry-After", "7200")
			w.WriteHeader(429)
			return
		}
		if *mode == "oversized" {
			_, _ = w.Write([]byte(strings.Repeat("x", nativeMaxBody+1)))
			return
		}
		if *mode == "malformed" {
			_, _ = w.Write([]byte("{"))
			return
		}
		file := ""
		switch r.URL.Path {
		case "/api/dashboard/get-plan-info":
			if !strings.Contains(r.Header.Get("Cookie"), token) || r.Header.Get("Authorization") != "" {
				t.Error("incorrect plan authentication")
			}
			file = "merged-plan.json"
		case "/aiserver.v1.DashboardService/GetCurrentPeriodUsage":
			if r.Header.Get("Authorization") != "Bearer "+token || r.Header.Get("Cookie") != "" || r.Header.Get("Connect-Protocol-Version") != "1" {
				t.Error("incorrect RPC authentication")
			}
			if *mode == "missing-quota" {
				_, _ = w.Write([]byte(`{"planUsage":{}}`))
				return
			}
			file = "period-usage.json"
		default:
			t.Error("extra endpoint outside two-request budget")
			w.WriteHeader(400)
			return
		}
		b, err := os.ReadFile(filepath.Join("testdata", "cursor", file))
		if err != nil {
			t.Error(err)
			return
		}
		_, _ = w.Write(b)
	}))
	oldHost, oldRPC, oldClient := cursorHost, cursorRPCHost, nativeClient
	cursorHost, cursorRPCHost, nativeClient = srv.URL, srv.URL, srv.Client()
	t.Cleanup(func() { srv.Close(); cursorHost, cursorRPCHost, nativeClient = oldHost, oldRPC, oldClient })
}

func TestCursorAdmittedReadBudgetIdentityAndCacheOnly(t *testing.T) {
	p, token := cursorAdmittedPaths(t)
	mode := "ok"
	paths := []string{}
	cursorPeriodServer(t, token, &mode, &paths)
	grant := p.ReaderAccess
	p.ReaderAccess = nil
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "cursor", Backend: BackendNative, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	if NativeDue(p, cursorNow) {
		t.Fatal("legacy connection granted saved-login access")
	}
	if err := RefreshNative(context.Background(), p, cursorNow); err == nil || len(paths) != 0 {
		t.Fatal("missing consent collected")
	}
	p.ReaderAccess = grant
	if err := RefreshNative(context.Background(), p, cursorNow); err != nil {
		t.Fatal(err)
	}
	if strings.Join(paths, " ") != "/api/dashboard/get-plan-info /aiserver.v1.DashboardService/GetCurrentPeriodUsage" {
		t.Fatal(paths)
	}
	s, _ := loadReaderState(p.Cache, "cursor")
	a := s.Entries[0].Account
	if a == nil || len(a.Windows) != 1 || a.Windows[0].Kind != "weekly" || *a.Windows[0].UsedPercent != 41 || a.Subscription == nil || a.SharedPool == nil || a.SharedPool.Status != "unverified" || a.SharedPool.Additive {
		t.Fatal("invalid included pool or fabricated link")
	}
	if err := RefreshNative(context.Background(), p, cursorNow.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if len(paths) != 2 {
		t.Fatal("five minute floor bypassed")
	}
	if err := RefreshNative(context.Background(), p, cursorNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if len(paths) != 3 || paths[2] != "/aiserver.v1.DashboardService/GetCurrentPeriodUsage" {
		t.Fatal("warm read refetched stable metadata")
	}
	// Cache projection neither stats the tool DB nor launches a collection.
	home, _ := os.UserHomeDir()
	if err := os.Remove(CursorReadPath(home)); err != nil {
		t.Fatal(err)
	}
	r := Report{}
	applyNative(&r, p, cursorNow.Add(6*time.Minute))
	if len(r.Accounts) != 1 || len(paths) != 3 || !r.Accounts[0].ObservedAt.Equal(cursorNow.Add(5*time.Minute)) {
		t.Fatal("cache projection touched tool state")
	}
	for _, path := range []string{readerPath(p.Cache, "cursor"), subscriptionsPath(p.Cache), xSubscriptionPath(p.Cache)} {
		b, _ := os.ReadFile(path)
		for _, secret := range []string{token, "synthetic-cursor-account", "synthetic-private@example.invalid", home} {
			if strings.Contains(string(b), secret) {
				t.Fatal("private value persisted")
			}
		}
	}
}

func TestCursorFailuresKeepCaptureBackoffAndUnknown(t *testing.T) {
	for _, failure := range []string{"rejected", "limited", "oversized", "malformed", "missing-quota"} {
		t.Run(failure, func(t *testing.T) {
			p, token := cursorAdmittedPaths(t)
			mode := "ok"
			paths := []string{}
			cursorPeriodServer(t, token, &mode, &paths)
			if err := RefreshNative(context.Background(), p, cursorNow); err != nil {
				t.Fatal(err)
			}
			mode = failure
			if err := RefreshNative(context.Background(), p, cursorNow.Add(5*time.Minute)); err != nil {
				t.Fatal(err)
			}
			s, _ := loadReaderState(p.Cache, "cursor")
			if s.Entries[0].Status == "ok" || s.Entries[0].Account == nil || !s.Entries[0].Account.ObservedAt.Equal(cursorNow) || *s.Entries[0].Account.Windows[0].UsedPercent != 41 {
				t.Fatal("failure replaced the last valid capture or guessed zero")
			}
			if NativeDue(p, cursorNow.Add(14*time.Minute)) {
				t.Fatal("error backoff ignored")
			}
			if failure == "limited" && !s.NextAttemptAt.Equal(cursorNow.Add(125*time.Minute)) {
				t.Fatal("Retry-After ignored")
			}
		})
	}
}

func TestCursorUnsupportedAndExpiredUseNoRequests(t *testing.T) {
	for _, mode := range []string{"opaque", "expired", "passive", "off"} {
		t.Run(mode, func(t *testing.T) {
			p, token := cursorAdmittedPaths(t)
			serverMode := "ok"
			paths := []string{}
			cursorPeriodServer(t, token, &serverMode, &paths)
			switch mode {
			case "opaque":
				cursorDB(t, "unsupported-opaque-login", false)
			case "expired":
				cursorDB(t, syntheticCursorToken("synthetic-expired", cursorNow), false)
			default:
				t.Setenv("MODELPLAN_READERS", mode)
			}
			_ = RefreshNative(context.Background(), p, cursorNow)
			if len(paths) != 0 {
				t.Fatal("unsupported login or privacy mode made a request")
			}
		})
	}
}

func TestCursorPlanAndPeriodDoNotGuessLegacyUnits(t *testing.T) {
	_, details := parseCursorPlan([]byte(`{"isMerged":false,"planInfo":{"includedUsagePeriod":"INCLUDED_USAGE_PERIOD_MONTHLY"}}`))
	if details == nil || details.Unified || details.Minutes != 43200 {
		t.Fatal("legacy plan confused with shared pool")
	}
	ws, ok := parseCursorPeriod([]byte(`{"planUsage":{"totalPercentUsed":0,"used":5000,"limit":10000}}`), details, cursorNow)
	if !ok || len(ws) != 1 || ws[0].Kind != "monthly" || *ws[0].UsedPercent != 0 || ws[0].UsedUSD != nil || ws[0].Requests != nil {
		t.Fatal("legacy units or request counts guessed")
	}
	for _, body := range []string{`{}`, `{"isMerged":true}`, `{"planInfo":{"includedUsagePeriod":"NEW_UNKNOWN_PERIOD"}}`} {
		if _, details := parseCursorPlan([]byte(body)); details != nil {
			t.Fatal("unknown period guessed")
		}
	}
	var raw json.RawMessage = []byte(`{"planUsage":{"totalPercentUsed":"NaN"}}`)
	if _, ok := parseCursorPeriod(raw, details, cursorNow); ok {
		t.Fatal("invalid percentage guessed")
	}
}

func TestXSubscriptionConservativeCrossProviderFloor(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	if !xSubscriptionDue(cache, "cursor", cursorNow) {
		t.Fatal("initial read unavailable")
	}
	if err := reserveXSubscription(cache, "cursor", cursorNow); err != nil {
		t.Fatal(err)
	}
	if xSubscriptionDue(cache, "grok", cursorNow.Add(4*time.Minute)) || !xSubscriptionDue(cache, "grok", cursorNow.Add(5*time.Minute)) {
		t.Fatal("shared pool floor incorrect")
	}
	if !xSubscriptionDue(cache, "gemini", cursorNow) {
		t.Fatal("unrelated provider blocked")
	}
}

func TestCursorDoesNotForwardSavedLoginOnRedirect(t *testing.T) {
	p, _ := cursorAdmittedPaths(t)
	forwarded := false
	target := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { forwarded = true }))
	defer target.Close()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { http.Redirect(w, r, target.URL, 302) }))
	defer srv.Close()
	oldHost, oldRPC, oldClient := cursorHost, cursorRPCHost, nativeClient
	cursorHost, cursorRPCHost, nativeClient = srv.URL, srv.URL, srv.Client()
	defer func() { cursorHost, cursorRPCHost, nativeClient = oldHost, oldRPC, oldClient }()
	if err := RefreshNative(context.Background(), p, cursorNow); err != nil {
		t.Fatal(err)
	}
	s, _ := loadReaderState(p.Cache, "cursor")
	if forwarded || s.Entries[0].Status == "ok" {
		t.Fatal("saved session followed redirect")
	}
}
