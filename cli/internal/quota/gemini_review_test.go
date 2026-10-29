package quota

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func clearGeminiTransientProjects() {
	geminiProjects.Lock()
	geminiProjects.values = map[string]geminiProject{}
	geminiProjects.Unlock()
}

func TestGeminiProjectSwitchNeverSplicesOldScope(t *testing.T) {
	for _, restart := range []bool{false, true} {
		for _, selector := range []string{"GOOGLE_CLOUD_PROJECT", "GOOGLE_CLOUD_PROJECT_ID"} {
			for _, mode := range []string{"success", "no-credits", "discovery-fails", "quota-fails", "unknown-tier", "wrong-project", "malformed-quota"} {
				name := selector + "/" + mode
				if restart {
					name = "restart/" + name
				} else {
					name = "warm/" + name
				}
				t.Run(name, func(t *testing.T) {
					p := geminiTestPaths(t)
					const a = "synthetic-project-A"
					const b = "synthetic-project-B"
					t.Setenv(selector, a)
					requests := []string{}
					srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
						var body map[string]string
						// loadCodeAssist also contains a metadata object, so decode just the
						// project field independently rather than treating that object as text.
						var raw map[string]json.RawMessage
						if json.NewDecoder(r.Body).Decode(&raw) != nil {
							t.Error("bad request")
						}
						body = map[string]string{}
						for _, key := range []string{"cloudaicompanionProject", "project"} {
							var value string
							_ = json.Unmarshal(raw[key], &value)
							body[key] = value
						}
						project := body["project"]
						if strings.HasSuffix(r.URL.Path, "loadCodeAssist") {
							project = body["cloudaicompanionProject"]
						}
						requests = append(requests, r.URL.Path+":"+project)
						if r.Header.Get("Authorization") != "Bearer synthetic-google-access" || (project != a && project != b) {
							t.Error("wrong binding")
						}
						switch r.URL.Path {
						case "/v1internal:loadCodeAssist":
							if project == b && mode == "discovery-fails" {
								w.WriteHeader(503)
								return
							}
							id, tier, balance := project, "free-tier", "120"
							if project == b {
								tier, balance = "standard-tier", "20"
							}
							if project == b && mode == "wrong-project" {
								id = a
							}
							if project == b && mode == "unknown-tier" {
								tier = "new-unknown-tier"
							}
							current := map[string]any{"id": tier}
							if project != b || mode != "no-credits" {
								current["availableCredits"] = []map[string]string{{"creditType": "GOOGLE_ONE_AI", "creditAmount": balance}}
							}
							_ = json.NewEncoder(w).Encode(map[string]any{"cloudaicompanionProject": id, "currentTier": current})
						case "/v1internal:retrieveUserQuota":
							if project == b && mode == "quota-fails" {
								w.WriteHeader(503)
								return
							}
							if project == b && mode == "malformed-quota" {
								_, _ = w.Write([]byte(`{}`))
								return
							}
							fraction := 0.75
							if project == b {
								fraction = 0.2
							}
							_ = json.NewEncoder(w).Encode(map[string]any{"buckets": []map[string]any{{"modelId": "gemini-pro", "remainingFraction": fraction}}})
						default:
							t.Error("extra endpoint")
							w.WriteHeader(400)
						}
					}))
					oldHost, oldClient := geminiHost, nativeClient
					nativeClient = readerFixtureClient(t, srv, "cloudcode-pa.googleapis.com")
					defer func() { srv.Close(); geminiHost, nativeClient = oldHost, oldClient }()
					if err := RefreshNative(context.Background(), p, geminiNow); err != nil {
						t.Fatal(err)
					}
					previous, _ := loadReaderState(p.Cache, "gemini")
					oldRef := previous.Entries[0].Account.Subscription.Ref
					if restart {
						clearGeminiTransientProjects()
					}
					t.Setenv(selector, b)
					if err := RefreshNative(context.Background(), p, geminiNow.Add(time.Minute)); err != nil {
						t.Fatal(err)
					}
					if len(requests) != 2 {
						t.Fatal("scope change bypassed floor")
					}
					if err := RefreshNative(context.Background(), p, geminiNow.Add(5*time.Minute)); err != nil {
						t.Fatal(err)
					}
					expected := 4
					if mode == "discovery-fails" || mode == "unknown-tier" || mode == "wrong-project" {
						expected = 3
					}
					if len(requests) != expected || requests[2] != "/v1internal:loadCodeAssist:"+b {
						t.Fatal("scope not revalidated within two-call budget", requests)
					}
					if expected == 4 && requests[3] != "/v1internal:retrieveUserQuota:"+b {
						t.Fatal("old project quota requested")
					}
					state, _ := loadReaderState(p.Cache, "gemini")
					entry := state.Entries[0]
					if mode == "success" || mode == "no-credits" {
						account := entry.Account
						if account == nil || account.Plan != "Gemini Code Assist Standard" || len(account.Windows) != 1 || *account.Windows[0].UsedPercent != 80 || account.Subscription == nil || account.Subscription.Ref == oldRef {
							t.Fatal("B usage mixed with A scope or plan")
						}
						if mode == "no-credits" && account.Credits != nil {
							t.Fatal("A wallet spliced onto B")
						}
						if mode == "success" && (account.Credits == nil || *account.Credits.Balance != 20) {
							t.Fatal("B wallet lost or spliced")
						}
					} else if entry.Account != nil || entry.Metadata.ScopeKey != "" {
						t.Fatal("failed B read inherited A account/metadata")
					}
				})
			}
		}
	}
}

func TestGeminiChangedInvalidBindingCannotInheritAccount(t *testing.T) {
	for _, mode := range []string{"expired-B", "malformed-B", "unsupported-B", "encrypted-B", "missing-B", "invalid-token-B", "expired-same-token-project-B"} {
		t.Run(mode, func(t *testing.T) {
			p := geminiTestPaths(t)
			serverMode := "ok"
			paths := []string{}
			geminiServer(t, &serverMode, &paths)
			if err := RefreshNative(context.Background(), p, geminiNow); err != nil {
				t.Fatal(err)
			}
			path := filepath.Join(p.ReaderAccess.Grants["gemini"].Profiles[0].Root, "oauth_creds.json")
			var err error
			switch mode {
			case "expired-same-token-project-B":
				t.Setenv("GOOGLE_CLOUD_PROJECT", "synthetic-project-B")
				err = os.WriteFile(path, []byte(`{"access_token":"synthetic-google-access","expiry_date":1}`), 0600)
			case "expired-B":
				err = os.WriteFile(path, []byte(`{"access_token":"synthetic-account-B","expiry_date":1}`), 0600)
			case "malformed-B":
				err = os.WriteFile(path, []byte(`{"access_token":"synthetic-account-B"`), 0600)
			case "unsupported-B":
				t.Setenv("GEMINI_API_KEY", "synthetic-api-B")
			case "encrypted-B":
				t.Setenv("GEMINI_FORCE_ENCRYPTED_FILE_STORAGE", "true")
			case "missing-B":
				err = os.Remove(path)
			case "invalid-token-B":
				err = os.WriteFile(path, []byte(`{"access_token":"bad\r\nB","expiry_date":9999999999999}`), 0600)
			}
			if err != nil {
				t.Fatal(err)
			}
			if err := RefreshNative(context.Background(), p, geminiNow.Add(5*time.Minute)); err != nil {
				t.Fatal(err)
			}
			s, _ := loadReaderState(p.Cache, "gemini")
			if len(paths) != 2 || s.Entries[0].Account != nil || s.Entries[0].Metadata.CredentialKey != "" {
				t.Fatal("invalid B inherited A or made request")
			}
			r := Report{}
			applyManaged(&r, p, "gemini", geminiNow.Add(6*time.Minute))
			if len(r.Accounts) != 0 {
				t.Fatal("A numbers still projected")
			}
		})
	}
}

func TestGeminiSameExpiredGenerationRetainsOriginalCapture(t *testing.T) {
	p := geminiTestPaths(t)
	mode := "ok"
	paths := []string{}
	geminiServer(t, &mode, &paths)
	if err := RefreshNative(context.Background(), p, geminiNow); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(p.ReaderAccess.Grants["gemini"].Profiles[0].Root, "oauth_creds.json")
	if err := os.WriteFile(path, []byte(`{"access_token":"synthetic-google-access","expiry_date":1}`), 0600); err != nil {
		t.Fatal(err)
	}
	if err := RefreshNative(context.Background(), p, geminiNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	s, _ := loadReaderState(p.Cache, "gemini")
	if len(paths) != 2 || s.Entries[0].Status != "expired" || s.Entries[0].Account == nil || !s.Entries[0].Account.ObservedAt.Equal(geminiNow) || NativeDue(p, geminiNow.Add(6*time.Minute)) {
		t.Fatal("same-generation failure lost capture age or floor")
	}
}

func TestGeminiForgetReconnectRestartKeepsActualDispatchFloor(t *testing.T) {
	p := geminiTestPaths(t)
	mode := "ok"
	paths := []string{}
	geminiServer(t, &mode, &paths)
	if err := RefreshNative(context.Background(), p, geminiNow); err != nil {
		t.Fatal(err)
	}
	if err := ForgetReader(p.Cache, "gemini"); err != nil {
		t.Fatal(err)
	}
	clearGeminiTransientProjects()
	g := p.ReaderAccess.Grants["gemini"]
	g.Generation = "reconnected-grant-B"
	p = Paths{Cache: p.Cache, ConnectionsFile: p.ConnectionsFile, ReaderAccess: &ReaderAccess{Grants: map[string]ReaderGrant{"gemini": g}}}
	for _, seconds := range []int{60, 299} {
		at := geminiNow.Add(time.Duration(seconds) * time.Second)
		if NativeDue(p, at) {
			t.Fatal("Forget/restart reset dispatch floor")
		}
		if err := RefreshNative(context.Background(), p, at); err != nil {
			t.Fatal(err)
		}
	}
	if len(paths) != 2 {
		t.Fatal("dispatched within 300 seconds after Forget")
	}
	if err := RefreshNative(context.Background(), p, geminiNow.Add(300*time.Second)); err != nil {
		t.Fatal(err)
	}
	if len(paths) != 4 {
		t.Fatal("not released at 300 seconds")
	}
	assertGeminiCachePrivate(t, p.Cache)
}
