// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	legacy "github.com/modelplan/modelplan/cli/internal/consent/testdata/schema-v1"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

func legacyRevokeCodex(t *testing.T) {
	t.Helper()
	// Invoke the actual frozen pre-API Change/Load/Set implementation, not this
	// version's serializer. It knows neither Record.Keychain nor State.Requests.
	before, err := os.ReadFile(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	if err := legacy.Change(legacy.Path(), func(s *legacy.State) error {
		return legacy.Set(s, "codex", false, "", "", time.Now())
	}); err == nil {
		t.Fatal("schema-1 writer accepted schema 2")
	}
	after, _ := os.ReadFile(consent.Path())
	if !bytes.Equal(before, after) {
		t.Fatal("old writer changed schema-2 store")
	}
}

func TestConsentAPIKeychainRestrictionsSurviveSchemaOneReadersAndWriters(t *testing.T) {
	for _, choice := range []string{"deny", ""} {
		t.Run("choice="+choice, func(t *testing.T) {
			home := consentAPIHome(t)
			var choices map[string]string
			want := "unset"
			if choice != "" {
				choices, want = map[string]string{"claude": choice}, "denied"
			}
			grantConsentAPI(t, apiRequest(t, 1, 0, []string{"claude"}, nil, choices))
			assertRestriction := func() {
				old, err := legacy.Load(legacy.Path())
				if err == nil || old.Allows("claude", "keychain", legacy.Automatic) || old.Allows("claude", legacy.Credential, legacy.Automatic) {
					t.Fatal("pre-API reader ignored Keychain restriction or lost saved-login grant", old, err)
				}
				if consent.Allowed("claude", "keychain") {
					t.Fatal("new reader lost Keychain restriction")
				}
				view := readConsentAPI(t)
				if apiTools(view.Tools)["claude"].Keychain != want {
					t.Fatal("readback lost recorded choice", view)
				}
				g, ok := quota.ProductionPaths(filepath.Join(home, "modelplan-cache"), version).ReaderAccessGrant("claude")
				if !ok || g.Keychain || !g.SavedLogin {
					t.Fatal("production admission ignored Keychain restriction", g, ok)
				}
			}
			assertRestriction()
			legacyRevokeCodex(t)
			b, err := os.ReadFile(consent.Path())
			if err != nil || !bytes.Contains(b, []byte(`"schemaVersion": 2`)) {
				t.Fatal("fixture did not drop the new Keychain field", string(b), err)
			}
			assertRestriction()
		})
	}
}

func TestConsentAPISuccessReceiptSurvivesRejectedSchemaOneWriter(t *testing.T) {
	home := consentAPIHome(t)
	input := apiRequest(t, 1, 0, []string{"claude"}, nil, nil)
	result := grantConsentAPI(t, input)
	legacyRevokeCodex(t)
	s, err := consent.Load(consent.Path())
	if err != nil || s.Generation != 1 || len(s.Requests) != 1 || s.Tools["codex"].Allowed {
		t.Fatal("legacy write lost receipt or failed to apply its own decision", s, err)
	}
	before := tree(t, home)
	if replay := grantConsentAPI(t, input); !reflect.DeepEqual(replay, result) || !reflect.DeepEqual(before, tree(t, home)) {
		t.Fatal("replay after pre-API write did not return original receipt without writing", replay, result)
	}
}

func TestConsentAPIPendingForgetReceiptSurvivesRejectedSchemaOneWriter(t *testing.T) {
	home := consentAPIHome(t)
	grantConsentAPI(t, apiRequest(t, 1, 0, []string{"claude"}, nil, nil))
	observed := filepath.Join(home, "modelplan-cache", "observed")
	if err := os.MkdirAll(observed, 0700); err != nil {
		t.Fatal(err)
	}
	lock := filepath.Join(observed, "native.lock")
	if err := os.WriteFile(lock, nil, 0600); err != nil {
		t.Fatal(err)
	}
	input := apiRequest(t, 2, 1, nil, []string{"claude"}, nil)
	code, result, stderr := consentRun([]string{"consent", "grant", "--json"}, input)
	var response consentResult
	if code == 0 || stderr != "" || json.Unmarshal([]byte(result), &response) != nil || response.Error != "cleanup_pending" {
		t.Fatal(code, result, stderr)
	}
	legacyRevokeCodex(t)
	s, err := consent.Load(consent.Path())
	if err != nil || s.Generation != 2 || s.Tools["claude"].Allowed || len(s.Requests[consent.ReceiptKey(s.StoreEpoch, response.RequestID)].PendingForget) != 1 {
		t.Fatal("pre-API writer lost revocation/Forget obligation", s, err)
	}
	if err := os.Remove(lock); err != nil {
		t.Fatal(err)
	}
	// A replay must not retry cleanup even though the old lock is now gone.
	capture := filepath.Join(observed, "claude-code.json")
	if err := os.WriteFile(capture, []byte("SYNTHETIC REPLAY MUST NOT DELETE"), 0600); err != nil {
		t.Fatal(err)
	}
	before := tree(t, home)
	replayCode, replay, replayStderr := consentRun([]string{"consent", "grant", "--json"}, input)
	if replayCode != code || replay != result || replayStderr != "" || !reflect.DeepEqual(before, tree(t, home)) {
		t.Fatal("replay after pre-API write reapplied consent or cleanup", replayCode, replay, replayStderr)
	}
}

func TestConsentAPIUnsetCanBeExplicitlyAllowedAfterRejectedSchemaOneWrite(t *testing.T) {
	consentAPIHome(t)
	grantConsentAPI(t, apiRequest(t, 1, 0, []string{"claude"}, nil, nil))
	legacyRevokeCodex(t)
	result := grantConsentAPI(t, apiRequest(t, 2, 1, []string{"claude"}, nil, map[string]string{"claude": "allow"}))
	if apiTools(result.Tools)["claude"].Keychain != "allowed" || !consent.Allowed("claude", "keychain") {
		t.Fatal("explicit permission could not resolve unset", result)
	}
	legacyRevokeCodex(t)
	if view := readConsentAPI(t); apiTools(view.Tools)["claude"].Keychain != "allowed" {
		t.Fatal("pre-API write lost explicit allowed readback", view)
	}
	if err := consent.Deny(consent.Path(), "claude", "keychain"); err != nil {
		t.Fatal(err)
	}
	result = grantConsentAPI(t, apiRequest(t, 3, 3, []string{"claude"}, nil, map[string]string{"claude": "allow"}))
	if apiTools(result.Tools)["claude"].Keychain != "denied" || consent.Allowed("claude", "keychain") {
		t.Fatal("API cleared a pre-API source Deny", result)
	}
}
