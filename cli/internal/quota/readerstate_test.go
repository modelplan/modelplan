package quota

import (
	"context"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestManagedAdaptiveCadence(t *testing.T) {
	p := claudeTestPaths(t)
	old := claudeAccountReader.Managed
	calls := 0
	claudeAccountReader.Managed = func(_ context.Context, _ *http.Client, r readerContext) readerOutcome {
		calls++
		return readerOutcome{Entry: readerEntry{Status: "ok", Account: &Account{Source: "claude-code", ObservedAt: r.Now, Windows: []Window{}}}}
	}
	t.Cleanup(func() { claudeAccountReader.Managed = old })
	for i, at := range []int{0, 5, 15, 30} {
		now := claudeTestNow.Add(time.Duration(at) * time.Minute)
		if err := RefreshNative(context.Background(), p, now); err != nil {
			t.Fatal(err)
		}
		s, _ := loadReaderState(p.Cache, "claude")
		want := []int{5, 10, 15, 30}[i]
		if s.IntervalMinutes != want || !s.NextAttemptAt.Equal(now.Add(time.Duration(want)*time.Minute)) {
			t.Fatal("adaptive cadence incorrect")
		}
		if NativeDue(p, now.Add(time.Duration(want)*time.Minute-time.Second)) {
			t.Fatal("early provider read")
		}
	}
	if calls != 4 {
		t.Fatal(calls)
	}
}
func TestManagedProfilesShareBudgetAndDeduplicateNewest(t *testing.T) {
	p := claudeTestPaths(t)
	g := p.ReaderAccess.Grants["claude"]
	g.Profiles = append(g.Profiles, ReaderProfile{Root: filepath.Join(t.TempDir(), "other-account")})
	p.ReaderAccess.Grants["claude"] = g
	old := claudeAccountReader.Managed
	calls := 0
	claudeAccountReader.Managed = func(_ context.Context, _ *http.Client, r readerContext) readerOutcome {
		calls++
		return readerOutcome{Entry: readerEntry{Status: "ok", Account: &Account{Source: "claude-code", ObservedAt: r.Now, Windows: []Window{}, Subscription: &Binding{Ref: "synthetic-common-subscription", Status: "verified"}}}}
	}
	t.Cleanup(func() { claudeAccountReader.Managed = old })
	for _, at := range []int{0, 1, 4, 5} {
		if err := RefreshNative(context.Background(), p, claudeTestNow.Add(time.Duration(at)*time.Minute)); err != nil {
			t.Fatal(err)
		}
	}
	if calls != 2 {
		t.Fatal("accounts bypassed shared five minute floor")
	}
	report := Report{}
	applyManaged(&report, p, "claude", claudeTestNow.Add(6*time.Minute))
	if len(report.Accounts) != 1 || !report.Accounts[0].ObservedAt.Equal(claudeTestNow.Add(5*time.Minute)) {
		t.Fatal("duplicate subscription or older capture selected")
	}
	b, err := os.ReadFile(readerPath(p.Cache, "claude"))
	if err != nil {
		t.Fatal(err)
	}
	for _, profile := range g.Profiles {
		if strings.Contains(string(b), profile.Root) {
			t.Fatal("profile path persisted")
		}
	}
}
func TestManagedRevocationDiscardsInFlightResult(t *testing.T) {
	p := claudeTestPaths(t)
	g := p.ReaderAccess.Grants["claude"]
	allowed := true
	g.StillValid = func() bool { return allowed }
	p.ReaderAccess.Grants["claude"] = g
	old := claudeAccountReader.Managed
	claudeAccountReader.Managed = func(_ context.Context, _ *http.Client, r readerContext) readerOutcome {
		allowed = false
		return readerOutcome{Entry: readerEntry{Status: "ok", Account: &Account{Source: "claude-code", ObservedAt: r.Now}}}
	}
	t.Cleanup(func() { claudeAccountReader.Managed = old })
	if err := RefreshNative(context.Background(), p, claudeTestNow); err == nil {
		t.Fatal("revoked read published")
	}
	s, _ := loadReaderState(p.Cache, "claude")
	if len(s.Entries) != 0 || s.NextAttemptAt.Before(claudeTestNow.Add(5*time.Minute)) {
		t.Fatal("revocation discarded reservation or published result")
	}
}
