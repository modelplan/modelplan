package quota

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io/fs"
	"net/http"
	"os"
	"path/filepath"
	"reflect"
	"runtime"

	"github.com/modelplan/modelplan/cli/internal/keychain"
	"github.com/modelplan/modelplan/cli/internal/rows"
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
	if !first.AttemptedAt.Equal(claudeTestNow) || first.LastFailure != nil || first.Account == nil || (first.LoginChanged || first.GenerationChanged) || len(s.PendingAttempts) != 0 {
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
	if (e.LoginChanged || e.GenerationChanged) || e.Account == nil || !e.Account.ObservedAt.Equal(first.Account.ObservedAt) || e.Metadata.CredentialKey != first.Metadata.CredentialKey {
		t.Fatal("same-login failure discarded the retained reading")
	}
	if readerProfileLocator(p.Cache, "claude", e.ProfileKey) != locator {
		t.Fatal("failed refresh changed profile reference")
	}
}

func TestManagedRowsRetainedFailureAndIdentityOff(t *testing.T) {
	p := claudeTestPaths(t)
	status, paths := http.StatusOK, []string{}
	claudeTestServer(t, &status, &paths)
	if err := refreshManaged(context.Background(), p, "claude", claudeTestNow); err != nil {
		t.Fatal(err)
	}
	status = http.StatusServiceUnavailable
	at := claudeTestNow.Add(5 * time.Minute)
	if err := refreshManaged(context.Background(), p, "claude", at); err != nil {
		t.Fatal(err)
	}
	in := rows.Input{Now: at}
	AppendManagedRows(&in, p)
	if len(in.Profiles) != 1 || len(in.Accounts) != 1 {
		t.Fatal("retained account/profile missing")
	}
	f := in.Profiles[0]
	if f.LatestAttempt != rows.AttemptResultFailed || f.LastFailure == nil || f.LastFailure.Code != "http_5xx" || f.LastFailure.At == nil || !f.LastFailure.At.Equal(at) || f.ObservedAt == nil || !f.ObservedAt.Equal(claudeTestNow) || !f.WithinFreshness || f.FreshUntil == nil || !f.FreshUntil.Equal(claudeTestNow.Add(staleAfter)) || f.AccountLocator == nil || in.Accounts[0].SubscriptionRef == nil {
		t.Fatal("rows lost retained-value or existing identity facts")
	}
	for _, mode := range []string{"input", "environment"} {
		t.Run(mode, func(t *testing.T) {
			if mode == "environment" {
				t.Setenv("MODELPLAN_IDENTITY", "off")
			}
			in := rows.Input{Now: at, IdentityOff: mode == "input"}
			AppendManagedRows(&in, p)
			if len(in.Profiles) != 1 || in.Profiles[0].AccountLocator != nil || len(in.Accounts) != 1 || in.Accounts[0].SubscriptionRef != nil {
				t.Fatal("identity-off rows exposed existing references")
			}
		})
	}
	// A new grant cannot export the prior generation even before collection.
	g := p.ReaderAccess.Grants["claude"]
	g.Generation = "synthetic-new-grant"
	p.ReaderAccess.Grants["claude"] = g
	changed := rows.Input{Now: at}
	AppendManagedRows(&changed, p)
	if len(changed.Accounts) != 0 || len(changed.Profiles) != 1 || !changed.Profiles[0].GenerationChanged || changed.Profiles[0].ObservedAt != nil {
		t.Fatal("generation mismatch exposed old account")
	}
}

func readerTreeSnapshot(t *testing.T, root string) map[string]string {
	t.Helper()
	out := map[string]string{}
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		var sum [32]byte
		if entry.Type().IsRegular() {
			b, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			sum = sha256.Sum256(b)
		}
		out[path] = fmt.Sprintf("%s/%d/%x", info.Mode(), info.ModTime().UnixNano(), sum)
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return out
}

func TestManagedRowsReadOnlyPreRowsCacheAndUnknownProfileTimes(t *testing.T) {
	p := claudeTestPaths(t)
	g := p.ReaderAccess.Grants["claude"]
	g.Profiles = append(g.Profiles, ReaderProfile{Root: t.TempDir()})
	// The adapter must use this captured admission without re-reading consent.
	g.StillValid = func() bool { t.Fatal("rows adapter re-read admission"); return false }
	p.ReaderAccess.Grants["claude"] = g
	keyA := readerHash(p.Cache, "claude:profile", g.Profiles[0].Root+"\x00"+g.Profiles[0].AccountFile)
	keyB := readerHash(p.Cache, "claude:profile", g.Profiles[1].Root+"\x00")
	grant := readerHash(p.Cache, "claude:grant", g.Generation)
	// Deliberately use the old on-disk shape, without any rows metadata. The
	// provider's latest attempt belongs to B, never A, and proves no A timestamp.
	old := map[string]any{"schemaVersion": 1, "provider": "claude", "grantKey": grant, "attemptedAt": claudeTestNow, "nextAttemptAt": claudeTestNow.Add(time.Minute), "entries": []any{
		map[string]any{"profileKey": keyA, "status": "ok", "account": &Account{Source: "claude-code", ObservedAt: claudeTestNow.Add(-5 * time.Minute), Windows: []Window{}}},
		map[string]any{"profileKey": keyB, "status": "unavailable", "errorCode": "network"},
	}}
	b, _ := json.Marshal(old)
	if err := os.MkdirAll(filepath.Dir(readerPath(p.Cache, "claude")), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(readerPath(p.Cache, "claude"), b, 0600); err != nil {
		t.Fatal(err)
	}
	before := readerTreeSnapshot(t, p.Cache)
	legacyBefore := Report{}
	applyManaged(&legacyBefore, p, "claude", claudeTestNow)
	legacyBytes, _ := json.Marshal(legacyBefore)
	for range 2 {
		in := rows.Input{Now: claudeTestNow, ReadOnly: true}
		AppendManagedRows(&in, p)
		if len(in.Profiles) != 2 || len(in.Accounts) != 1 {
			t.Fatal("pre-rows profile facts lost")
		}
		a, b := in.Profiles[0], in.Profiles[1]
		if a.LatestAttempt != rows.AttemptResultSucceeded || a.AttemptedAt != nil || !a.WithinFreshness || a.AccountLocator != nil || b.LatestAttempt != rows.AttemptResultFailed || b.AttemptedAt != nil || b.LastFailure == nil || b.LastFailure.Code != "network" || b.LastFailure.At != nil || b.AccountLocator != nil {
			t.Fatal("old cache synthesized per-profile times or references")
		}
	}
	if !reflect.DeepEqual(before, readerTreeSnapshot(t, p.Cache)) {
		t.Fatal("read-only rows migrated or wrote the cache")
	}
	legacyAfter := Report{}
	applyManaged(&legacyAfter, p, "claude", claudeTestNow)
	afterBytes, _ := json.Marshal(legacyAfter)
	if string(legacyBytes) != string(afterBytes) {
		t.Fatal("rows adapter changed legacy quota JSON")
	}
}

func TestManagedRowsObservationAndFreshnessFacts(t *testing.T) {
	for _, tc := range []struct {
		name             string
		observed         time.Time
		within, deadline bool
	}{
		{"known", claudeTestNow, true, true},
		{"unknown", time.Time{}, false, false},
		{"future", claudeTestNow.Add(time.Minute), false, false},
		{"aged", claudeTestNow.Add(-staleAfter - time.Second), false, true},
		{"at-deadline", claudeTestNow.Add(-staleAfter), false, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			p := claudeTestPaths(t)
			g := p.ReaderAccess.Grants["claude"]
			profile := g.Profiles[0]
			key := readerHash(p.Cache, "claude:profile", profile.Root+"\x00"+profile.AccountFile)
			grant := readerHash(p.Cache, "claude:grant", g.Generation)
			s := &readerState{SchemaVersion: 1, Provider: "claude", GrantKey: grant, Entries: []readerEntry{{ProfileKey: key, Status: "ok", AttemptedAt: claudeTestNow, Account: &Account{Source: "claude-code", ObservedAt: tc.observed, Windows: []Window{}}}}}
			if err := saveReaderState(p.Cache, s); err != nil {
				t.Fatal(err)
			}
			in := rows.Input{Now: claudeTestNow}
			AppendManagedRows(&in, p)
			if len(in.Profiles) != 1 {
				t.Fatal("profile missing")
			}
			f := in.Profiles[0]
			if f.WithinFreshness != tc.within || (f.FreshUntil != nil) != tc.deadline || (f.ObservedAt == nil) != tc.observed.IsZero() {
				t.Fatal("observation/freshness facts were invented or lost")
			}
			if f.ObservedAt != nil && !f.ObservedAt.Equal(tc.observed) {
				t.Fatal("raw future observation time not preserved for classifier")
			}
		})
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
			if e.Account != nil || !(e.LoginChanged || e.GenerationChanged) || e.LastFailure == nil || !e.LastFailure.At.Equal(at) || e.Metadata.CredentialKey != "" {
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
		if err != nil || len(s.PendingAttempts) != 1 || s.PendingAttempts[0].ProfileKey != r.ProfileKey || !s.PendingAttempts[0].At.Equal(r.Now) {
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
	in := rows.Input{Now: claudeTestNow, ReadOnly: true}
	p := Paths{Cache: cache, ReaderAccess: &ReaderAccess{Grants: map[string]ReaderGrant{
		"claude": {SavedLogin: true, Generation: "synthetic-first-grant", Profiles: []ReaderProfile{{Root: filepath.Join(t.TempDir(), "absent-tool-root")}}},
	}}}
	AppendManagedRows(&in, p)
	if len(in.Profiles) != 1 || in.Profiles[0].LatestAttempt != rows.AttemptResultNever || in.Profiles[0].AccountLocator != nil || len(in.Accounts) != 0 {
		t.Fatal("first read invented an identity, attempt or account")
	}
	if _, err := os.Stat(cache); !os.IsNotExist(err) {
		t.Fatal("read-only lookup or rows adapter created cache files")
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
		{name: "unreadable-file", file: "unreadable", choice: "denied"},
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
			if tc.file == "unreadable" {
				if err := os.Mkdir(filepath.Join(root, ".credentials.json"), 0700); err != nil {
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
			// Consume exactly the persisted collector fact through the shared
			// interface. Saved permission alone creates no Keychain block.
			out.Entry.ProfileKey = key
			grantKey := readerHash(p.Cache, "claude:grant", g.Generation)
			if err := saveReaderState(p.Cache, &readerState{SchemaVersion: 1, Provider: "claude", GrantKey: grantKey, Entries: []readerEntry{out.Entry}}); err != nil {
				t.Fatal(err)
			}
			p.ReaderAccess.Grants["claude"] = g
			in := rows.Input{Now: claudeTestNow}
			AppendManagedRows(&in, p)
			if want == "" {
				if len(in.KeychainBlocks) != 0 {
					t.Fatal("file read inferred a block from saved permission")
				}
			} else if len(in.KeychainBlocks) != 1 || in.KeychainBlocks[0].Status != want || in.KeychainBlocks[0].Blocked != (want != "busy") || in.Profiles[0].Busy != (want == "busy") {
				t.Fatal("rows lost actual Keychain block or confused busy with a block")
			}
			if want == "busy" && (in.Profiles[0].LatestAttempt == rows.AttemptResultFailed || in.Profiles[0].LastFailure != nil) {
				t.Fatal("busy Keychain read was exposed as a completed failure")
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

func TestManagedRowsGenerationDiscardsEveryProfileUntilNewSuccess(t *testing.T) {
	p := claudeTestPaths(t)
	g := p.ReaderAccess.Grants["claude"]
	g.Profiles = append(g.Profiles, ReaderProfile{Root: t.TempDir()})
	p.ReaderAccess.Grants["claude"] = g
	old := claudeAccountReader.Managed
	fail := false
	claudeAccountReader.Managed = func(_ context.Context, _ *http.Client, r readerContext) readerOutcome {
		if fail {
			return readerOutcome{Entry: readerEntry{Status: "unavailable", ErrorCode: "network"}}
		}
		return readerOutcome{Entry: readerEntry{Status: "ok", Account: &Account{Source: "claude-code", ObservedAt: r.Now, Windows: []Window{}}}}
	}
	t.Cleanup(func() { claudeAccountReader.Managed = old })
	for _, minute := range []int{0, 5} {
		if err := refreshManaged(context.Background(), p, "claude", claudeTestNow.Add(time.Duration(minute)*time.Minute)); err != nil {
			t.Fatal(err)
		}
	}
	g.Generation = "synthetic-replacement-generation"
	p.ReaderAccess.Grants["claude"] = g
	fail = true
	at := claudeTestNow.Add(10 * time.Minute)
	if err := refreshManaged(context.Background(), p, "claude", at); err != nil {
		t.Fatal(err)
	}
	in := rows.Input{Now: at}
	AppendManagedRows(&in, p)
	if len(in.Profiles) != 2 || len(in.Accounts) != 0 {
		t.Fatal("generation change retained a profile's old numbers")
	}
	for _, f := range in.Profiles {
		if !f.GenerationChanged || f.ObservedAt != nil {
			t.Fatal("unvisited profile lost its generation-discard fact")
		}
	}
	fail = false
	at = claudeTestNow.Add(20 * time.Minute)
	if err := refreshManaged(context.Background(), p, "claude", at); err != nil {
		t.Fatal(err)
	}
	in = rows.Input{Now: at}
	AppendManagedRows(&in, p)
	if len(in.Accounts) != 1 || !in.Profiles[0].GenerationChanged || in.Profiles[1].GenerationChanged || in.Profiles[1].LatestAttempt != rows.AttemptResultSucceeded {
		t.Fatal("new success did not release only its own generation discard")
	}
}

func TestReaderSubscriptionReferenceRequiresStoreMembership(t *testing.T) {
	p := claudeTestPaths(t)
	ref := assignSubscription(p.Cache, "claude-oauth", "synthetic-account", claudeTestNow)
	binding := &Binding{Ref: ref, Basis: "claude-oauth", Status: "verified"}
	if ref == "" || existingReaderSubscription(p.Cache, "claude", binding) != ref {
		t.Fatal("existing verified subscription reference lost")
	}
	fabricated := *binding
	fabricated.Ref = "1234567890abcdef"
	if existingReaderSubscription(p.Cache, "claude", &fabricated) != "" {
		t.Fatal("accepted a charset-valid invented reference")
	}
	if existingReaderSubscription(p.Cache, "grok", binding) != "" {
		t.Fatal("accepted another reader's subscription reference")
	}
	fabricated = *binding
	fabricated.Status = "unknown"
	if existingReaderSubscription(p.Cache, "claude", &fabricated) != "" {
		t.Fatal("accepted unverified identity")
	}
	t.Setenv("MODELPLAN_IDENTITY", "off")
	if existingReaderSubscription(p.Cache, "claude", binding) != "" {
		t.Fatal("identity off exposed existing subscription")
	}
}

func TestManagedRowsInterruptedAttemptSurvivesAnotherProfileRefresh(t *testing.T) {
	p := claudeTestPaths(t)
	g := p.ReaderAccess.Grants["claude"]
	g.Profiles = append(g.Profiles, ReaderProfile{Root: t.TempDir()})
	p.ReaderAccess.Grants["claude"] = g
	keyA := readerHash(p.Cache, "claude:profile", g.Profiles[0].Root+"\x00"+g.Profiles[0].AccountFile)
	grant := readerHash(p.Cache, "claude:grant", g.Generation)
	interruptedAt := claudeTestNow.Add(5 * time.Minute)
	s := &readerState{SchemaVersion: 1, Provider: "claude", GrantKey: grant, NextProfile: 1, NextAttemptAt: interruptedAt.Add(5 * time.Minute),
		Entries:         []readerEntry{{ProfileKey: keyA, Status: "ok", AttemptedAt: claudeTestNow, Account: &Account{ObservedAt: claudeTestNow, Windows: []Window{}}}},
		PendingAttempts: []readerProfileAttempt{{ProfileKey: keyA, At: interruptedAt}},
	}
	if err := saveReaderState(p.Cache, s); err != nil {
		t.Fatal(err)
	}
	old := claudeAccountReader.Managed
	claudeAccountReader.Managed = func(_ context.Context, _ *http.Client, r readerContext) readerOutcome {
		return readerOutcome{Entry: readerEntry{Status: "ok", Account: &Account{ObservedAt: r.Now, Windows: []Window{}}}}
	}
	t.Cleanup(func() { claudeAccountReader.Managed = old })
	now := claudeTestNow.Add(10 * time.Minute)
	if err := refreshManaged(context.Background(), p, "claude", now); err != nil {
		t.Fatal(err)
	}
	in := rows.Input{Now: now}
	AppendManagedRows(&in, p)
	if len(in.Profiles) != 2 {
		t.Fatal("missing profiles")
	}
	a, b := in.Profiles[0], in.Profiles[1]
	if a.LatestAttempt != rows.AttemptResultNever || a.AttemptedAt == nil || !a.AttemptedAt.Equal(interruptedAt) || a.Busy || a.ObservedAt == nil || !a.ObservedAt.Equal(claudeTestNow) || b.LatestAttempt != rows.AttemptResultSucceeded {
		t.Fatal("another profile erased the interrupted attempt or advertised it as success")
	}
}

func TestManagedRowsCoolingDownUsesAllPersistedReservations(t *testing.T) {
	for _, provider := range []string{"claude", "cursor", "grok", "kimi"} {
		t.Run(provider, func(t *testing.T) {
			cache := t.TempDir()
			next := claudeTestNow.Add(15 * time.Minute)
			if err := reserveReaderAttempt(cache, provider, next); err != nil {
				t.Fatal(err)
			}
			if provider == "kimi" {
				if err := kimiFinish(cache, next.Add(time.Minute)); err != nil {
					t.Fatal(err)
				}
				next = next.Add(time.Minute)
			}
			if provider == "cursor" || provider == "grok" {
				if err := reserveXSubscription(cache, provider, next); err != nil {
					t.Fatal(err)
				}
				next = next.Add(5 * time.Minute)
			}
			before := readerTreeSnapshot(t, cache)
			got, known := managedReaderNext(cache, provider, claudeTestNow.Add(time.Minute))
			if !known || !got.Equal(next) {
				t.Fatal("lost independent/shared reservation")
			}
			if !reflect.DeepEqual(before, readerTreeSnapshot(t, cache)) {
				t.Fatal("reading budget state wrote files")
			}
			if err := os.WriteFile(readerAttemptPath(cache, provider), []byte("{"), 0600); err != nil {
				t.Fatal(err)
			}
			if got, known := managedReaderNext(cache, provider, time.Time{}); known || !got.IsZero() {
				t.Fatal("unreadable gate advertised an available refresh")
			}
		})
	}
}

func TestManagedRowsUnboundCacheCannotExportOldAccount(t *testing.T) {
	p := claudeTestPaths(t)
	g := p.ReaderAccess.Grants["claude"]
	profile := g.Profiles[0]
	key := readerHash(p.Cache, "claude:profile", profile.Root+"\x00"+profile.AccountFile)
	// A cache without its grant binding cannot establish that its old numbers
	// belong to the captured generation, even if the profile key still matches.
	s := &readerState{SchemaVersion: 1, Provider: "claude", Entries: []readerEntry{{ProfileKey: key, Status: "ok", Account: &Account{Source: "claude-code", ObservedAt: claudeTestNow, Windows: []Window{}}}}}
	if err := saveReaderState(p.Cache, s); err != nil {
		t.Fatal(err)
	}
	before := readerTreeSnapshot(t, p.Cache)
	in := rows.Input{Now: claudeTestNow, ReadOnly: true}
	AppendManagedRows(&in, p)
	if len(in.Accounts) != 0 || len(in.Profiles) != 1 || !in.Profiles[0].GenerationChanged || in.Profiles[0].ObservedAt != nil {
		t.Fatal("cache without generation provenance exported an old account")
	}
	if !reflect.DeepEqual(before, readerTreeSnapshot(t, p.Cache)) {
		t.Fatal("unbound-cache read migrated state")
	}
}

func TestGeminiCollectedSubscriptionSurvivesReadOnlyRowsProjection(t *testing.T) {
	p := geminiTestPaths(t)
	mode, calls := "ok", []string{}
	geminiServer(t, &mode, &calls)
	if err := RefreshNative(context.Background(), p, geminiNow); err != nil {
		t.Fatal(err)
	}
	state, err := loadReaderState(p.Cache, "gemini")
	if err != nil || len(state.Entries) != 1 || state.Entries[0].Status != "ok" || state.Entries[0].Account == nil {
		t.Fatal("Gemini collection did not produce a successful account", err)
	}
	binding := state.Entries[0].Account.Subscription
	allocated := lookupSubscription(p.Cache, "gemini-cli-account-project", "synthetic-google-subject\x00synthetic-project-001")
	if allocated == "" || binding == nil || binding.Ref != allocated || binding.Status != "verified" || binding.Basis != "gemini-cli-local-account-project" {
		t.Fatal("Gemini fixture did not exercise its actual allocation/binding pair")
	}
	before := readerTreeSnapshot(t, p.Cache)
	root := p.ReaderAccess.Grants["gemini"].Profiles[0].Root
	sourceBefore := readerTreeSnapshot(t, root)
	legacyBefore := Report{}
	applyManaged(&legacyBefore, p, "gemini", geminiNow)
	legacyJSON, _ := json.Marshal(legacyBefore)

	in := rows.Input{Now: geminiNow, ReadOnly: true}
	AppendManagedRows(&in, p)
	if len(in.Accounts) != 1 || in.Accounts[0].SubscriptionRef == nil || *in.Accounts[0].SubscriptionRef != allocated {
		t.Fatal("rows projection lost Gemini's existing verified subscription reference")
	}
	if len(calls) != 2 {
		t.Fatal("cache-only projection contacted the Gemini source")
	}
	for _, mode := range []string{"input", "environment"} {
		t.Run(mode, func(t *testing.T) {
			if mode == "environment" {
				t.Setenv("MODELPLAN_IDENTITY", "off")
			}
			hidden := rows.Input{Now: geminiNow, ReadOnly: true, IdentityOff: mode == "input"}
			AppendManagedRows(&hidden, p)
			if len(hidden.Accounts) != 1 || hidden.Accounts[0].SubscriptionRef != nil || len(hidden.Profiles) != 1 || hidden.Profiles[0].AccountLocator != nil {
				t.Fatal("identity-off projection exposed a Gemini identity reference")
			}
		})
	}
	if !reflect.DeepEqual(before, readerTreeSnapshot(t, p.Cache)) || !reflect.DeepEqual(sourceBefore, readerTreeSnapshot(t, root)) {
		t.Fatal("read-only projection wrote the cache or synthetic Gemini source")
	}
	legacyAfter := Report{}
	applyManaged(&legacyAfter, p, "gemini", geminiNow)
	afterJSON, _ := json.Marshal(legacyAfter)
	if string(legacyJSON) != string(afterJSON) {
		t.Fatal("rows projection changed Gemini's legacy quota JSON")
	}
}

func TestManagedReaderSubscriptionBasisPairs(t *testing.T) {
	pairs := []struct{ provider, stored, binding string }{
		{"claude", "claude-oauth", "claude-oauth"},
		{"cursor", "cursor-auth", "cursor-auth"},
		{"gemini", "gemini-cli-account-project", "gemini-cli-local-account-project"},
		{"grok", "grok-auth-principal", "grok-auth-principal"},
		{"kimi", "kimi-code-login:china", "kimi-code-login:china"},
	}
	covered := map[string]bool{}
	for _, pair := range pairs {
		covered[pair.provider] = true
		t.Run(pair.provider, func(t *testing.T) {
			t.Setenv("MODELPLAN_IDENTITY", "")
			cache := t.TempDir()
			ref := assignSubscription(cache, pair.stored, "synthetic-subject", claudeTestNow)
			binding := &Binding{Ref: ref, Basis: pair.binding, Status: "verified"}
			if ref == "" || existingReaderSubscription(cache, pair.provider, binding) != ref {
				t.Fatal("actual reader allocation/binding pair lost its reference")
			}
			wrongBinding := *binding
			wrongBinding.Basis = "unrelated-binding"
			if existingReaderSubscription(cache, pair.provider, &wrongBinding) != "" {
				t.Fatal("accepted an unrelated binding vocabulary")
			}
			// Membership alone is insufficient: a real ref from the profile
			// namespace is not a verified subscription for this reader.
			wrongStoreRef := assignSubscription(cache, readerProfileBasis(pair.provider), "synthetic-subject", claudeTestNow)
			wrongStore := *binding
			wrongStore.Ref = wrongStoreRef
			if wrongStoreRef == "" || existingReaderSubscription(cache, pair.provider, &wrongStore) != "" {
				t.Fatal("accepted an existing reference from the wrong store basis")
			}
			if pair.binding != pair.stored {
				// The published Gemini label is not an alternate storage basis.
				wrongStore.Ref = assignSubscription(cache, pair.binding, "synthetic-subject", claudeTestNow)
				if wrongStore.Ref == "" || existingReaderSubscription(cache, pair.provider, &wrongStore) != "" {
					t.Fatal("conflated Gemini's published and stored basis vocabularies")
				}
				wrongBinding.Basis = pair.stored
				if existingReaderSubscription(cache, pair.provider, &wrongBinding) != "" {
					t.Fatal("accepted Gemini's store basis as a published binding")
				}
			}
			before := readerTreeSnapshot(t, cache)
			t.Setenv("MODELPLAN_IDENTITY", "off")
			if existingReaderSubscription(cache, pair.provider, binding) != "" {
				t.Fatal("identity off exposed a managed reader subscription")
			}
			if !reflect.DeepEqual(before, readerTreeSnapshot(t, cache)) {
				t.Fatal("identity lookup wrote the reference store")
			}
		})
	}
	for provider, reader := range nativeReaders {
		if reader.Managed != nil && !covered[provider] {
			t.Errorf("managed reader %s has no allocation/binding pair regression", provider)
		}
	}
}
