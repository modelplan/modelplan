// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func TestQuotaJSONSanitizesGeminiScopeThroughCache(t *testing.T) {
	home := nativeRefreshHome(t)
	t.Setenv("GEMINI_CLI_HOME", home)
	root := filepath.Join(home, ".gemini")
	if err := os.MkdirAll(root, 0700); err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	claims, _ := json.Marshal(map[string]any{"iss": "https://accounts.google.com", "sub": "synthetic-subject", "exp": now.Add(24 * time.Hour).Unix()})
	creds, _ := json.Marshal(map[string]any{"access_token": "synthetic-access", "expiry_date": now.Add(24 * time.Hour).UnixMilli(), "id_token": "e30." + base64.RawURLEncoding.EncodeToString(claims) + ".synthetic"})
	if err := os.WriteFile(filepath.Join(root, "oauth_creds.json"), creds, 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "settings.json"), []byte(`{"security":{"auth":{"selectedType":"oauth-personal"}}}`), 0600); err != nil {
		t.Fatal(err)
	}
	grantConsentAPI(t, apiRequest(t, 1, 0, []string{"gemini"}, nil, nil))
	oldTransport := http.DefaultTransport
	calls := 0
	http.DefaultTransport = nativeRefreshTransport(func(r *http.Request) (*http.Response, error) {
		if r.URL.Host != "cloudcode-pa.googleapis.com" || r.Method != "POST" {
			t.Fatalf("unexpected synthetic request: %s %s", r.Method, r.URL.Host)
		}
		calls++
		body := `{"currentTier":{"id":"standard-tier"},"cloudaicompanionProject":"synthetic-project"}`
		if strings.HasSuffix(r.URL.Path, ":retrieveUserQuota") {
			body = `{"buckets":[{"modelId":"synthetic-token-shaped-secret","remainingFraction":0.5},{"modelId":"gemini-2.5-pro","remainingFraction":0.8}]}`
		} else if !strings.HasSuffix(r.URL.Path, ":loadCodeAssist") {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		return &http.Response{StatusCode: 200, Header: make(http.Header), Body: io.NopCloser(strings.NewReader(body))}, nil
	})
	t.Cleanup(func() { http.DefaultTransport = oldTransport })
	st, err := store.Locate()
	if err != nil {
		t.Fatal(err)
	}
	if err := quota.RefreshNativeProviders(context.Background(), quotaPaths(st), now, []string{"gemini"}); err != nil {
		t.Fatal(err)
	}
	if calls != 2 {
		t.Fatalf("synthetic provider was not read: %d", calls)
	}
	check := func(preScope bool) {
		t.Helper()
		code, out, stderr := consentRun([]string{"quota", "--json", "--offline"}, "")
		if code != 0 {
			t.Fatalf("quota exit %d: %s", code, stderr)
		}
		if strings.Contains(out, "synthetic-token-shaped-secret") {
			t.Fatal("unreviewed synthetic provider text appeared in quota JSON")
		}
		var report quota.Report
		if err := json.Unmarshal([]byte(out), &report); err != nil {
			t.Fatal(err)
		}
		found := 0
		for _, a := range report.Accounts {
			if a.Source != "native:gemini" {
				continue
			}
			for _, w := range a.Windows {
				if len(w.ModelIDs) != 1 {
					t.Fatalf("scope missing: %+v", w)
				}
				switch w.ModelIDs[0] {
				case "unknown", "gemini-2.5-pro":
					found++
				default:
					t.Fatalf("unreviewed modelIds: %q", w.ModelIDs[0])
				}
			}
		}
		if found != 2 {
			t.Fatalf("missing synthetic windows: %d, %s", found, out)
		}
		input := consent.Capture().RowsInput(now)
		input.Catalogue = append(input.Catalogue, rows.CatalogueEntry{ToolID: "gemini", Detected: true, ReaderExists: true})
		quota.AppendManagedRows(&input, quotaPaths(st))
		projection := rows.Build(input)
		if err := rows.Validate(input, projection); err != nil {
			t.Fatal(err)
		}
		scopes := map[string]bool{}
		for _, row := range projection.Rows {
			if row.ID == "gemini" {
				for _, account := range row.Accounts {
					for _, window := range account.Windows {
						if window.ModelScope != nil && len(window.ModelScope.Models) == 1 {
							scopes[window.ModelScope.Models[0]] = true
						}
					}
				}
			}
		}
		if (!preScope && !scopes["unknown"]) || !scopes["gemini-2.5-pro"] {
			t.Fatalf("rows lost safe scoped windows: %+v", scopes)
		}
	}
	check(false)
	// Simulate an existing older cache that stored the raw identifier. The quota
	// JSON boundary must still sanitize it when that cache is read.
	path := filepath.Join(st.Dir, "observed", "readers", "gemini.json")
	cached, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	prior := `"modelIds":["unknown"]`
	replacement := `"modelIds":["synthetic-token-shaped-secret"]`
	if !strings.Contains(string(cached), prior) {
		t.Fatalf("expected cached scope missing: %s", fmt.Sprint(len(cached)))
	}
	legacy := strings.Replace(string(cached), prior, replacement, 1)
	legacy = strings.Replace(legacy, `"limit":"unknown"`, `"limit":"synthetic-token-shaped-secret"`, 1)
	if !strings.Contains(legacy, `"limit":"synthetic-token-shaped-secret"`) {
		t.Fatal("legacy limit injection failed")
	}
	if err = os.WriteFile(path, []byte(legacy), 0600); err != nil {
		t.Fatal(err)
	}
	check(false)
	// A pre-scope cache lacks both the marker and modelIds entirely.
	legacy = strings.Replace(legacy, replacement+",", "", 1)
	legacy = strings.Replace(legacy, `"scopeKnown":true,`, "", 1)
	if err = os.WriteFile(path, []byte(legacy), 0600); err != nil {
		t.Fatal(err)
	}
	check(true)
}
