// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
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
func TestScopePlanPolicyPendingNeedsNoCredentialsOrBudget(t *testing.T) {
	p := schedulePaths(t, consent.ScopeGeminiAccountUsageSavedLogin)
	plan, err := PlanScopeRefresh(p, consent.ScopeGeminiAccountUsageSavedLogin, time.Now())
	if err != nil || !plan.PolicyPending || plan.Admitted {
		t.Fatalf("POST scope was admitted: %+v %v", plan, err)
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
