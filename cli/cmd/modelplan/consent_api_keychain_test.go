// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestConsentAPIKeychainReadbackMatchesLegacyConnectAdmission(t *testing.T) {
	for _, command := range [][]string{{"connect", "claude"}, {"connect", "--detected"}} {
		t.Run(command[len(command)-1], func(t *testing.T) {
			home := consentAPIHome(t)
			input := "y\n"
			if command[1] == "--detected" {
				input = "\ny\n"
			}
			if code, out, stderr := consentRun(command, input); code != 0 || stderr != "" {
				t.Fatal(code, out, stderr)
			}
			s, err := consent.Load(consent.Path())
			if err != nil || s.Tools["claude"].Keychain != "" {
				t.Fatal("legacy connect fixture unexpectedly recorded an API choice", s, err)
			}
			for _, mode := range []string{"automatic", "passive", "off"} {
				t.Run(mode, func(t *testing.T) {
					t.Setenv("MODELPLAN_READERS", mode)
					before := tree(t, home)
					view := readConsentAPI(t)
					tools := apiTools(view.Tools)
					g, _ := quota.ProductionPaths(filepath.Join(home, "modelplan-cache"), version).ReaderAccessGrant("claude")
					want := "denied"
					if mode == "automatic" {
						want = "allowed"
					}
					if tools["claude"].Keychain != want || (tools["claude"].Keychain == "allowed") != g.Keychain || tools["codex"].Keychain != "unset" {
						t.Fatal("readback disagrees with production Keychain permission", view, g)
					}
					if !reflect.DeepEqual(before, tree(t, home)) {
						t.Fatal("readback or admission wrote files")
					}
				})
			}
			// Omitting a choice preserves the existing implicit permission;
			// only a newly introduced API grant defaults to unset.
			result := grantConsentAPI(t, apiRequest(t, 1, s.Generation, []string{"claude"}, nil, nil))
			if apiTools(result.Tools)["claude"].Keychain != "allowed" {
				t.Fatal("API omission downgraded existing legacy permission", result)
			}
			if err := consent.Deny(consent.Path(), "claude", "keychain"); err != nil {
				t.Fatal(err)
			}
			if view := readConsentAPI(t); apiTools(view.Tools)["claude"].Keychain != "denied" {
				t.Fatal("readback ignored source Deny", view)
			}
		})
	}
}

func TestConsentAPIRejectsKeychainChoicesForUnusedRoutesAtomically(t *testing.T) {
	for _, provider := range []string{"codex", "cursor", "gemini", "helper-claude"} {
		for _, choice := range []string{"allow", "deny"} {
			t.Run(provider+"/"+choice, func(t *testing.T) {
				home := consentAPIHome(t)
				if err := os.MkdirAll(filepath.Join(home, ".cursor"), 0700); err != nil {
					t.Fatal(err)
				}
				if err := os.MkdirAll(filepath.Join(home, ".gemini"), 0700); err != nil {
					t.Fatal(err)
				}
				id := provider
				if provider == "helper-claude" {
					cacheConsentCatalogue(t, "codexbar", "standard", "codexbar:claude")
					id = "claude"
				}
				// Establish another record and receipt to prove the failed request
				// neither changes permissions nor creates a replay receipt.
				grantConsentAPI(t, apiRequest(t, 1, 0, []string{"claude"}, nil, nil))
				before, err := os.ReadFile(consent.Path())
				if err != nil {
					t.Fatal(err)
				}
				code, out, stderr := consentRun([]string{"consent", "grant", "--json"}, apiRequest(t, 2, 1, []string{id}, nil, map[string]string{id: choice}))
				var result consentResult
				if code == 0 || stderr != "" || json.Unmarshal([]byte(out), &result) != nil || result.Error != "keychain_not_supported" {
					t.Fatal(code, out, stderr)
				}
				after, err := os.ReadFile(consent.Path())
				if err != nil || !bytes.Equal(before, after) {
					t.Fatal("unsupported Keychain choice changed consent", err)
				}
			})
		}
	}
}

func TestConsentAPIIgnoresPreviouslyRecordedUnusedKeychainChoice(t *testing.T) {
	consentAPIHome(t)
	grantConsentAPI(t, apiRequest(t, 1, 0, []string{"codex"}, nil, nil))
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		r := s.Tools["codex"]
		consent.SetKeychain(&r, "allow") // State written by the prior API revision.
		s.Tools["codex"] = r
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if view := readConsentAPI(t); apiTools(view.Tools)["codex"].Keychain != "unset" || consent.Allowed("codex", "keychain") {
		t.Fatal("unused choice was exposed as a runtime permission", view)
	}
}
