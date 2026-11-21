// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// Sampling 11-21 S8 (#1130 follow-up to 11-20 S5): the parent build read GLM account A through
// ZCode, the user pasted key B, and a throttled refresh wrote A's quota back into native.json. After
// the upgrade a refresh before the deadline returned that entry unchanged, so A's quota still
// showed while B was selected. Invariant: while a pasted GLM key is saved, a cached GLM reading is
// shown only when it was read with that key; any other entry becomes reference-only and keeps its
// deadline. Replays the parent build's cache.
func TestS8UpgradeDropsAParentBuildGLMReadingOfAnotherKey(t *testing.T) {
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
	parent, err := os.ReadFile(nativePath(cache))
	if err != nil {
		t.Fatal(err)
	}
	if err := SetManualKey(cache, "zai", "pasted-key-account-b", "global"); err != nil {
		t.Fatal(err)
	}
	// The parent build's throttled refresh projected account A's reading back over key B.
	if err := os.WriteFile(nativePath(cache), parent, 0o600); err != nil {
		t.Fatal(err)
	}
	var contaminated nativeSnap
	if err := json.Unmarshal(parent, &contaminated); err != nil || len(contaminated.Providers) != 1 || contaminated.Providers[0].Status != "ok" {
		t.Fatalf("fixture: parent cache %s", parent)
	}
	deadline := glmReferenceOnly(contaminated.Providers[0]).NativeNextAttemptAt
	if deadline == nil {
		t.Fatal("fixture: no deadline")
	}
	// Upgrade: a cache-only read before any refresh does not show A either.
	if glmAccount(ReadPermitted(paths(), now)) {
		t.Fatal("after the upgrade, a cache-only read shows account A's GLM quota while pasted key B is selected")
	}
	// Refresh before the deadline.
	later := now.Add(time.Minute)
	if !later.Before(*deadline) {
		t.Fatalf("fixture: %s is not before the deadline %s", later, *deadline)
	}
	if err := RefreshNative(context.Background(), paths(), later); err != nil {
		t.Fatal(err)
	}
	if glmAccount(ReadPermitted(paths(), later)) {
		t.Fatal("after the upgrade, account A's GLM quota is shown while pasted key B is selected")
	}
	if calls.Load() != 1 {
		t.Fatalf("the throttled refresh sent %d provider requests", calls.Load()-1)
	}
	after := loadNative(cache).Providers
	if len(after) != 1 || after[0].Status == "ok" || len(after[0].Windows) != 0 || after[0].NativeNextAttemptAt == nil || !after[0].NativeNextAttemptAt.Equal(*deadline) {
		t.Fatalf("GLM entry after the upgrade refresh: %+v", after)
	}
	// The pasted key's own reading, once due, is kept by a later throttled refresh.
	due := deadline.Add(time.Second)
	if err := RefreshNative(context.Background(), paths(), due); err != nil {
		t.Fatal(err)
	}
	if calls.Load() != 2 || !glmAccount(ReadPermitted(paths(), due)) {
		t.Fatalf("pasted key B not read when due (calls %d)", calls.Load())
	}
	if err := RefreshNative(context.Background(), paths(), due.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if calls.Load() != 2 || !glmAccount(ReadPermitted(paths(), due.Add(time.Minute))) {
		t.Fatalf("a throttled refresh dropped key B's own reading (calls %d)", calls.Load())
	}
}
