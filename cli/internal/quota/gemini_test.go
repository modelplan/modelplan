package quota

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"math"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

var geminiNow = time.Date(2026, 10, 27, 12, 0, 0, 0, time.UTC)

func geminiTestPaths(t *testing.T) Paths {
	t.Helper()
	allowPOSTProtocolFixture(t, "gemini")
	isolateHome(t)
	for _, name := range []string{"MODELPLAN_READERS", "MODELPLAN_NATIVE", "MODELPLAN_IDENTITY", "GEMINI_API_KEY", "GOOGLE_API_KEY", "GOOGLE_GENAI_USE_VERTEXAI", "CODE_ASSIST_ENDPOINT", "CODE_ASSIST_API_VERSION", "GOOGLE_CLOUD_PROJECT", "GOOGLE_CLOUD_PROJECT_ID", "GEMINI_FORCE_ENCRYPTED_FILE_STORAGE"} {
		t.Setenv(name, "")
	}
	home := t.TempDir()
	t.Setenv("GEMINI_CLI_HOME", home)
	profiles := geminiProfiles()
	if err := os.MkdirAll(profiles[0].Root, 0o700); err != nil {
		t.Fatal(err)
	}
	claims, _ := json.Marshal(map[string]any{"iss": "https://accounts.google.com", "sub": "synthetic-google-subject", "exp": geminiNow.Add(48 * time.Hour).Unix()})
	id := "e30." + base64.RawURLEncoding.EncodeToString(claims) + ".synthetic-signature"
	credential, _ := json.Marshal(map[string]any{"access_token": "synthetic-google-access", "expiry_date": geminiNow.Add(48 * time.Hour).UnixMilli(), "id_token": id, "refresh_token": "synthetic-google-refresh-never-use", "client_secret": "synthetic-client-secret-never-use"})
	if err := os.WriteFile(filepath.Join(profiles[0].Root, "oauth_creds.json"), credential, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(profiles[0].Root, "settings.json"), []byte(`{"security":{"auth":{"selectedType":"oauth-personal"}}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	p := nativePaths(t)
	p.ReaderAccess = &ReaderAccess{Grants: map[string]ReaderGrant{"gemini": {SavedLogin: true, Generation: "synthetic-grant-001", Profiles: profiles}}}
	return p
}

func geminiServer(t *testing.T, mode *string, paths *[]string) {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		*paths = append(*paths, r.URL.Path)
		if r.Method != "POST" || r.Header.Get("Authorization") != "Bearer synthetic-google-access" {
			t.Error("wrong Code Assist request")
		}
		if *mode == "rejected" {
			w.WriteHeader(401)
			return
		}
		if *mode == "limited" {
			w.Header().Set("Retry-After", "7200")
			w.WriteHeader(429)
			return
		}
		if *mode == "oversized" {
			_, _ = w.Write([]byte(strings.Repeat("x", nativeMaxBody+1)))
			return
		}
		if *mode == "malformed" {
			_, _ = w.Write([]byte("{"))
			return
		}
		var body map[string]json.RawMessage
		if json.NewDecoder(r.Body).Decode(&body) != nil {
			t.Error("invalid request body")
		}
		name := ""
		switch r.URL.Path {
		case "/v1internal:loadCodeAssist":
			if string(body["mode"]) != `"HEALTH_CHECK"` {
				t.Error("metadata request is not health-check mode")
			}
			if *mode == "no-project" {
				_, _ = w.Write([]byte(`{"currentTier":{"id":"standard-tier"}}`))
				return
			}
			if *mode == "unknown-tier" {
				_, _ = w.Write([]byte(`{"currentTier":{"id":"unknown-tier"},"cloudaicompanionProject":"synthetic-project-001"}`))
				return
			}
			name = "assist.json"
		case "/v1internal:retrieveUserQuota":
			if string(body["project"]) != `"synthetic-project-001"` {
				t.Error("wrong project scope")
			}
			if *mode == "missing-quota" {
				_, _ = w.Write([]byte(`{}`))
				return
			}
			name = "quota.json"
		default:
			t.Error("extra endpoint/refresh/enumeration/inference")
			w.WriteHeader(400)
			return
		}
		b, err := os.ReadFile(filepath.Join("testdata", "gemini", name))
		if err != nil {
			t.Error(err)
			return
		}
		_, _ = w.Write(b)
	}))
	oldHost, oldClient := geminiHost, nativeClient
	nativeClient = readerFixtureClient(t, srv, "cloudcode-pa.googleapis.com")
	t.Cleanup(func() { srv.Close(); geminiHost, nativeClient = oldHost, oldClient })
}

func TestGeminiBudgetMetadataCreditsAndCache(t *testing.T) {
	p := geminiTestPaths(t)
	mode := "ok"
	paths := []string{}
	geminiServer(t, &mode, &paths)
	if err := RefreshNative(context.Background(), p, geminiNow); err != nil {
		t.Fatal(err)
	}
	if strings.Join(paths, " ") != "/v1internal:loadCodeAssist /v1internal:retrieveUserQuota" {
		t.Fatal(paths)
	}
	s, _ := loadReaderState(p.Cache, "gemini")
	a := s.Entries[0].Account
	if a == nil || len(a.Windows) != 2 || a.Windows[0].Kind != "unknown" || a.Windows[0].WindowMinutes != 0 || *a.Windows[0].UsedPercent != 25 || a.Windows[0].Requests == nil || *a.Windows[0].Requests.Remaining != 75 || a.Windows[0].Requests.Limit != nil || a.Credits == nil || *a.Credits.Balance != 120 || a.Credits.Scope != "google-one-ai" || a.Subscription == nil {
		t.Fatal("quota, credits or account scope guessed")
	}
	if err := RefreshNative(context.Background(), p, geminiNow.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if len(paths) != 2 {
		t.Fatal("five minute floor bypassed")
	}
	if err := RefreshNative(context.Background(), p, geminiNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if len(paths) != 3 || paths[2] != "/v1internal:retrieveUserQuota" {
		t.Fatal("warm metadata not reused")
	}
	s, _ = loadReaderState(p.Cache, "gemini")
	if !s.Entries[0].Account.Credits.ObservedAt.Equal(geminiNow) {
		t.Fatal("cached wallet falsely freshened")
	}
	if err := os.RemoveAll(p.ReaderAccess.Grants["gemini"].Profiles[0].Root); err != nil {
		t.Fatal(err)
	}
	r := Report{}
	applyManaged(&r, p, "gemini", geminiNow.Add(13*time.Hour))
	if len(r.Accounts) != 1 || len(r.Accounts[0].Windows) != 0 || len(paths) != 3 || r.Accounts[0].Credits == nil {
		t.Fatal("cache projection lost independent wallet or contacted source")
	}
	assertGeminiCachePrivate(t, p.Cache)
}

func TestGeminiConfiguredProjectRecoversWarmReadWithoutPersistingID(t *testing.T) {
	p := geminiTestPaths(t)
	mode := "ok"
	paths := []string{}
	geminiServer(t, &mode, &paths)
	if err := RefreshNative(context.Background(), p, geminiNow); err != nil {
		t.Fatal(err)
	}
	geminiProjects.Lock()
	geminiProjects.values = map[string]geminiProject{}
	geminiProjects.Unlock()
	t.Setenv("GOOGLE_CLOUD_PROJECT", "synthetic-project-001")
	if err := RefreshNative(context.Background(), p, geminiNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if len(paths) != 3 || paths[2] != "/v1internal:retrieveUserQuota" {
		t.Fatal("project binding not recovered")
	}
	assertGeminiCachePrivate(t, p.Cache)
}

func TestGeminiFailuresRetainCaptureAndBackoff(t *testing.T) {
	for _, failure := range []string{"rejected", "limited", "oversized", "malformed", "missing-quota"} {
		t.Run(failure, func(t *testing.T) {
			p := geminiTestPaths(t)
			mode := "ok"
			paths := []string{}
			geminiServer(t, &mode, &paths)
			if err := RefreshNative(context.Background(), p, geminiNow); err != nil {
				t.Fatal(err)
			}
			mode = failure
			if err := RefreshNative(context.Background(), p, geminiNow.Add(5*time.Minute)); err != nil {
				t.Fatal(err)
			}
			s, _ := loadReaderState(p.Cache, "gemini")
			if s.Entries[0].Status == "ok" || s.Entries[0].Account == nil || !s.Entries[0].Account.ObservedAt.Equal(geminiNow) || NativeDue(p, geminiNow.Add(14*time.Minute)) {
				t.Fatal("last good capture or backoff lost")
			}
			if failure == "limited" && !s.NextAttemptAt.Equal(geminiNow.Add(125*time.Minute)) {
				t.Fatal("Retry-After ignored")
			}
		})
	}
}

func TestGeminiUnsupportedLoginsMakeNoRequests(t *testing.T) {
	for _, mode := range []string{"no-consent", "passive", "off", "api-key", "vertex", "expired", "custom-host", "secure-store-only", "encrypted-store"} {
		t.Run(mode, func(t *testing.T) {
			p := geminiTestPaths(t)
			serverMode := "ok"
			paths := []string{}
			geminiServer(t, &serverMode, &paths)
			root := p.ReaderAccess.Grants["gemini"].Profiles[0].Root
			switch mode {
			case "no-consent":
				p.ReaderAccess = nil
			case "passive", "off":
				t.Setenv("MODELPLAN_READERS", mode)
			case "api-key":
				t.Setenv("GEMINI_API_KEY", "synthetic-api-key")
			case "vertex":
				if err := os.WriteFile(filepath.Join(root, "settings.json"), []byte(`{"security":{"auth":{"selectedType":"vertex-ai"}}}`), 0o600); err != nil {
					t.Fatal(err)
				}
			case "expired":
				if err := os.WriteFile(filepath.Join(root, "oauth_creds.json"), []byte(`{"access_token":"synthetic-google-access","expiry_date":1}`), 0o600); err != nil {
					t.Fatal(err)
				}
			case "custom-host":
				t.Setenv("CODE_ASSIST_ENDPOINT", "https://synthetic.invalid")
			case "encrypted-store":
				t.Setenv("GEMINI_FORCE_ENCRYPTED_FILE_STORAGE", "true")
			case "secure-store-only":
				if err := os.Remove(filepath.Join(root, "oauth_creds.json")); err != nil {
					t.Fatal(err)
				}
			}
			_ = RefreshNative(context.Background(), p, geminiNow)
			if len(paths) != 0 {
				t.Fatal("unsupported login made a request")
			}
		})
	}
}

func TestGeminiNoProjectEnumerationOrUnknownTierFallback(t *testing.T) {
	for _, mode := range []string{"no-project", "unknown-tier"} {
		t.Run(mode, func(t *testing.T) {
			p := geminiTestPaths(t)
			paths := []string{}
			geminiServer(t, &mode, &paths)
			if err := RefreshNative(context.Background(), p, geminiNow); err != nil {
				t.Fatal(err)
			}
			if len(paths) != 1 || paths[0] != "/v1internal:loadCodeAssist" {
				t.Fatal("discovery exceeded its slot")
			}
			s, _ := loadReaderState(p.Cache, "gemini")
			if s.Entries[0].Account != nil || s.Entries[0].Status == "ok" {
				t.Fatal("unsupported project/tier guessed quota")
			}
		})
	}
}

func TestGeminiCreditsAndFractionsStrict(t *testing.T) {
	isolateHome(t)
	for _, value := range []geminiAvailableCredit{{Type: "UNKNOWN", Amount: "1"}, {Type: "GOOGLE_ONE_AI", Amount: "-1"}, {Type: "GOOGLE_ONE_AI", Amount: "NaN"}, {Type: "GOOGLE_ONE_AI", Amount: "1.5"}} {
		if geminiCredits([]geminiAvailableCredit{value}, geminiNow) != nil {
			t.Fatal("unknown credit units guessed")
		}
	}
	for _, body := range []string{`{}`, `{"buckets":[{"modelId":"gemini-pro","remainingFraction":1.1}]}`, `{"buckets":[{"modelId":"account/secret","remainingFraction":0.5}]}`, `{"buckets":[{"modelId":"gemini-pro","remainingFraction":0.5,"resetTime":"bad"}]}`} {
		var q geminiQuota
		_ = json.Unmarshal([]byte(body), &q)
		if _, ok := parseGeminiQuota(q, geminiNow); ok {
			t.Fatal("unsupported quota guessed")
		}
	}
	var q geminiQuota
	_ = json.Unmarshal([]byte(`{"buckets":[{"modelId":"gemini-pro","remainingFraction":0.8}]}`), &q)
	ws, ok := parseGeminiQuota(q, geminiNow)
	if !ok || math.Abs(*ws[0].UsedPercent-20) > 0.000001 || ws[0].WindowMinutes != 0 {
		t.Fatal("fraction mapping or unknown duration incorrect")
	}
}

func TestGeminiDoesNotForwardCredentialOnRedirect(t *testing.T) {
	p := geminiTestPaths(t)
	forwarded := false
	target := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { forwarded = true }))
	defer target.Close()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { http.Redirect(w, r, target.URL, 302) }))
	defer srv.Close()
	oldHost, oldClient := geminiHost, nativeClient
	nativeClient = readerFixtureClient(t, srv, "cloudcode-pa.googleapis.com")
	defer func() { geminiHost, nativeClient = oldHost, oldClient }()
	if err := RefreshNative(context.Background(), p, geminiNow); err != nil {
		t.Fatal(err)
	}
	s, _ := loadReaderState(p.Cache, "gemini")
	if forwarded || s.Entries[0].Status == "ok" {
		t.Fatal("credential followed redirect")
	}
}

func assertGeminiCachePrivate(t *testing.T, cache string) {
	t.Helper()
	err := filepath.WalkDir(cache, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		b, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		for _, private := range []string{"synthetic-google-access", "synthetic-google-refresh", "synthetic-client-secret", "synthetic-google-subject", "synthetic-project-001"} {
			if strings.Contains(string(b), private) {
				t.Fatal("private value persisted")
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}
