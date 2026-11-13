package quota

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// G3-103 (owner build 14e): after signing in to Grok again, and after unticking and re-ticking
// it in Settings, Grok still did not appear. Each failed read doubled the back-off up to an hour
// and neither a new sign-in nor a new grant shortened it. A changed sign-in file or a new grant
// now allows the next read at the five-minute floor; a provider's Retry-After still holds.
func TestG3103GrokReadsAgainAfterSignInOrRegrant(t *testing.T) {
	expiredThreeTimes := func(t *testing.T) (Paths, string, *string, *int) {
		t.Helper()
		p := grokTestPaths(t)
		root := p.ReaderAccess.Grants["grok"].Profiles[0].Root
		writeGrokAuth(t, root, grokAuth{Key: "synthetic-grok-access", Mode: "oidc", User: "synthetic-grok-user", Issuer: "https://auth.x.ai", Client: grokDefaultClient, Expires: grokNow.Add(-time.Hour).Format(time.RFC3339)})
		touchGrokAuth(t, root, grokNow.Add(-time.Hour))
		mode, hits := "ok", 0
		grokTestServer(t, &mode, &hits)
		for _, at := range []time.Duration{0, 10 * time.Minute, 30 * time.Minute} {
			if err := RefreshNative(context.Background(), p, grokNow.Add(at)); err != nil {
				t.Fatal(err)
			}
		}
		s, _ := loadReaderState(p.Cache, "grok")
		if hits != 0 || s.Failures != 3 || !s.NextAttemptAt.Equal(grokNow.Add(70*time.Minute)) {
			t.Fatalf("setup: hits=%d failures=%d next=%v", hits, s.Failures, s.NextAttemptAt)
		}
		return p, root, &mode, &hits
	}
	t.Run("signed in again", func(t *testing.T) {
		p, root, _, hits := expiredThreeTimes(t)
		if err := RefreshNative(context.Background(), p, grokNow.Add(34*time.Minute)); err != nil || *hits != 0 {
			t.Fatalf("an unchanged sign-in keeps the back-off: %v hits=%d", err, *hits)
		}
		writeGrokAuth(t, root, grokAuth{Key: "synthetic-grok-access", Mode: "oidc", User: "synthetic-grok-user", Issuer: "https://auth.x.ai", Client: grokDefaultClient, Expires: grokNow.Add(48 * time.Hour).Format(time.RFC3339)})
		touchGrokAuth(t, root, grokNow.Add(33*time.Minute))
		if !NativeDue(p, grokNow.Add(35*time.Minute)) {
			t.Fatal("the scheduler does not see the new sign-in")
		}
		if err := RefreshNative(context.Background(), p, grokNow.Add(35*time.Minute)); err != nil {
			t.Fatal(err)
		}
		s, _ := loadReaderState(p.Cache, "grok")
		if *hits != 1 || s.Entries[0].Status != "ok" || s.Failures != 0 {
			t.Fatalf("not read after signing in again: hits=%d status=%s", *hits, s.Entries[0].Status)
		}
	})
	t.Run("ticked again in Settings", func(t *testing.T) {
		p, root, _, hits := expiredThreeTimes(t)
		writeGrokAuth(t, root, grokAuth{Key: "synthetic-grok-access", Mode: "oidc", User: "synthetic-grok-user", Issuer: "https://auth.x.ai", Client: grokDefaultClient, Expires: grokNow.Add(48 * time.Hour).Format(time.RFC3339)})
		touchGrokAuth(t, root, grokNow.Add(-time.Hour)) // same stamp: only the grant changes
		g := p.ReaderAccess.Grants["grok"]
		g.Generation = "synthetic-grant-002"
		p.ReaderAccess.Grants["grok"] = g
		if err := RefreshNative(context.Background(), p, grokNow.Add(32*time.Minute)); err != nil || *hits != 0 {
			t.Fatalf("the five-minute floor holds: %v hits=%d", err, *hits)
		}
		if err := RefreshNative(context.Background(), p, grokNow.Add(35*time.Minute)); err != nil {
			t.Fatal(err)
		}
		if *hits != 1 {
			t.Fatalf("not read after the new grant: hits=%d", *hits)
		}
	})
	t.Run("Retry-After still holds", func(t *testing.T) {
		p := grokTestPaths(t)
		mode, hits := "limited", 0
		grokTestServer(t, &mode, &hits)
		if err := RefreshNative(context.Background(), p, grokNow); err != nil || hits != 1 {
			t.Fatalf("%v hits=%d", err, hits)
		}
		g := p.ReaderAccess.Grants["grok"]
		g.Generation = "synthetic-grant-002"
		p.ReaderAccess.Grants["grok"] = g
		touchGrokAuth(t, g.Profiles[0].Root, grokNow.Add(time.Minute))
		if err := RefreshNative(context.Background(), p, grokNow.Add(10*time.Minute)); err != nil || hits != 1 {
			t.Fatalf("a rate limit was retried early: %v hits=%d", err, hits)
		}
	})
}

func touchGrokAuth(t *testing.T, root string, at time.Time) {
	t.Helper()
	if err := os.Chtimes(filepath.Join(root, "auth.json"), at, at); err != nil {
		t.Fatal(err)
	}
}
