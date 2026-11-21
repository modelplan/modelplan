// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// Sampling 11-20 S5 (#1031): GLM is read through ZCode's configured key (account A), then the
// user saves a pasted key B for another account. Invariant: while a pasted GLM key is saved, a
// refresh never publishes a reading made with another key. A refresh before the next request is
// due keeps "not read yet", publishes no GLM account, sends no request and keeps the deadline.
func TestGLMThrottledRefreshAfterAPastedKeyKeepsTheOtherAccountsReadingOut(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	writeZCodeProviders(t, home, zcodeTemplateProvider)
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		_, _ = w.Write([]byte(`{"success":true,"code":200,"data":{"limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":25,"nextResetTime":1792152000000}]}}`))
	}))
	defer server.Close()
	oldClient := nativeClient
	t.Cleanup(func() { nativeClient = oldClient })
	nativeClient = readerFixtureClient(t, server, "api.z.ai", "open.bigmodel.cn")
	cache := t.TempDir()
	paths := func() Paths { return ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()) }
	if err := ExecuteScopeRefresh(context.Background(), paths(), consent.ScopeZaiAccountUsageAPIKey, now); err != nil {
		t.Fatalf("ZCode refresh: %v", err)
	}
	glmAccount := func(r Report) bool {
		for _, a := range r.Accounts {
			if a.Source == "native:zai" {
				return true
			}
		}
		return false
	}
	if !glmAccount(ReadPermitted(paths(), now)) || calls.Load() != 1 {
		t.Fatalf("fixture: no ZCode GLM reading (calls %d)", calls.Load())
	}

	if err := SetManualKey(cache, "zai", "pasted-key-account-b", "global"); err != nil {
		t.Fatal(err)
	}
	entry := loadNative(cache).Providers[0]
	if entry.NativeNextAttemptAt == nil {
		t.Fatalf("fixture: reference-only entry has no deadline: %+v", entry)
	}
	deadline := *entry.NativeNextAttemptAt
	later := now.Add(time.Minute)
	if !later.Before(deadline) {
		t.Fatalf("fixture: refresh at %s is not before the deadline %s", later, deadline)
	}
	if err := RefreshNative(context.Background(), paths(), later); err != nil {
		t.Fatal(err)
	}
	r := ReadPermitted(paths(), later)
	if glmAccount(r) {
		t.Fatal("a throttled refresh published account A's GLM quota while pasted key B is selected")
	}
	for _, s := range r.Sources {
		if s.Source == "native:zai" && (s.Status != "missing" || s.Reason != "not read yet") {
			t.Fatalf("GLM status %+v, want missing / not read yet", s)
		}
	}
	if calls.Load() != 1 {
		t.Fatalf("a throttled refresh sent %d provider requests", calls.Load()-1)
	}
	after := loadNative(cache).Providers
	if len(after) != 1 || after[0].NativeNextAttemptAt == nil || !after[0].NativeNextAttemptAt.Equal(deadline) || after[0].Status == "ok" {
		t.Fatalf("throttled refresh changed the GLM entry: %+v", after)
	}
}
