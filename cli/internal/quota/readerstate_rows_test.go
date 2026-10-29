package quota

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"runtime"

	"github.com/modelplan/modelplan/cli/internal/keychain"
	"testing"
	"time"
)

func TestReaderProfileAttemptFailureAndRetention(t *testing.T) {
	p := claudeTestPaths(t)
	status := http.StatusOK
	paths := []string{}
	claudeTestServer(t, &status, &paths)
	if err := refreshManaged(context.Background(), p, "claude", claudeTestNow); err != nil {
		t.Fatal(err)
	}
	s, err := loadReaderState(p.Cache, "claude")
	if err != nil || len(s.Entries) != 1 {
		t.Fatal("missing initial per-profile reading", err)
	}
	first := s.Entries[0]
	if !first.AttemptedAt.Equal(claudeTestNow) || first.LastFailure != nil || first.Account == nil || first.Discarded || s.PendingAttempt != nil {
		t.Fatal("success did not record a completed profile attempt")
	}
	locator := readerProfileLocator(p.Cache, "claude", first.ProfileKey)
	if locator == "" || locator == first.ProfileKey {
		t.Fatal("authorized collection did not allocate a random profile reference")
	}
	status = http.StatusServiceUnavailable
	failedAt := claudeTestNow.Add(5 * time.Minute)
	if err := refreshManaged(context.Background(), p, "claude", failedAt); err != nil {
		t.Fatal(err)
	}
	s, err = loadReaderState(p.Cache, "claude")
	if err != nil {
		t.Fatal(err)
	}
	e := s.Entries[0]
	if !e.AttemptedAt.Equal(failedAt) || e.LastFailure == nil || e.LastFailure.Code != "http_5xx" || !e.LastFailure.At.Equal(failedAt) {
		t.Fatal("failed refresh lost its profile-specific code/time")
	}
	if e.Discarded || e.Account == nil || !e.Account.ObservedAt.Equal(first.Account.ObservedAt) || e.Metadata.CredentialKey != first.Metadata.CredentialKey {
		t.Fatal("same-login failure discarded the retained reading")
	}
	if readerProfileLocator(p.Cache, "claude", e.ProfileKey) != locator {
		t.Fatal("failed refresh changed profile reference")
	}
}

func TestReaderLoginAndGenerationChangeDiscardOldAccount(t *testing.T) {
	for _, change := range []string{"login", "generation"} {
		t.Run(change, func(t *testing.T) {
			p := claudeTestPaths(t)
			status := http.StatusOK
			paths := []string{}
			claudeTestServer(t, &status, &paths)
			if err := refreshManaged(context.Background(), p, "claude", claudeTestNow); err != nil {
				t.Fatal(err)
			}
			g := p.ReaderAccess.Grants["claude"]
			if change == "generation" {
				g.Generation = "synthetic-new-generation"
				p.ReaderAccess.Grants["claude"] = g
			}
			// A changed, expired login fails before HTTP. The predecessor's quota must
			// never be retained as if it belonged to the new login.
			writeClaudeCredential(t, g.Profiles[0].Root, "synthetic-different-login", claudeTestNow.Add(-time.Minute))
			at := claudeTestNow.Add(5 * time.Minute)
			if err := refreshManaged(context.Background(), p, "claude", at); err != nil {
				t.Fatal(err)
			}
			s, err := loadReaderState(p.Cache, "claude")
			if err != nil || len(s.Entries) != 1 {
				t.Fatal("missing failed profile attempt", err)
			}
			e := s.Entries[0]
			if e.Account != nil || !e.Discarded || e.LastFailure == nil || !e.LastFailure.At.Equal(at) || e.Metadata.CredentialKey != "" {
				t.Fatal("changed login/generation retained old account data")
			}
		})
	}
}

func TestReaderAttemptsBelongToProfilesNotProvider(t *testing.T) {
	p := claudeTestPaths(t)
	g := p.ReaderAccess.Grants["claude"]
	g.Profiles = append(g.Profiles, ReaderProfile{Root: t.TempDir()})
	p.ReaderAccess.Grants["claude"] = g
	old := claudeAccountReader.Managed
	claudeAccountReader.Managed = func(_ context.Context, _ *http.Client, r readerContext) readerOutcome {
		s, err := loadReaderState(p.Cache, "claude")
		if err != nil || s.PendingAttempt == nil || s.PendingAttempt.ProfileKey != r.ProfileKey || !s.PendingAttempt.At.Equal(r.Now) {
			t.Fatal("profile attempt not reserved before credential I/O")
		}
		if r.Profile.Root == g.Profiles[1].Root {
			return readerOutcome{Entry: readerEntry{Status: "unavailable", ErrorCode: "network"}}
		}
		return readerOutcome{Entry: readerEntry{Status: "ok", Account: &Account{Source: "claude-code", ObservedAt: r.Now, Windows: []Window{}}}}
	}
	t.Cleanup(func() { claudeAccountReader.Managed = old })
	for _, minutes := range []int{0, 5} {
		if err := refreshManaged(context.Background(), p, "claude", claudeTestNow.Add(time.Duration(minutes)*time.Minute)); err != nil {
			t.Fatal(err)
		}
	}
	s, err := loadReaderState(p.Cache, "claude")
	if err != nil || len(s.Entries) != 2 {
		t.Fatal("missing profile results", err)
	}
	a, b := s.Entries[0], s.Entries[1]
	if !a.AttemptedAt.Equal(claudeTestNow) || a.LastFailure != nil || a.Account == nil || !b.AttemptedAt.Equal(claudeTestNow.Add(5*time.Minute)) || b.LastFailure == nil || b.LastFailure.Code != "network" || b.Account != nil {
		t.Fatal("provider attempt time/failure leaked across profiles")
	}
}

func TestReaderLocatorUsesExactExistingIdentityBinding(t *testing.T) {
	p := claudeTestPaths(t)
	key := readerHash(p.Cache, "claude:profile", "synthetic-profile")
	basis := readerProfileBasis("claude")
	ref := assignSubscription(p.Cache, basis, key, claudeTestNow)
	if ref == "" || readerProfileLocator(p.Cache, "claude", key) != ref {
		t.Fatal("existing profile binding not found")
	}
	if readerProfileLocator(p.Cache, "grok", key) != "" || readerProfileLocator(p.Cache, "claude", "different-profile") != "" {
		t.Fatal("accepted reference from another profile/provider")
	}
	b, err := os.ReadFile(subscriptionsPath(p.Cache))
	if err != nil {
		t.Fatal(err)
	}
	var m subscriptionMap
	if json.Unmarshal(b, &m) != nil {
		t.Fatal("invalid fixture identity store")
	}
	for id, item := range m.Refs {
		if item.Ref == ref {
			item.Basis = "unrelated-basis"
			m.Refs[id] = item
		}
	}
	b, _ = json.Marshal(m)
	if err := os.WriteFile(subscriptionsPath(p.Cache), b, 0600); err != nil {
		t.Fatal(err)
	}
	if readerProfileLocator(p.Cache, "claude", key) != "" {
		t.Fatal("accepted charset-valid reference without provenance")
	}
}

func TestReaderIdentityOffDoesNotAllocateProfileReference(t *testing.T) {
	p := claudeTestPaths(t)
	t.Setenv("MODELPLAN_IDENTITY", "off")
	old := claudeAccountReader.Managed
	claudeAccountReader.Managed = func(_ context.Context, _ *http.Client, r readerContext) readerOutcome {
		return readerOutcome{Entry: readerEntry{Status: "ok", Account: &Account{ObservedAt: r.Now}}}
	}
	t.Cleanup(func() { claudeAccountReader.Managed = old })
	if err := refreshManaged(context.Background(), p, "claude", claudeTestNow); err != nil {
		t.Fatal(err)
	}
	s, _ := loadReaderState(p.Cache, "claude")
	key := s.Entries[0].ProfileKey
	if readerProfileLocator(p.Cache, "claude", key) != "" || lookupSubscription(p.Cache, readerProfileBasis("claude"), key) != "" {
		t.Fatal("identity-off collection allocated or exposed profile reference")
	}
	// An existing reference must also be hidden while identity is off.
	assignSubscription(p.Cache, readerProfileBasis("claude"), key, claudeTestNow)
	if readerProfileLocator(p.Cache, "claude", key) != "" {
		t.Fatal("identity-off read exposed cached profile reference")
	}
}

func TestReadOnlyReaderHashDoesNotInitializeIdentityStore(t *testing.T) {
	cache := filepath.Join(t.TempDir(), "absent-cache")
	if lookupReaderHash(cache, "claude:profile", "synthetic-profile") != "" || readerProfileLocator(cache, "claude", "synthetic-profile") != "" {
		t.Fatal("missing identity store produced reference")
	}
	if _, err := os.Stat(cache); !os.IsNotExist(err) {
		t.Fatal("read-only lookup created cache files")
	}
}

func TestClaudeCredentialReadBlockFact(t *testing.T) {
	for _, tc := range []struct {
		name, file, choice, want string
		prior                    bool
		exit                     int
		canceled, busy           bool
	}{
		{name: "unset-missing", choice: "unset", want: "unset"},
		{name: "denied-missing", choice: "denied", want: "denied"},
		{name: "keychain-denied", choice: "allowed", prior: true, exit: 128, want: "denied"},
		{name: "keychain-not-found", choice: "allowed", prior: true, exit: 44, want: "not-found"},
		{name: "keychain-unavailable", choice: "allowed", prior: true, exit: 1, want: "unavailable"},
		{name: "keychain-confirmation", choice: "allowed", want: "keychain-confirmation-needed"},
		{name: "keychain-canceled", choice: "allowed", prior: true, canceled: true, want: "canceled"},
		{name: "keychain-busy", choice: "allowed", prior: true, busy: true, want: "busy"},
		{name: "readable-invalid-file", file: "invalid", choice: "denied"},
		{name: "readable-file-unset", file: "valid", choice: "unset"},
		{name: "readable-file-denied", file: "valid", choice: "denied"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			p := claudeTestPaths(t)
			// Explicit synthetic HOME: every credential and Keychain-state fixture below
			// lives under a testing-owned temporary directory, never the owner's home.
			syntheticHome := t.TempDir()
			t.Setenv("HOME", syntheticHome)
			t.Setenv("CLAUDE_CONFIG_DIR", "")
			root := filepath.Join(syntheticHome, ".claude")
			if err := os.MkdirAll(root, 0700); err != nil {
				t.Fatal(err)
			}
			g := p.ReaderAccess.Grants["claude"]
			g.Profiles = []ReaderProfile{{Root: root}}
			g.Keychain = tc.choice == "allowed"
			g.KeychainConsent, g.KeychainPriorGrant = tc.choice, tc.prior
			if tc.file == "valid" {
				writeClaudeCredential(t, root, "synthetic-access-token", claudeTestNow.Add(time.Hour))
			}
			if tc.file == "invalid" {
				if err := os.WriteFile(filepath.Join(root, ".credentials.json"), []byte("{"), 0600); err != nil {
					t.Fatal(err)
				}
			}
			if tc.busy {
				dir := filepath.Join(p.Cache, "observed", "keychain")
				if err := os.MkdirAll(dir, 0700); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(filepath.Join(dir, "claude-code.json.lock"), nil, 0600); err != nil {
					t.Fatal(err)
				}
			}
			old := claudeSecurity
			calls := 0
			claudeSecurity = func(context.Context, string, ...string) (keychain.ProcessResult, error) {
				calls++
				return keychain.ProcessResult{ExitCode: tc.exit}, nil
			}
			t.Cleanup(func() { claudeSecurity = old })
			status, paths := http.StatusOK, []string{}
			claudeTestServer(t, &status, &paths)
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			if tc.canceled {
				cancel()
			}
			key := readerHash(p.Cache, "claude:profile", root+"\x00")
			out := collectClaudeAccount(ctx, nativeClient, readerContext{Paths: p, Grant: g, Profile: g.Profiles[0], ProfileKey: key, Now: claudeTestNow})
			want := tc.want
			if runtime.GOOS != "darwin" && !g.Keychain {
				want = ""
			}
			if out.Entry.CredentialReadState != want {
				t.Fatalf("credential-read block = %q, want %q", out.Entry.CredentialReadState, want)
			}
			if tc.file != "" && calls != 0 {
				t.Fatal("readable file invoked Keychain")
			}
			if tc.file == "valid" && (out.Entry.Status != "ok" || len(paths) != 2) {
				t.Fatal("saved Keychain choice blocked working credentials file")
			}
		})
	}
}
