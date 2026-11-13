// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// G3-103 on the desktop (#911): the app plans each read with PlanScopeRefresh and runs it with
// ExecuteScopeRefresh. #911 taught only the hook path (NativeDue) about a new sign-in or grant, so
// the app still waited out the failure back-off. These tests drive the app's two entry points.

// g3103Desktop grants the tool's saved-login scope in the consent store, as Settings does, and
// binds the paths to that admission, as the app server does.
func g3103Desktop(t *testing.T, provider string, p Paths) Paths {
	t.Helper()
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if err := consent.Change(consent.Path(), func(state *consent.State) error {
		return consent.Set(state, provider, true, "native:"+provider, BackendNative, time.Now())
	}); err != nil {
		t.Fatal(err)
	}
	admission := consent.Capture()
	p.Admission = &admission
	return p
}

func g3103Plan(t *testing.T, p Paths, scope string, at time.Time) time.Time {
	t.Helper()
	plan, err := PlanScopeRefresh(p, scope, at)
	if err != nil || !plan.Admitted || !plan.BudgetKnown || plan.PolicyPending {
		t.Fatalf("plan at %v: %+v %v", at, plan, err)
	}
	return plan.At
}

// g3103FailThreeTimes reads at 0, 10 and 30 minutes through the app's run entry; each read
// fails before any request, so the back-off ends at 70 minutes.
func g3103FailThreeTimes(t *testing.T, p Paths, provider, scope string, start time.Time) {
	t.Helper()
	for _, at := range []time.Duration{0, 10 * time.Minute, 30 * time.Minute} {
		if got := g3103Plan(t, p, scope, start.Add(at)); got.After(start.Add(at)) {
			t.Fatalf("setup: read at %v planned for %v", at, got)
		}
		if err := ExecuteScopeRefresh(context.Background(), p, scope, start.Add(at)); err != nil {
			t.Fatal(err)
		}
	}
	s, _ := loadReaderState(p.Cache, provider)
	if s.Failures != 3 || !s.NextAttemptAt.Equal(start.Add(70*time.Minute)) {
		t.Fatalf("setup: failures=%d next=%v", s.Failures, s.NextAttemptAt)
	}
	if got := g3103Plan(t, p, scope, start.Add(34*time.Minute)); !got.Equal(start.Add(70 * time.Minute)) {
		t.Fatalf("an unchanged sign-in and grant keep the back-off: planned %v", got)
	}
}

func g3103Attempted(t *testing.T, p Paths, provider string, at time.Time) bool {
	t.Helper()
	s, err := loadReaderState(p.Cache, provider)
	return err == nil && s.AttemptedAt.Equal(at)
}

func TestG3103PlanScopeRefreshHonoursEarlyRetry(t *testing.T) {
	scope := consent.ScopeGrokAccountUsageSavedLogin
	setup := func(t *testing.T) (Paths, string, *int) {
		t.Helper()
		p := grokTestPaths(t)
		root := p.ReaderAccess.Grants["grok"].Profiles[0].Root
		writeGrokAuth(t, root, grokAuth{Key: "synthetic-grok-access", Mode: "oidc", User: "synthetic-grok-user", Issuer: "https://auth.x.ai", Client: grokDefaultClient, Expires: grokNow.Add(-time.Hour).Format(time.RFC3339)})
		touchGrokAuth(t, root, grokNow.Add(-time.Hour))
		mode, hits := "ok", 0
		grokTestServer(t, &mode, &hits)
		p = g3103Desktop(t, "grok", p)
		g3103FailThreeTimes(t, p, "grok", scope, grokNow)
		if hits != 0 {
			t.Fatalf("setup: expired sign-in reached the provider %d times", hits)
		}
		writeGrokAuth(t, root, grokAuth{Key: "synthetic-grok-access", Mode: "oidc", User: "synthetic-grok-user", Issuer: "https://auth.x.ai", Client: grokDefaultClient, Expires: grokNow.Add(48 * time.Hour).Format(time.RFC3339)})
		return p, root, &hits
	}
	check := func(t *testing.T, p Paths, hits *int) {
		t.Helper()
		if got := g3103Plan(t, p, scope, grokNow.Add(35*time.Minute)); got.After(grokNow.Add(35 * time.Minute)) {
			t.Fatalf("the app plans the read for %v, after the five-minute floor", got)
		}
		if err := ExecuteScopeRefresh(context.Background(), p, scope, grokNow.Add(35*time.Minute)); err != nil {
			t.Fatal(err)
		}
		s, _ := loadReaderState(p.Cache, "grok")
		if *hits != 1 || len(s.Entries) != 1 || s.Entries[0].Status != "ok" || s.Failures != 0 {
			t.Fatalf("Grok was not read: hits=%d state=%+v", *hits, s)
		}
	}
	t.Run("signed in again", func(t *testing.T) {
		p, root, hits := setup(t)
		touchGrokAuth(t, root, grokNow.Add(33*time.Minute))
		check(t, p, hits)
	})
	t.Run("ticked again in Settings", func(t *testing.T) {
		p, root, hits := setup(t)
		touchGrokAuth(t, root, grokNow.Add(-time.Hour)) // same stamp: only the grant changes
		g := p.ReaderAccess.Grants["grok"]
		g.Generation = "synthetic-grant-002"
		p.ReaderAccess.Grants["grok"] = g
		if got := g3103Plan(t, p, scope, grokNow.Add(32*time.Minute)); !got.Equal(grokNow.Add(35 * time.Minute)) {
			t.Fatalf("the five-minute floor holds: planned %v", got)
		}
		check(t, p, hits)
	})
	t.Run("Retry-After still holds", func(t *testing.T) {
		p := g3103Desktop(t, "grok", grokTestPaths(t))
		mode, hits := "limited", 0
		grokTestServer(t, &mode, &hits)
		if err := ExecuteScopeRefresh(context.Background(), p, scope, grokNow); err != nil || hits != 1 {
			t.Fatalf("%v hits=%d", err, hits)
		}
		g := p.ReaderAccess.Grants["grok"]
		g.Generation = "synthetic-grant-002"
		p.ReaderAccess.Grants["grok"] = g
		touchGrokAuth(t, g.Profiles[0].Root, grokNow.Add(time.Minute))
		if got := g3103Plan(t, p, scope, grokNow.Add(10*time.Minute)); !got.After(grokNow.Add(10 * time.Minute)) {
			t.Fatalf("a rate limit was planned early: %v", got)
		}
	})
}

// #911-2: the early read replaces the failure reservation, so the reader's normal schedule
// follows a recovery instead of the old deadline.
func TestG3103RecoveryReleasesFailureReservation(t *testing.T) {
	scope := consent.ScopeGrokAccountUsageSavedLogin
	p := grokTestPaths(t)
	root := p.ReaderAccess.Grants["grok"].Profiles[0].Root
	writeGrokAuth(t, root, grokAuth{Key: "synthetic-grok-access", Mode: "oidc", User: "synthetic-grok-user", Issuer: "https://auth.x.ai", Client: grokDefaultClient, Expires: grokNow.Add(-time.Hour).Format(time.RFC3339)})
	touchGrokAuth(t, root, grokNow.Add(-time.Hour))
	mode, hits := "ok", 0
	grokTestServer(t, &mode, &hits)
	p = g3103Desktop(t, "grok", p)
	g3103FailThreeTimes(t, p, "grok", scope, grokNow)
	writeGrokAuth(t, root, grokAuth{Key: "synthetic-grok-access", Mode: "oidc", User: "synthetic-grok-user", Issuer: "https://auth.x.ai", Client: grokDefaultClient, Expires: grokNow.Add(48 * time.Hour).Format(time.RFC3339)})
	touchGrokAuth(t, root, grokNow.Add(33*time.Minute))
	if err := ExecuteScopeRefresh(context.Background(), p, scope, grokNow.Add(35*time.Minute)); err != nil || hits != 1 {
		t.Fatalf("recovery read: %v hits=%d", err, hits)
	}
	at := grokNow.Add(40 * time.Minute)
	if next, known := managedReaderNext(p.Cache, "grok", time.Time{}); !known || !next.Equal(at) {
		t.Fatalf("the failure reservation outlived the recovery: %v", next)
	}
	if !managedDue(p, "grok", at) {
		t.Fatal("the hook path still waits for the old deadline")
	}
	if got := g3103Plan(t, p, scope, at); !got.Equal(at) {
		t.Fatalf("the app plans the next read for %v", got)
	}
	if err := ExecuteScopeRefresh(context.Background(), p, scope, at); err != nil || hits != 2 {
		t.Fatalf("the next read did not run: %v hits=%d", err, hits)
	}
}

// #911-3: Gemini, Cursor and Kimi had no sign-in stamp, so signing in again changed nothing.
func TestG3103SignInStampGeminiCursorKimi(t *testing.T) {
	t.Run("Gemini", func(t *testing.T) {
		scope := consent.ScopeGeminiAccountUsageSavedLogin
		p := geminiTestPaths(t)
		mode, paths := "ok", []string{}
		geminiServer(t, &mode, &paths)
		credential := filepath.Join(p.ReaderAccess.Grants["gemini"].Profiles[0].Root, "oauth_creds.json")
		saved, err := os.ReadFile(credential)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.Remove(credential); err != nil { // signed out
			t.Fatal(err)
		}
		p = g3103Desktop(t, "gemini", p)
		g3103FailThreeTimes(t, p, "gemini", scope, geminiNow)
		if len(paths) != 0 {
			t.Fatalf("setup: a signed-out read reached the provider: %v", paths)
		}
		if err := os.WriteFile(credential, saved, 0o600); err != nil { // signed in again
			t.Fatal(err)
		}
		if got := g3103Plan(t, p, scope, geminiNow.Add(35*time.Minute)); got.After(geminiNow.Add(35 * time.Minute)) {
			t.Fatalf("the new Gemini sign-in was not seen: planned %v", got)
		}
		if err := ExecuteScopeRefresh(context.Background(), p, scope, geminiNow.Add(35*time.Minute)); err != nil {
			t.Fatal(err)
		}
		if !g3103Attempted(t, p, "gemini", geminiNow.Add(35*time.Minute)) || len(paths) == 0 {
			t.Fatalf("Gemini was not read after signing in again: %v", paths)
		}
	})
	t.Run("Kimi", func(t *testing.T) {
		scope := consent.ScopeKimiAccountUsageSavedLogin
		p, token := kimiLoginTestPaths(t)
		mode, hits := "ok", 0
		kimiLoginServer(t, token, &mode, &hits)
		credential := filepath.Join(p.ReaderAccess.Grants["kimi"].Profiles[0].Root, "credentials", "kimi-code.json")
		saved, err := os.ReadFile(credential)
		if err != nil {
			t.Fatal(err)
		}
		expired, _ := json.Marshal(map[string]any{"access_token": token, "expires_at": 1})
		if err := os.WriteFile(credential, expired, 0o600); err != nil {
			t.Fatal(err)
		}
		p = g3103Desktop(t, "kimi", p)
		g3103FailThreeTimes(t, p, "kimi", scope, kimiNow)
		if hits != 0 {
			t.Fatalf("setup: an expired login reached the provider %d times", hits)
		}
		if err := os.WriteFile(credential, saved, 0o600); err != nil {
			t.Fatal(err)
		}
		if got := g3103Plan(t, p, scope, kimiNow.Add(35*time.Minute)); got.After(kimiNow.Add(35 * time.Minute)) {
			t.Fatalf("the new Kimi sign-in was not seen: planned %v", got)
		}
		if err := ExecuteScopeRefresh(context.Background(), p, scope, kimiNow.Add(35*time.Minute)); err != nil || hits != 1 {
			t.Fatalf("Kimi was not read after signing in again: %v hits=%d", err, hits)
		}
	})
	t.Run("Cursor stamps its write-ahead log", func(t *testing.T) {
		root := t.TempDir()
		profile := ReaderProfile{Root: root}
		if err := os.WriteFile(filepath.Join(root, "state.vscdb"), []byte("synthetic"), 0o600); err != nil {
			t.Fatal(err)
		}
		before := loginStamp("cursor", profile)
		if before == "" {
			t.Fatal("Cursor has no sign-in stamp")
		}
		// SQLite may hold the new token only in the WAL until a checkpoint.
		if err := os.WriteFile(filepath.Join(root, "state.vscdb-wal"), []byte("synthetic-wal"), 0o600); err != nil {
			t.Fatal(err)
		}
		if loginStamp("cursor", profile) == before {
			t.Fatal("a sign-in written to the WAL is not seen")
		}
	})
	t.Run("Grok keeps its stamp format", func(t *testing.T) {
		root := t.TempDir()
		file := filepath.Join(root, "auth.json")
		if err := os.WriteFile(file, []byte("{}"), 0o600); err != nil {
			t.Fatal(err)
		}
		if got, want := loginStamp("grok", ReaderProfile{Root: root, AccountFile: file}), fileStamp(file); got != want {
			t.Fatalf("stored Grok stamps would all look changed: %q != %q", got, want)
		}
	})
}

// #911-4: Kimi's shared budget held the failure deadline, so a new grant could not shorten it.
func TestG3103KimiRegrantPassesBudget(t *testing.T) {
	scope := consent.ScopeKimiAccountUsageSavedLogin
	p, token := kimiLoginTestPaths(t)
	mode, hits := "ok", 0
	kimiLoginServer(t, token, &mode, &hits)
	credential := filepath.Join(p.ReaderAccess.Grants["kimi"].Profiles[0].Root, "credentials", "kimi-code.json")
	expired, _ := json.Marshal(map[string]any{"access_token": token, "expires_at": 1})
	if err := os.WriteFile(credential, expired, 0o600); err != nil {
		t.Fatal(err)
	}
	stamp := kimiNow.Add(-time.Hour)
	if err := os.Chtimes(credential, stamp, stamp); err != nil {
		t.Fatal(err)
	}
	p = g3103Desktop(t, "kimi", p)
	g3103FailThreeTimes(t, p, "kimi", scope, kimiNow)
	// The login file is unchanged: only the grant changes.
	g := p.ReaderAccess.Grants["kimi"]
	g.Generation = "synthetic-grant-002"
	p.ReaderAccess.Grants["kimi"] = g
	if !kimiBudgetDue(p.Cache, kimiNow.Add(35*time.Minute)) {
		t.Fatal("Kimi's shared budget still holds the failure back-off")
	}
	if !managedDue(p, "kimi", kimiNow.Add(35*time.Minute)) {
		t.Fatal("the hook path does not see the new grant")
	}
	if got := g3103Plan(t, p, scope, kimiNow.Add(35*time.Minute)); got.After(kimiNow.Add(35 * time.Minute)) {
		t.Fatalf("the app plans Kimi for %v after a new grant", got)
	}
	if err := ExecuteScopeRefresh(context.Background(), p, scope, kimiNow.Add(35*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if !g3103Attempted(t, p, "kimi", kimiNow.Add(35*time.Minute)) {
		t.Fatal("Kimi was not read after a new grant")
	}
	if kimiBudgetDue(p.Cache, kimiNow.Add(39*time.Minute)) {
		t.Fatal("the five-minute floor no longer holds")
	}
}
