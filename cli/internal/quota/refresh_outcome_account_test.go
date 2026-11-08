package quota

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestWindowsSayWhenTheirOwnReadingIsOld(t *testing.T) {
	used := 10.0
	reset := now.Add(3 * time.Hour)
	a := Account{Source: "codex", ObservedAt: now, Windows: []Window{
		{Kind: "five_hour", UsedPercent: &used, ResetsAt: &reset, ObservedAt: now.Add(-staleAfter)},
		{Kind: "weekly", UsedPercent: &used, ResetsAt: &reset, ObservedAt: now.Add(-staleAfter - time.Minute)},
	}}
	Evaluate(&a, now)
	if a.Stale || a.Windows[0].Stale || !a.Windows[1].Stale {
		t.Fatalf("account %v, windows %v %v", a.Stale, a.Windows[0].Stale, a.Windows[1].Stale)
	}
	// A later reading clears it: Evaluate runs on cached windows again.
	a.Windows[1].ObservedAt = now
	Evaluate(&a, now)
	if a.Windows[1].Stale {
		t.Fatal("stale kept after a fresh reading")
	}
}

func TestRefreshAccountNowNamesWhatHappened(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	if r := RefreshAccountNow(context.Background(), t.TempDir(), "", now); r.Status != "failed" || !strings.Contains(r.Reason, "MODELPLAN_CODEX_ACCOUNT") {
		t.Fatalf("disabled: %+v", r)
	}
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "")
	cache := t.TempDir()
	if err := os.MkdirAll(filepath.Join(cache, "observed"), 0o700); err != nil {
		t.Fatal(err)
	}
	write := func(status, reason string) {
		b, _ := json.Marshal(accountSnap{SchemaVersion: 1, ObservedAt: now, Status: status, Error: reason})
		if err := os.WriteFile(accountPath(cache), b, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	write("ok", "")
	if r := RefreshAccountNow(context.Background(), cache, "", now.Add(time.Minute)); r.Status != "too_soon" || r.NextAt == nil || !r.NextAt.Equal(now.Add(AccountEvery)) || r.Reason != "" {
		t.Fatalf("too soon: %+v", r)
	}
	// Within the wait after a failure, the failure is named, not hidden behind old figures.
	write("error", "codex not found")
	if r := RefreshAccountNow(context.Background(), cache, "", now.Add(time.Minute)); r.Status != "too_soon" || r.Reason != "codex not found" {
		t.Fatalf("too soon after failure: %+v", r)
	}
}
