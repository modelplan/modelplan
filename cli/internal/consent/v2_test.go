// SPDX-License-Identifier: MIT
package consent

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestSchemaTwoBoundary(t *testing.T) {
	file := filepath.Join(t.TempDir(), "consent.json")
	raw := `{"schemaVersion":1,"generation":7,"privacy":"passive","tools":{"gemini":{"allowed":true,"consentTextVersion":2,"at":"2026-01-01T00:00:00Z","readerId":"native:gemini","backend":"native","deniedSources":{"local":true}}}}`
	if err := os.WriteFile(file, []byte(raw), 0600); err != nil {
		t.Fatal(err)
	}
	s, err := Load(file)
	if err != nil {
		t.Fatal(err)
	}
	if s.SchemaVersion != 2 {
		t.Fatalf("schema = %d, want 2", s.SchemaVersion)
	}
	backup, err := os.ReadFile(filepath.Join(filepath.Dir(file), "consent.v1.bak"))
	if err != nil || string(backup) != raw {
		t.Fatalf("schema-1 backup: %s, %v", backup, err)
	}
	if s.Generation != 7 || s.Privacy != Passive {
		t.Fatalf("migration lost state: %+v", s)
	}
}

func TestEpochResetFencesLateReadAndOldAllow(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	before, err := EnsureStore(Path())
	if err != nil {
		t.Fatal(err)
	}
	allow := Grant{RequestID: "old-allow", ExpectStoreEpoch: before.StoreEpoch, ExpectGeneration: 0, ConsentTextVersion: TextVersion, Allow: []string{ScopeClaudeAccountUsageSavedLogin}}
	hooks := GrantHooks{Admit: func(d ScopeDefinition) (Record, error) {
		return Record{ReaderID: "native:claude", Backend: "native"}, nil
	}}
	if _, err := ApplyGrant(Path(), allow, hooks); err != nil {
		t.Fatal(err)
	}
	admitted, _ := Load(Path())
	// Commit an allow whose expected generation will equal the reset floor, then
	// retry that exact request (including its ID and payload) after reset.
	allow.RequestID = "retry-old-allow"
	allow.ExpectGeneration = admitted.Generation
	if _, err := ApplyGrant(Path(), allow, hooks); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(Path(), []byte("damaged"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := Load(Path()); err == nil {
		t.Fatal("damaged store accepted")
	}
	if err := Change(Path(), func(*State) error { t.Fatal("corrupt store mutated"); return nil }); err == nil {
		t.Fatal("damaged store overwritten")
	}
	reset, err := Reset(Path())
	if err != nil {
		t.Fatal(err)
	}
	if reset.AllowsScope(ScopeCodexRuntimeUsage, Automatic) || reset.AllowsScope(ScopeClaudeLocalHistory, Automatic) {
		t.Fatal("reset inherited implicit permission")
	}
	if reset.Generation != admitted.Generation || reset.StoreEpoch == admitted.StoreEpoch {
		t.Fatalf("reset fence: %+v %+v", admitted.Fence(), reset.Fence())
	}
	restarted, err := Load(Path())
	if err != nil || restarted.Fence() != reset.Fence() {
		t.Fatal("restart changed epoch", err)
	}
	late := false
	if err := Publish(admitted.Fence(), func() error { late = true; return nil }); err == nil || late {
		t.Fatal("old read published across reset")
	}
	if _, err := ApplyGrant(Path(), allow, hooks); err == nil || err.Error() != "consent_stale" {
		t.Fatal("old-epoch allow accepted", err)
	}
	if err := Publish(reset.Fence(), func() error { return nil }); err != nil {
		t.Fatal("new epoch rejected", err)
	}
}

func TestScopedRevokeRacesReadAndKeepsLocalPermission(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	s, err := EnsureStore(Path())
	if err != nil {
		t.Fatal(err)
	}
	hooks := GrantHooks{Admit: func(d ScopeDefinition) (Record, error) {
		return Record{ReaderID: "native:claude", Backend: "native"}, nil
	}, Cleanup: func(string, bool) error { return nil }}
	request := Grant{RequestID: "allow", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: 0, ConsentTextVersion: TextVersion, Allow: []string{ScopeClaudeLocalHistory, ScopeClaudeAccountUsageSavedLogin}}
	if _, err := ApplyGrant(Path(), request, hooks); err != nil {
		t.Fatal(err)
	}
	admitted, _ := Load(Path())
	started, complete := make(chan struct{}), make(chan struct{})
	read := make(chan error, 1)
	go func() {
		close(started)
		<-complete
		read <- Publish(admitted.Fence(), func() error { t.Error("revoked value published"); return nil })
	}()
	<-started
	request.RequestID = "deny"
	request.ExpectGeneration = 1
	request.Allow = nil
	request.Deny = []string{ScopeClaudeAccountUsageSavedLogin}
	if _, err := ApplyGrant(Path(), request, hooks); err != nil {
		t.Fatal(err)
	}
	close(complete)
	if err := <-read; err == nil {
		t.Fatal("late read accepted")
	}
	current, _ := Load(Path())
	if current.AllowsScope(ScopeClaudeAccountUsageSavedLogin, Automatic) || !current.AllowsScope(ScopeClaudeLocalHistory, Automatic) {
		t.Fatal("scope isolation lost")
	}
}

func TestScopedTwoWritersAndDurableReplay(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	s, err := EnsureStore(Path())
	if err != nil {
		t.Fatal(err)
	}
	requests := []Grant{
		{RequestID: "writer-a", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: 0, Deny: []string{ScopeClaudeAccountUsageSavedLogin}},
		{RequestID: "writer-b", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: 0, Deny: []string{"retired.old_path"}},
	}
	start := make(chan struct{})
	results := make(chan int, 2)
	for i := range requests {
		go func(i int) {
			<-start
			_, err := ApplyGrant(Path(), requests[i], GrantHooks{})
			if err != nil {
				results <- -1
				return
			}
			results <- i
		}(i)
	}
	close(start)
	a, b := <-results, <-results
	winner := a
	if winner < 0 {
		winner = b
	}
	if winner < 0 || a >= 0 && b >= 0 {
		t.Fatalf("writers: %d %d", a, b)
	}
	before, _ := os.ReadFile(Path())
	replay, err := ApplyGrant(Path(), requests[winner], GrantHooks{})
	if err != nil || !replay.Committed || replay.Code != "cleanup_pending" {
		t.Fatal("receipt lost", replay, err)
	}
	after, _ := os.ReadFile(Path())
	if string(before) != string(after) {
		t.Fatal("replay wrote store")
	}
	changed := requests[winner]
	changed.Deny = []string{"other.retired_path"}
	if _, err := ApplyGrant(Path(), changed, GrantHooks{}); err == nil || err.Error() != "request_mismatch" {
		t.Fatal("payload mismatch accepted", err)
	}
}

func TestTightenWhileOffAndRetiredScopes(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "off")
	s, err := EnsureStore(Path())
	if err != nil {
		t.Fatal(err)
	}
	req := Grant{RequestID: "retired", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: 0, Deny: []string{"retired.old_path"}, Forget: []string{ScopeGeminiAccountUsageSavedLogin}}
	cleaned := map[string]bool{}
	result, err := ApplyGrant(Path(), req, GrantHooks{Cleanup: func(id string, forget bool) error { cleaned[id] = forget; return nil }})
	if err != nil || !result.Committed || result.Code != "ok" || !cleaned[ScopeGeminiAccountUsageSavedLogin] {
		t.Fatal(result, cleaned, err)
	}
	current, _ := Load(Path())
	if current.Scopes["retired.old_path"].Allowed || current.Scopes[ScopeGeminiAccountUsageSavedLogin].Allowed {
		t.Fatal("tightening lost")
	}
}

func TestMigrationPreservesCoveredScopesDenialsAndReceipts(t *testing.T) {
	file := filepath.Join(t.TempDir(), "consent.json")
	receipt := Receipt{RequestHash: strings.Repeat("a", 64), Result: json.RawMessage(`{"ok":false,"error":"cleanup_pending"}`), PendingForget: []string{"gemini"}}
	encoded, _ := json.Marshal(receipt)
	raw, _ := json.Marshal(map[string]any{"schemaVersion": 1, "generation": 9, "privacy": Passive,
		"tools": map[string]Record{
			"claude": {Allowed: true, ConsentTextVersion: TextVersion, ReaderID: "native:claude", Backend: "native", DeniedSources: map[string]bool{"keychain": true}},
			"gemini": {Allowed: false, ConsentTextVersion: TextVersion, ReaderID: "native:gemini", Backend: "native"},
			"kimi":   {Allowed: true, ConsentTextVersion: TextVersion, ReaderID: "native:kimi", Backend: "native", KeyEnv: "KIMI_CODE_API_KEY"},
			"cursor": {Allowed: true, ConsentTextVersion: TextVersion, ReaderID: "codexbar:cursor", Backend: "codexbar"}},
		"hinted": map[string]bool{"claude": true, receiptPrefix + "legacy-request/" + base64.RawURLEncoding.EncodeToString(encoded): true}})
	if err := os.WriteFile(file, raw, 0600); err != nil {
		t.Fatal(err)
	}
	s, err := Load(file)
	if err != nil {
		t.Fatal(err)
	}
	if !validEpoch(s.StoreEpoch) || s.Generation != 9 || s.Privacy != Passive || !s.Hinted["claude"] {
		t.Fatal("migration lost metadata", s)
	}
	if !s.AllowsScope(ScopeClaudeAccountUsageSavedLogin, Automatic) || s.Allows("claude", "keychain", Automatic) || s.AllowsScope(ScopeGeminiLocalHistory, Automatic) || !s.AllowsScope(ScopeKimiAccountUsageAPIKey, Automatic) || s.AllowsScope(ScopeKimiAccountUsageSavedLogin, Automatic) || s.AllowsScope(ScopeCursorAccountUsageSavedLogin, Automatic) || s.AllowsScope(ScopeCursorLocalHistory, Automatic) {
		t.Fatal("migration broadened or lost scopes", s.Scopes)
	}
	migrated := s.Requests[ReceiptKey(s.StoreEpoch, "legacy-request")]
	if !reflect.DeepEqual(migrated, receipt) {
		t.Fatal("migration changed immutable receipt", migrated)
	}
	backup, err := os.ReadFile(filepath.Join(filepath.Dir(file), "consent.v1.bak"))
	if err != nil || !bytes.Equal(backup, raw) {
		t.Fatal("original backup lost", err)
	}
	before, _ := os.ReadFile(file)
	reloaded, err := Load(file)
	after, _ := os.ReadFile(file)
	if err != nil || !bytes.Equal(before, after) || reloaded.Fence() != s.Fence() {
		t.Fatal("second load remigrated store", err)
	}
}

func TestCleanupRetryPreservesGenerationAndOriginalReceipt(t *testing.T) {
	file := filepath.Join(t.TempDir(), "consent.json")
	s, err := EnsureStore(file)
	if err != nil {
		t.Fatal(err)
	}
	request := Grant{RequestID: "forget", ExpectStoreEpoch: s.StoreEpoch, Forget: []string{"retired.old_path"}}
	result, err := ApplyGrant(file, request, GrantHooks{})
	if err != nil || result.Code != "cleanup_pending" {
		t.Fatal(result, err)
	}
	replay, err := ApplyGrant(file, request, GrantHooks{Cleanup: func(string, bool) error { t.Fatal("replay retried cleanup"); return nil }})
	if err != nil || !replay.Replayed {
		t.Fatal("replay not marked", replay, err)
	}
	if err := RetryCleanup(file, func(scope string, forget bool) error {
		if scope != "retired.old_path" || !forget {
			t.Fatal("Forget semantics lost", scope, forget)
		}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	current, err := Load(file)
	if err != nil || current.Generation != 1 || current.Scopes["retired.old_path"].Allowed || len(current.Requests[ReceiptKey(s.StoreEpoch, "forget")].PendingForget) != 0 {
		t.Fatal("cleanup retry lost denial or changed generation", current, err)
	}
	replay, err = ApplyGrant(file, request, GrantHooks{})
	replay.Replayed = false
	if err != nil || !reflect.DeepEqual(replay, result) {
		t.Fatal("cleanup retry rewrote original response", replay, result, err)
	}
}
