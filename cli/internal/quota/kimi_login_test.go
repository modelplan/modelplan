package quota

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func kimiLoginTestPaths(t *testing.T) (Paths, string) {
	t.Helper()
	isolateHome(t)
	for _, name := range []string{"MODELPLAN_READERS", "MODELPLAN_NATIVE", "MODELPLAN_IDENTITY", "KIMI_CODE_API_KEY", "KIMI_CODE_BASE_URL", "KIMI_CODE_OAUTH_HOST", "KIMI_OAUTH_HOST", "KIMI_AUTH_TOKEN", "kimi_auth_token"} {
		t.Setenv(name, "")
	}
	root := t.TempDir()
	t.Setenv("KIMI_CODE_HOME", root)
	if err := os.MkdirAll(filepath.Join(root, "credentials"), 0o700); err != nil {
		t.Fatal(err)
	}
	claims, _ := json.Marshal(map[string]any{"sub": "synthetic-kimi-account", "exp": kimiNow.Add(48 * time.Hour).Unix(), "email": "synthetic-private@example.invalid"})
	token := "e30." + base64.RawURLEncoding.EncodeToString(claims) + ".synthetic-signature"
	credential, _ := json.Marshal(map[string]any{"access_token": token, "refresh_token": "synthetic-kimi-refresh-never-use", "expires_at": kimiNow.Add(48 * time.Hour).Unix()})
	if err := os.WriteFile(filepath.Join(root, "credentials", "kimi-code.json"), credential, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "device_id"), []byte("synthetic-device-001\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	p := nativePaths(t)
	p.ReaderAccess = &ReaderAccess{Grants: map[string]ReaderGrant{"kimi": {SavedLogin: true, Generation: "synthetic-grant-001", Region: "china", Profiles: kimiLoginProfiles()}}}
	return p, token
}

func kimiLoginServer(t *testing.T, token string, mode *string, hits *int) {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		*hits++
		if r.Method != "GET" || r.URL.Path != "/coding/v1/usages" || r.Header.Get("Authorization") != "Bearer "+token || r.Header.Get("Cookie") != "" || r.Header.Get("X-Msh-Platform") != "kimi_code_cli" || r.Header.Get("X-Msh-Device-Id") != "synthetic-device-001" || !strings.Contains(r.Header.Get("X-Msh-Device-Name"), "ModelPlan") {
			t.Error("incorrect saved-login request")
		}
		switch *mode {
		case "limited":
			w.Header().Set("Retry-After", "7200")
			w.WriteHeader(429)
			return
		case "rejected":
			w.WriteHeader(401)
			return
		case "empty":
			_, _ = w.Write([]byte(`{}`))
			return
		case "oversized":
			_, _ = w.Write([]byte(strings.Repeat("x", nativeMaxBody+1)))
			return
		}
		_, _ = w.Write(kimiFixture(t, "ratios"))
	}))
	oldHost, oldClient := kimiLoginHost, nativeClient
	kimiLoginHost, nativeClient = srv.URL, srv.Client()
	t.Cleanup(func() { srv.Close(); kimiLoginHost, nativeClient = oldHost, oldClient })
}

func TestKimiLoginChinaBudgetCacheAndPrivacy(t *testing.T) {
	p, token := kimiLoginTestPaths(t)
	mode := "ok"
	hits := 0
	kimiLoginServer(t, token, &mode, &hits)
	root := p.ReaderAccess.Grants["kimi"].Profiles[0].Root
	credentialPath := filepath.Join(root, "credentials", "kimi-code.json")
	before, _ := os.ReadFile(credentialPath)
	deviceBefore, _ := os.ReadFile(filepath.Join(root, "device_id"))
	if err := RefreshNative(context.Background(), p, kimiNow); err != nil {
		t.Fatal(err)
	}
	s, _ := loadReaderState(p.Cache, "kimi")
	a := s.Entries[0].Account
	if hits != 1 || a == nil || len(a.Windows) != 3 || a.Plan != "Kimi Code (China)" || a.Subscription == nil || *a.Windows[0].UsedPercent != 12.5 || *a.Windows[1].UsedPercent != 41 {
		t.Fatal("invalid saved-login quota")
	}
	if err := RefreshNative(context.Background(), p, kimiNow.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if hits != 1 {
		t.Fatal("five minute floor bypassed")
	}
	if err := RefreshNative(context.Background(), p, kimiNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if hits != 2 {
		t.Fatal("extra usage call")
	}
	after, _ := os.ReadFile(credentialPath)
	deviceAfter, _ := os.ReadFile(filepath.Join(root, "device_id"))
	if string(before) != string(after) || string(deviceBefore) != string(deviceAfter) {
		t.Fatal("tool files modified")
	}
	if err := os.RemoveAll(root); err != nil {
		t.Fatal(err)
	}
	r := Report{}
	applyManaged(&r, p, "kimi", kimiNow.Add(6*time.Hour))
	if len(r.Accounts) != 1 || hits != 2 {
		t.Fatal("cache projection touched credentials")
	}
	assertKimiLoginPrivate(t, p.Cache, token)
}

func TestKimiLoginUnsupportedModesMakeNoRequests(t *testing.T) {
	for _, mode := range []string{"no-consent", "passive", "off", "international", "missing-device", "expired", "endpoint-override", "oauth-override", "api-key"} {
		t.Run(mode, func(t *testing.T) {
			p, token := kimiLoginTestPaths(t)
			serverMode := "ok"
			hits := 0
			kimiLoginServer(t, token, &serverMode, &hits)
			g := p.ReaderAccess.Grants["kimi"]
			root := g.Profiles[0].Root
			switch mode {
			case "no-consent":
				p.ReaderAccess = nil
			case "passive", "off":
				t.Setenv("MODELPLAN_READERS", mode)
			case "international":
				g.Region = "international"
				p.ReaderAccess.Grants["kimi"] = g
			case "missing-device":
				if err := os.Remove(filepath.Join(root, "device_id")); err != nil {
					t.Fatal(err)
				}
			case "expired":
				if err := os.WriteFile(filepath.Join(root, "credentials", "kimi-code.json"), []byte(`{"access_token":"synthetic-expired","expires_at":1}`), 0o600); err != nil {
					t.Fatal(err)
				}
			case "endpoint-override":
				t.Setenv("KIMI_CODE_BASE_URL", "https://api.kimi.ai")
			case "oauth-override":
				t.Setenv("KIMI_CODE_OAUTH_HOST", "https://synthetic.invalid")
			case "api-key":
				t.Setenv("KIMI_CODE_API_KEY", "synthetic-api-key")
			}
			_ = RefreshNative(context.Background(), p, kimiNow)
			if hits != 0 {
				t.Fatal("unsupported login called a provider")
			}
			if mode == "missing-device" {
				if _, err := os.Stat(filepath.Join(root, "device_id")); !os.IsNotExist(err) {
					t.Fatal("device ID created")
				}
			}
		})
	}
}

func TestKimiLoginFailuresRetainCaptureAndBackoff(t *testing.T) {
	for _, failure := range []string{"limited", "rejected", "empty", "oversized"} {
		t.Run(failure, func(t *testing.T) {
			p, token := kimiLoginTestPaths(t)
			mode := "ok"
			hits := 0
			kimiLoginServer(t, token, &mode, &hits)
			if err := RefreshNative(context.Background(), p, kimiNow); err != nil {
				t.Fatal(err)
			}
			mode = failure
			if err := RefreshNative(context.Background(), p, kimiNow.Add(5*time.Minute)); err != nil {
				t.Fatal(err)
			}
			s, _ := loadReaderState(p.Cache, "kimi")
			if hits != 2 || s.Entries[0].Status == "ok" || s.Entries[0].Account == nil || !s.Entries[0].Account.ObservedAt.Equal(kimiNow) || NativeDue(p, kimiNow.Add(14*time.Minute)) {
				t.Fatal("capture or backoff lost")
			}
			if failure == "limited" && !s.NextAttemptAt.Equal(kimiNow.Add(125*time.Minute)) {
				t.Fatal("Retry-After ignored")
			}
		})
	}
}

func TestKimiLegacyAndSavedLoginShareAttemptGate(t *testing.T) {
	p, _ := kimiLoginTestPaths(t)
	if err := kimiReserve(p.Cache, kimiNow); err != nil {
		t.Fatal(err)
	}
	if NativeDue(p, kimiNow.Add(4*time.Minute)) || !NativeDue(p, kimiNow.Add(5*time.Minute)) {
		t.Fatal("saved login bypassed shared gate")
	}
	if err := kimiFinish(p.Cache, kimiNow.Add(30*time.Minute)); err != nil {
		t.Fatal(err)
	}
	p.ReaderAccess = nil
	t.Setenv("KIMI_CODE_API_KEY", "synthetic-explicit-key")
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "kimi", Backend: BackendNative, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	if NativeDue(p, kimiNow.Add(29*time.Minute)) || !NativeDue(p, kimiNow.Add(30*time.Minute)) {
		t.Fatal("legacy key bypassed provider backoff")
	}
}

func TestKimiOtherDurationRetainsLabel(t *testing.T) {
	isolateHome(t)
	e := parseKimi([]byte(`{"limits":[{"window":{"duration":1,"timeUnit":"TIME_UNIT_HOUR"},"detail":{"used":2,"limit":10}}]}`), kimiNow)
	if e.Status != "ok" || len(e.Windows) != 1 || e.Windows[0].Kind != "unknown" || e.Windows[0].Limit != "60 minute quota" || *e.Windows[0].UsedPercent != 20 {
		t.Fatal("other quota duration discarded or guessed")
	}
}

func TestKimiLoginRefusesCredentialRedirect(t *testing.T) {
	p, _ := kimiLoginTestPaths(t)
	forwarded := false
	target := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { forwarded = true }))
	defer target.Close()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { http.Redirect(w, r, target.URL, 302) }))
	defer srv.Close()
	oldHost, oldClient := kimiLoginHost, nativeClient
	kimiLoginHost, nativeClient = srv.URL, srv.Client()
	defer func() { kimiLoginHost, nativeClient = oldHost, oldClient }()
	if err := RefreshNative(context.Background(), p, kimiNow); err != nil {
		t.Fatal(err)
	}
	s, _ := loadReaderState(p.Cache, "kimi")
	if forwarded || s.Entries[0].Status == "ok" {
		t.Fatal("credential followed redirect")
	}
}

func assertKimiLoginPrivate(t *testing.T, cache, token string) {
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
		for _, private := range []string{token, "synthetic-kimi-refresh", "synthetic-kimi-account", "synthetic-private@example.invalid", "synthetic-device-001"} {
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
