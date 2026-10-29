// SPDX-License-Identifier: MIT
package readers_test

import (
	"context"
	"database/sql"
	"encoding/base64"
	"encoding/json"
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

func postProductionPaths(t *testing.T, provider string, now time.Time) quota.Paths {
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
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		return consent.Set(s, provider, true, "native:"+provider, quota.BackendNative, now)
	}); err != nil {
		t.Fatal(err)
	}
	return quota.ProductionPaths(t.TempDir(), "1.0.0")
}

// Red line: real production paths, including retained consent, cannot send the
// unapproved POSTs. Valid synthetic logins make missing/expired credentials an
// invalid explanation for zero calls. No test policy override is used here.
func TestProductionPOSTGateOverridesSavedLoginConsent(t *testing.T) {
	now := time.Date(2026, 10, 29, 12, 0, 0, 0, time.UTC)
	for _, provider := range []string{"gemini", "cursor"} {
		t.Run(provider, func(t *testing.T) {
			paths := postProductionPaths(t, provider, now)
			record := readertest.NewTransport(readertest.Response{StatusCode: 200, Body: `{}`}, readertest.Response{StatusCode: 200, Body: `{}`})
			old := http.DefaultTransport
			http.DefaultTransport = record
			defer func() { http.DefaultTransport = old }()
			if quota.ReaderAdmitted(paths, provider) || quota.NativeDue(paths, now) {
				t.Error("unapproved scope admitted or scheduled")
			}
			_ = quota.RefreshNative(context.Background(), paths, now)
			_ = quota.RefreshReaderDiagnostics(context.Background(), paths, now.Add(time.Hour))
			if err := checkRequests(record.Requests(), nil); err != nil {
				t.Error(err)
			}
			found := false
			for _, row := range quota.ReaderDiagnostics(paths, now) {
				if row.Provider == provider {
					found = true
					if row.Admitted != "no" || row.State != "unavailable:policy_pending" || row.Windows != 0 {
						t.Errorf("missing policy gate diagnostic: %+v", row)
					}
				}
			}
			if !found {
				t.Error("missing provider diagnostic")
			}
		})
	}
}

func TestProductionPOSTGateSuppressesRetainedRemoteCapture(t *testing.T) {
	now := time.Date(2026, 10, 29, 12, 0, 0, 0, time.UTC)
	for _, provider := range []string{"gemini", "cursor"} {
		t.Run(provider, func(t *testing.T) {
			paths := postProductionPaths(t, provider, now)
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
