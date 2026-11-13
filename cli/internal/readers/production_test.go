// SPDX-License-Identifier: MIT
package readers_test

import (
	"context"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/readers/readertest"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

func postProductionPaths(t *testing.T, provider string, now time.Time, allowed bool) quota.Paths {
	t.Helper()
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	for _, env := range []string{"MODELPLAN_READERS", "MODELPLAN_NATIVE", "MODELPLAN_IDENTITY", "GEMINI_CLI_HOME", "GEMINI_API_KEY", "GOOGLE_API_KEY", "GOOGLE_GENAI_USE_VERTEXAI", "CODE_ASSIST_ENDPOINT", "CODE_ASSIST_API_VERSION", "GOOGLE_CLOUD_PROJECT", "GOOGLE_CLOUD_PROJECT_ID", "GEMINI_FORCE_ENCRYPTED_FILE_STORAGE", "MODELPLAN_HISTORY", "MODELPLAN_GEMINI", "MODELPLAN_GEMINI_HOME"} {
		t.Setenv(env, "")
	}
	if provider == "gemini" {
		root := filepath.Join(home, ".gemini")
		if err := os.MkdirAll(root, 0700); err != nil {
			t.Fatal(err)
		}
		credential, _ := json.Marshal(map[string]any{"access_token": "synthetic-google-access", "expiry_date": now.Add(48 * time.Hour).UnixMilli()})
		if err := os.WriteFile(filepath.Join(root, "oauth_creds.json"), credential, 0600); err != nil {
			t.Fatal(err)
		}
		if err := localusage.SetGemini(home, true); err != nil {
			t.Fatal(err)
		}
	} else {
		path := quota.CursorReadPath(home)
		if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
			t.Fatal(err)
		}
		db, err := sql.Open("sqlite", path)
		if err != nil {
			t.Fatal(err)
		}
		defer db.Close()
		if _, err := db.Exec(`CREATE TABLE ItemTable (key TEXT PRIMARY KEY, value)`); err != nil {
			t.Fatal(err)
		}
		claims, _ := json.Marshal(map[string]any{"sub": "auth|synthetic-cursor-account", "exp": now.Add(48 * time.Hour).Unix()})
		token := "e30." + base64.RawURLEncoding.EncodeToString(claims) + ".synthetic-signature"
		if _, err := db.Exec(`INSERT INTO ItemTable VALUES ('cursorAuth/accessToken', ?)`, token); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if allowed {
		setPOSTConsent(t, provider, true)
	}
	return quota.ProductionPaths(t.TempDir(), "1.0.0")
}

func setPOSTConsent(t *testing.T, provider string, allowed bool) {
	t.Helper()
	state, err := consent.Load(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	scope := consent.ScopeGeminiAccountUsageSavedLogin
	if provider == "cursor" {
		scope = consent.ScopeCursorAccountUsageSavedLogin
	}
	grant := consent.Grant{RequestID: fmt.Sprintf("post-%s-%t-%d", provider, allowed, state.Generation), ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation, ConsentTextVersion: consent.TextVersion}
	if allowed {
		grant.Allow = []string{scope}
	} else {
		grant.Deny = []string{scope}
	}
	_, err = consent.ApplyGrant(consent.Path(), grant, consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) {
		return consent.Record{ReaderID: "native:" + provider, Backend: quota.BackendNative}, nil
	}})
	if err != nil {
		t.Fatal(err)
	}
}

// The real production constructor requires an explicit saved-login scope grant.
// Approved cold reads use two pinned requests; warm reads use only usage. A new
// constructor/diagnostic call cannot bypass the persisted shared budget.
func TestProductionApprovedPOSTConsentColdWarmAndSharedBudget(t *testing.T) {
	now := time.Date(2026, 10, 27, 12, 0, 0, 0, time.UTC)
	for _, read := range approvedPOSTReads() {
		t.Run(read.name, func(t *testing.T) {
			paths := postProductionPaths(t, read.name, now, false)
			files := []string{"assist.json", "quota.json"}
			if read.name == "cursor" {
				files = []string{"merged-plan.json", "period-usage.json"}
			}
			responses := []readertest.Response{}
			for _, file := range append(files, files[1]) {
				body, err := os.ReadFile(filepath.Join("..", "quota", "testdata", read.name, file))
				if err != nil {
					t.Fatal(err)
				}
				responses = append(responses, readertest.Response{StatusCode: 200, Body: string(body)})
			}
			record := readertest.NewTransport(responses...)
			previous := http.DefaultTransport
			http.DefaultTransport = record
			t.Cleanup(func() { http.DefaultTransport = previous })
			if quota.ReaderAdmitted(paths, read.name) {
				t.Fatal("O-class scope admitted by presence alone")
			}
			_ = quota.RefreshNative(context.Background(), paths, now)
			if len(record.Requests()) != 0 {
				t.Fatal("request before per-scope consent")
			}
			setPOSTConsent(t, read.name, true)
			paths = quota.ProductionPaths(paths.Cache, "1.0.0")
			if !quota.ReaderAdmitted(paths, read.name) || !quota.NativeDue(paths, now) {
				t.Fatal("approved scope not scheduled after opt-in")
			}
			if err := quota.RefreshNative(context.Background(), paths, now); err != nil {
				t.Fatal(err)
			}
			want := []readertest.Request{}
			for _, p := range read.requests {
				r := p.request(t)
				want = append(want, readertest.Request{Method: r.Method, Host: r.URL.Host, Path: r.URL.EscapedPath()})
				r.Body.Close()
			}
			if err := checkRequests(record.Requests(), want); err != nil {
				t.Fatal(err)
			}
			if len(quota.ReadPermitted(paths, now).Accounts) == 0 {
				t.Fatal("approved production read produced no account")
			}
			again := quota.ProductionPaths(paths.Cache, "1.0.0")
			_ = quota.RefreshNative(context.Background(), again, now.Add(time.Minute))
			_ = quota.RefreshReaderDiagnostics(context.Background(), again, now.Add(2*time.Minute))
			if err := checkRequests(record.Requests(), want); err != nil {
				t.Fatal("shared budget bypassed", err)
			}
			if err := quota.RefreshNative(context.Background(), again, now.Add(10*time.Minute)); err != nil {
				t.Fatal(err)
			}
			want = append(want, want[1])
			if err := checkRequests(record.Requests(), want); err != nil {
				t.Fatal("warm read did not retain its request set", err)
			}
			setPOSTConsent(t, read.name, false)
			revoked := quota.ProductionPaths(paths.Cache, "1.0.0")
			_ = quota.RefreshNative(context.Background(), revoked, now.Add(time.Hour))
			if quota.ReaderAdmitted(revoked, read.name) || len(quota.ReadPermitted(revoked, now.Add(time.Hour)).Accounts) != 0 {
				t.Fatal("revoked account remained admitted")
			}
			if err := checkRequests(record.Requests(), want); err != nil {
				t.Fatal("request after revoke", err)
			}
		})
	}
}

func TestProductionUnconsentedPOSTSuppressesRetainedRemoteCapture(t *testing.T) {
	now := time.Date(2026, 10, 29, 12, 0, 0, 0, time.UTC)
	for _, provider := range []string{"gemini", "cursor"} {
		t.Run(provider, func(t *testing.T) {
			paths := postProductionPaths(t, provider, now, false)
			file := filepath.Join(paths.Cache, "observed", "readers", provider+".json")
			capture := map[string]any{"schemaVersion": 1, "provider": provider, "entries": []any{map[string]any{"profileKey": "synthetic-profile", "status": "ok", "account": map[string]any{"source": provider, "observedAt": now, "windows": []any{map[string]any{"kind": "weekly", "usedPercent": 25, "observedAt": now}}}}}}
			data, err := json.Marshal(capture)
			if err != nil {
				t.Fatal(err)
			}
			if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(file, data, 0600); err != nil {
				t.Fatal(err)
			}
			for _, p := range []quota.Paths{paths, {Cache: paths.Cache, ConnectionsFile: paths.ConnectionsFile, CodexBarFile: paths.CodexBarFile}} {
				if report := quota.Read(p, now); len(report.Accounts) != 0 {
					t.Errorf("disabled remote capture exposed: %+v", report.Accounts)
				}
			}
		})
	}
}
