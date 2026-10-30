// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func schedulePaths(t *testing.T, scope string) Paths {
	t.Helper()
	isolateHome(t)
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	definition, _ := consent.Definition(scope)
	if err := consent.Change(consent.Path(), func(state *consent.State) error {
		return consent.Set(state, definition.Tool, true, "native:"+definition.Tool, BackendNative, time.Now())
	}); err != nil {
		t.Fatal(err)
	}
	return ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
}
func TestScopePlanKeepsReservationWithoutCapture(t *testing.T) {
	p := schedulePaths(t, consent.ScopeCodexRuntimeUsage)
	now := time.Now()
	next := now.Add(17 * time.Minute)
	if err := reserveReaderAttempt(p.Cache, "codex", next); err != nil {
		t.Fatal(err)
	}
	before, err := os.ReadFile(readerAttemptPath(p.Cache, "codex"))
	if err != nil {
		t.Fatal(err)
	}
	plan, err := PlanScopeRefresh(p, consent.ScopeCodexRuntimeUsage, now)
	if err != nil || !plan.Admitted || !plan.At.Equal(next) {
		t.Fatalf("shared reservation was bypassed: %+v %v", plan, err)
	}
	after, _ := os.ReadFile(readerAttemptPath(p.Cache, "codex"))
	if string(before) != string(after) {
		t.Fatal("planning wrote the budget")
	}
	if _, err := os.Stat(accountPath(p.Cache)); !os.IsNotExist(err) {
		t.Fatal("planning created a capture")
	}
}
func TestScopePlanApprovedPOSTWithoutProfileNeedsNoCredentialsOrBudget(t *testing.T) {
	p := schedulePaths(t, consent.ScopeGeminiAccountUsageSavedLogin)
	plan, err := PlanScopeRefresh(p, consent.ScopeGeminiAccountUsageSavedLogin, time.Now())
	if err != nil || plan.PolicyPending || plan.Admitted {
		t.Fatalf("missing-profile scope was admitted: %+v %v", plan, err)
	}
	if _, err := os.Stat(filepath.Join(p.Cache, "observed")); !os.IsNotExist(err) {
		t.Fatal("planning created a reservation or reading")
	}
}
func TestScopePlanUnreadableBudgetFailsClosed(t *testing.T) {
	p := schedulePaths(t, consent.ScopeCodexRuntimeUsage)
	path := readerAttemptPath(p.Cache, "codex")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(`{"schemaVersion":99}`), 0600); err != nil {
		t.Fatal(err)
	}
	plan, err := PlanScopeRefresh(p, consent.ScopeCodexRuntimeUsage, time.Now())
	if err != nil || plan.BudgetKnown {
		t.Fatalf("unknown budget was treated as due: %+v %v", plan, err)
	}
}

func TestCodexRepeatedRefreshUsesInLockSharedReservation(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	binary, trace := fakeCodex(t, acctResponse)
	for _, offset := range []time.Duration{0, time.Minute} {
		if err := RefreshCodexAccount(context.Background(), cache, binary, acctNow.Add(offset)); err != nil {
			t.Fatal(err)
		}
	}
	calls, _ := os.ReadFile(trace)
	if count := strings.Count(string(calls), "account/rateLimits/read"); count != 1 {
		t.Fatalf("%d quota requests inside budget", count)
	}
	if err := ForgetTool(Paths{Cache: cache}, "codex"); err != nil {
		t.Fatal(err)
	}
	if err := RefreshCodexAccount(context.Background(), cache, binary, acctNow.Add(2*time.Minute)); err != nil {
		t.Fatal(err)
	}
	calls, _ = os.ReadFile(trace)
	if count := strings.Count(string(calls), "account/rateLimits/read"); count != 1 {
		t.Fatalf("Forget reset the budget: %d", count)
	}
	if err := RefreshCodexAccount(context.Background(), cache, binary, acctNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	calls, _ = os.ReadFile(trace)
	if count := strings.Count(string(calls), "account/rateLimits/read"); count != 2 {
		t.Fatalf("due read was not usable: %d", count)
	}
}

type scopeTransport func(*http.Request) (*http.Response, error)

func (f scopeTransport) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }
func TestSelectedNativeRefreshKeepsOtherProviderAndMakesNoOtherCall(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	t.Setenv("Z_AI_API_KEY", "synthetic-zai-key")
	t.Setenv("OPENCODE_API_KEY", "synthetic-opencode-key")
	if err := consent.Change(consent.Path(), func(state *consent.State) error {
		for _, provider := range []string{"zai", "opencodego"} {
			if err := consent.Set(state, provider, true, "native:"+provider, BackendNative, time.Now()); err != nil {
				return err
			}
		}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	path := nativePath(cache)
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	old := &nativeSnap{SchemaVersion: 1, ObservedAt: acctNow.Add(-time.Hour), Providers: []codexbarEntry{{Provider: "opencodego", Admission: consent.Capture().State().CaptureStamp(consent.ScopeOpenCodeGoAccountUsageAPIKey), Status: "ok", ObservedAt: acctNow.Add(-time.Hour), Plan: "unknown"}}}
	body, _ := json.Marshal(old)
	if err := os.WriteFile(path, body, 0600); err != nil {
		t.Fatal(err)
	}
	requests := []string{}
	previous := nativeClient
	nativeClient = &http.Client{Transport: scopeTransport(func(request *http.Request) (*http.Response, error) {
		requests = append(requests, request.URL.Host)
		return &http.Response{StatusCode: 403, Header: http.Header{}, Body: io.NopCloser(strings.NewReader(`{}`))}, nil
	})}
	t.Cleanup(func() { nativeClient = previous })
	paths := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if err := RefreshNativeProviders(context.Background(), paths, acctNow, []string{"zai"}); err != nil {
		t.Fatal(err)
	}
	if len(requests) != 1 || !strings.Contains(requests[0], "z.ai") {
		t.Fatalf("unrequested provider called: %v", requests)
	}
	found := false
	for _, entry := range loadNative(cache).Providers {
		if entry.Provider == "opencodego" {
			found = entry.ObservedAt.Equal(old.Providers[0].ObservedAt) && entry.Status == "ok" && reflect.DeepEqual(entry.Admission, old.Providers[0].Admission)
		}
	}
	if !found {
		t.Fatal("filtered refresh erased another provider's capture")
	}
}

func TestSelectedNativeRejectsStaleCapturedAdmissionBeforeReservation(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "synthetic-zai-key")
	cache := t.TempDir()
	if err := consent.Change(consent.Path(), func(state *consent.State) error {
		return consent.Set(state, "zai", true, "native:zai", BackendNative, time.Now())
	}); err != nil {
		t.Fatal(err)
	}
	paths := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if err := consent.Change(consent.Path(), func(state *consent.State) error { return consent.Set(state, "zai", false, "", "", time.Now()) }); err != nil {
		t.Fatal(err)
	}
	calls := 0
	previous := nativeClient
	nativeClient = &http.Client{Transport: scopeTransport(func(*http.Request) (*http.Response, error) {
		calls++
		return &http.Response{StatusCode: 403, Header: http.Header{}, Body: io.NopCloser(strings.NewReader(`{}`))}, nil
	})}
	t.Cleanup(func() { nativeClient = previous })
	if err := RefreshNativeProviders(context.Background(), paths, time.Now(), []string{"zai"}); err == nil {
		t.Fatal("stale captured admission was accepted")
	}
	if calls != 0 {
		t.Fatal("revoked source reached the provider")
	}
	if _, err := os.Stat(readerAttemptPath(cache, "zai")); !os.IsNotExist(err) {
		t.Fatal("revoked source reached reservation")
	}
}

func TestCorruptCodexCaptureCannotResetBudget(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	path := accountPath(cache)
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(`{"schemaVersion":99}`), 0600); err != nil {
		t.Fatal(err)
	}
	binary, trace := fakeCodex(t, acctResponse)
	if err := RefreshCodexAccount(context.Background(), cache, binary, acctNow); err == nil {
		t.Fatal("unknown capture/budget state was overwritten")
	}
	if _, err := os.Stat(trace); !os.IsNotExist(err) {
		t.Fatal("unknown budget reached runtime")
	}
}
