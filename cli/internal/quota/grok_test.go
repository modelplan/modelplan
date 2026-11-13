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

var grokNow = time.Date(2026, 10, 27, 12, 0, 0, 0, time.UTC)

func grokTestPaths(t *testing.T) Paths {
	t.Helper()
	isolateHome(t)
	for _, name := range []string{"MODELPLAN_READERS", "MODELPLAN_NATIVE", "MODELPLAN_IDENTITY", "GROK_AUTH_PATH", "GROK_AUTH", "GROK_AUTH_PROVIDER_COMMAND", "GROK_DEPLOYMENT_KEY", "GROK_LOCAL_AUTH", "GROK_OAUTH2_ISSUER", "GROK_OAUTH2_CLIENT_ID", "GROK_OAUTH2_PRINCIPAL_ID", "GROK_OAUTH2_PRINCIPAL_TYPE", "GROK_OIDC_ISSUER", "GROK_OIDC_CLIENT_ID", "GROK_FORCE_LOGIN_TEAM_ID", "XAI_API_KEY", "GROK_CODE_XAI_API_KEY"} {
		t.Setenv(name, "")
	}
	root := t.TempDir()
	t.Setenv("GROK_HOME", root)
	p := nativePaths(t)
	p.ReaderAccess = &ReaderAccess{Grants: map[string]ReaderGrant{"grok": {SavedLogin: true, Generation: "synthetic-grant-001", Profiles: grokProfiles()}}}
	writeGrokAuth(t, root, grokAuth{Key: "synthetic-grok-access", Mode: "oidc", User: "synthetic-grok-user", Issuer: "https://auth.x.ai", Client: grokDefaultClient, Expires: grokNow.Add(48 * time.Hour).Format(time.RFC3339)})
	return p
}

func writeGrokAuth(t *testing.T, root string, auth grokAuth) {
	t.Helper()
	v := map[string]any{"key": auth.Key, "auth_mode": auth.Mode, "user_id": auth.User, "oidc_issuer": auth.Issuer, "oidc_client_id": auth.Client, "expires_at": auth.Expires, "create_time": grokNow.Add(-time.Hour).Format(time.RFC3339), "refresh_token": "synthetic-grok-refresh-never-use", "email": "synthetic-private@example.invalid", "principal_id": auth.Principal, "team_id": auth.Team}
	b, _ := json.Marshal(map[string]any{"https://auth.x.ai::" + grokDefaultClient: v, "xai::api_key": map[string]string{"key": "synthetic-api-key-never-use", "auth_mode": "api_key"}})
	if err := os.WriteFile(filepath.Join(root, "auth.json"), b, 0o644); err != nil {
		t.Fatal(err)
	}
}

func grokTestServer(t *testing.T, mode *string, hits *int) {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		*hits++
		if r.Method != "GET" || r.URL.Path != "/v1/billing" || r.URL.RawQuery != "format=credits" || r.Header.Get("Authorization") != "Bearer synthetic-grok-access" || r.Header.Get("X-XAI-Token-Auth") != "xai-grok-cli" || r.Header.Get("x-userid") != "synthetic-grok-user" || r.Header.Get("x-grok-client-mode") != "headless" || !strings.Contains(r.Header.Get("x-grok-client-version"), "modelplan") {
			t.Error("incorrect billing request")
		}
		switch *mode {
		case "rejected":
			w.WriteHeader(401)
			return
		case "limited":
			w.Header().Set("Retry-After", "7200")
			w.WriteHeader(429)
			return
		case "oversized":
			_, _ = w.Write([]byte(strings.Repeat("x", nativeMaxBody+1)))
			return
		case "malformed":
			_, _ = w.Write([]byte("{"))
			return
		case "empty":
			_, _ = w.Write([]byte(`{"config":{}}`))
			return
		}
		b, err := os.ReadFile(filepath.Join("testdata", "grok-quota", "unified.json"))
		if err != nil {
			t.Error(err)
			return
		}
		_, _ = w.Write(b)
	}))
	oldHost, oldClient := grokHost, nativeClient
	nativeClient = readerFixtureClient(t, srv, "cli-chat-proxy.grok.com")
	t.Cleanup(func() { srv.Close(); grokHost, nativeClient = oldHost, oldClient })
}

func TestGrokSingleReadIncludedWalletAndReadOnlyCredential(t *testing.T) {
	p := grokTestPaths(t)
	mode := "ok"
	hits := 0
	grokTestServer(t, &mode, &hits)
	path := p.ReaderAccess.Grants["grok"].Profiles[0].AccountFile
	before, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	infoBefore, _ := os.Stat(path)
	if err := RefreshNative(context.Background(), p, grokNow); err != nil {
		t.Fatal(err)
	}
	s, _ := loadReaderState(p.Cache, "grok")
	a := s.Entries[0].Account
	if hits != 1 || a == nil || len(a.Windows) != 2 || a.Windows[0].Kind != "weekly" || *a.Windows[0].UsedPercent != 37.5 || a.Credits == nil || *a.Credits.Balance != 12.34 || a.Credits.Currency != "USD" || a.SharedPool == nil || a.SharedPool.Status != "unverified" || a.SharedPool.Additive || a.Subscription == nil {
		t.Fatal("billing reading or shared-pool link incorrect")
	}
	if *a.Windows[1].UsedUSD != 2 || *a.Windows[1].LimitUSD != 10 || a.Windows[1].ResetsAt != nil {
		t.Fatal("weekly reset copied onto independent spend cap")
	}
	after, _ := os.ReadFile(path)
	infoAfter, _ := os.Stat(path)
	if string(before) != string(after) || infoBefore.Mode() != infoAfter.Mode() {
		t.Fatal("credential modified or permissions repaired")
	}
	if err := RefreshNative(context.Background(), p, grokNow.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if hits != 1 {
		t.Fatal("five minute floor bypassed")
	}
	if err := RefreshNative(context.Background(), p, grokNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if hits != 2 {
		t.Fatal("extra billing request")
	}
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	r := Report{}
	applyManaged(&r, p, "grok", grokNow.Add(7*24*time.Hour))
	if len(r.Accounts) != 1 || len(r.Accounts[0].Windows) != 1 || r.Accounts[0].Credits == nil || hits != 2 {
		t.Fatal("reset pruning or cache-only wallet failed")
	}
	assertGrokPrivate(t, p.Cache)
}

func TestGrokFailuresKeepLastCaptureAndBackoff(t *testing.T) {
	for _, failure := range []string{"rejected", "limited", "oversized", "malformed", "empty"} {
		t.Run(failure, func(t *testing.T) {
			p := grokTestPaths(t)
			mode := "ok"
			hits := 0
			grokTestServer(t, &mode, &hits)
			if err := RefreshNative(context.Background(), p, grokNow); err != nil {
				t.Fatal(err)
			}
			mode = failure
			if err := RefreshNative(context.Background(), p, grokNow.Add(5*time.Minute)); err != nil {
				t.Fatal(err)
			}
			s, _ := loadReaderState(p.Cache, "grok")
			if hits != 2 || s.Entries[0].Account == nil || !s.Entries[0].Account.ObservedAt.Equal(grokNow) || s.Entries[0].Status == "ok" || NativeDue(p, grokNow.Add(14*time.Minute)) {
				t.Fatal("failure erased or freshened last capture")
			}
			if failure == "limited" && !s.NextAttemptAt.Equal(grokNow.Add(125*time.Minute)) {
				t.Fatal("Retry-After ignored")
			}
		})
	}
}

func TestGrokUnsupportedAuthUsesNoRequests(t *testing.T) {
	for _, mode := range []string{"no-consent", "off", "passive", "api-preferred", "model-key", "external-helper", "foreign-issuer", "expired", "unknown-expiry", "inline-auth"} {
		t.Run(mode, func(t *testing.T) {
			p := grokTestPaths(t)
			root := p.ReaderAccess.Grants["grok"].Profiles[0].Root
			serverMode := "ok"
			hits := 0
			grokTestServer(t, &serverMode, &hits)
			config := ""
			switch mode {
			case "no-consent":
				p.ReaderAccess = nil
			case "off", "passive":
				t.Setenv("MODELPLAN_READERS", mode)
			case "api-preferred":
				config = "[auth]\npreferred_method = 'api_key'\n"
			case "model-key":
				config = "[model.'synthetic-model']\napi_key = 'synthetic-model-key-never-use'\n"
			case "external-helper":
				config = "[grok_com_config]\nauth_provider_command = 'never-execute-this'\n"
			case "foreign-issuer":
				t.Setenv("GROK_OIDC_ISSUER", "https://synthetic.invalid")
				t.Setenv("GROK_OIDC_CLIENT_ID", "synthetic-client")
			case "expired", "unknown-expiry":
				expiry := ""
				if mode == "expired" {
					expiry = grokNow.Add(-time.Minute).Format(time.RFC3339)
				}
				writeGrokAuth(t, root, grokAuth{Key: "synthetic-grok-access", Mode: "oidc", User: "synthetic-grok-user", Issuer: "https://auth.x.ai", Client: grokDefaultClient, Expires: expiry})
			case "inline-auth":
				t.Setenv("GROK_AUTH", "synthetic-inline-auth")
			}
			if config != "" {
				if err := os.WriteFile(filepath.Join(root, "config.toml"), []byte(config), 0o600); err != nil {
					t.Fatal(err)
				}
			}
			_ = RefreshNative(context.Background(), p, grokNow)
			if hits != 0 {
				t.Fatal("unsupported auth/config made request")
			}
		})
	}
}

func TestGrokLegacyCentsAndMissingUnifiedEvidence(t *testing.T) {
	isolateHome(t)
	b, err := os.ReadFile(filepath.Join("testdata", "grok-quota", "legacy.json"))
	if err != nil {
		t.Fatal(err)
	}
	var response grokBilling
	_ = json.Unmarshal(b, &response)
	a, ok := parseGrokBilling(response, grokNow)
	if !ok || a.SharedPool != nil || len(a.Windows) != 1 || a.Windows[0].Kind != "monthly" || *a.Windows[0].UsedPercent != 25 || *a.Windows[0].UsedUSD != 5 {
		t.Fatal("legacy credits relabelled or units guessed")
	}
	for _, body := range []string{`{"config":{"prepaidBalance":{}}}`, `{"config":{"prepaidBalance":{"val":0}}}`} {
		response = grokBilling{}
		_ = json.Unmarshal([]byte(body), &response)
		a, ok = parseGrokBilling(response, grokNow)
		if !ok || a.Credits == nil || *a.Credits.Balance != 0 || a.SharedPool != nil {
			t.Fatal("explicit proto zero or absent unified flag misread")
		}
	}
	for _, body := range []string{`{}`, `{"config":{}}`, `{"config":{"creditUsagePercent":-1}}`, `{"config":{"prepaidBalance":{"val":-1}}}`, `{"config":{"isUnifiedBillingUser":true,"monthlyLimit":{"val":100},"used":{"val":20}}}`} {
		var bad grokBilling
		_ = json.Unmarshal([]byte(body), &bad)
		if _, ok := parseGrokBilling(bad, grokNow); ok {
			t.Fatal("unknown billing guessed")
		}
	}
}

func TestGrokJWTExpiryAndSharedBudget(t *testing.T) {
	p := grokTestPaths(t)
	mode := "ok"
	hits := 0
	grokTestServer(t, &mode, &hits)
	if err := reserveXSubscription(p.Cache, "cursor", grokNow); err != nil {
		t.Fatal(err)
	}
	if err := RefreshNative(context.Background(), p, grokNow.Add(4*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if hits != 0 {
		t.Fatal("Cursor/Grok shared floor bypassed")
	}
	claims, _ := json.Marshal(map[string]any{"exp": grokNow.Add(-time.Minute).Unix(), "iss": "https://auth.x.ai"})
	key := "e30." + base64.RawURLEncoding.EncodeToString(claims) + ".synthetic-signature"
	if grokExpiry(grokAuth{Key: key, Expires: grokNow.Add(time.Hour).Format(time.RFC3339)}, grokNow) {
		t.Fatal("later file expiry overrode expired JWT")
	}
}

func assertGrokPrivate(t *testing.T, cache string) {
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
		for _, private := range []string{"synthetic-grok-access", "synthetic-grok-refresh", "synthetic-grok-user", "synthetic-private@example.invalid", "synthetic-api-key-never-use"} {
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
