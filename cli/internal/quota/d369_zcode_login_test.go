// SPDX-License-Identifier: MIT
package quota

import (
	"bytes"
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"os/user"
	"path/filepath"
	"runtime"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// D369 (owner, 2026-11-21): ZCode users signed in by QR code (OAuth) get their GLM quota, through
// Token Monitor's route (Javis603/token-monitor@9de6288, zcodeDiscovery.js and limits.js).
// Synthetic fixtures only: the store is encrypted here with a test secret and every credential is
// a canary that must never reach a file, a report or a diagnostic.

const (
	zcodeTestSecret     = "test-credential-secret"
	zcodeAccountCanary  = "zcode-account-key-canary-d369"
	zcodeIdentityCanary = "user-identity-canary-d369"
	zcodeMidCanary      = "device-mid-canary-d369"
)

func zcodeTestEncrypt(t *testing.T, plain, secret string) string {
	t.Helper()
	key := sha256.Sum256([]byte(secret))
	block, err := aes.NewCipher(key[:])
	if err != nil {
		t.Fatal(err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		t.Fatal(err)
	}
	iv := make([]byte, 12)
	if _, err := rand.Read(iv); err != nil {
		t.Fatal(err)
	}
	sealed := gcm.Seal(nil, iv, []byte(plain), nil)
	body, tag := sealed[:len(sealed)-16], sealed[len(sealed)-16:]
	enc := base64.RawURLEncoding.EncodeToString
	return "enc:v1:" + enc(iv) + "." + enc(tag) + "." + enc(body)
}

// zcodeTestJWT: a fake, unsigned JWT with the given expiry and a canary claim.
func zcodeTestJWT(exp time.Time) string {
	enc := base64.RawURLEncoding.EncodeToString
	payload, _ := json.Marshal(map[string]any{"exp": exp.Unix(), "sub": "jwt-canary-d369"})
	return enc([]byte(`{"alg":"none","typ":"JWT"}`)) + "." + enc(payload) + ".c2lnLWNhbmFyeQ"
}

type zcodeFixture struct {
	family, kind, baseURL, jwt string
	accountKey                 bool
	deviceMid                  bool
}

// writeZCodeLogin writes ZCode Desktop's sign-in layout (3.12.3+): no provider_config.json, no
// plaintext key, the credential store encrypted with the test secret.
func writeZCodeLogin(t *testing.T, home string, f zcodeFixture) string {
	t.Helper()
	t.Setenv("ZCODE_CREDENTIAL_SECRET", zcodeTestSecret)
	dir := filepath.Join(home, ".zcode", "v2")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	slot := "coding-plan"
	if f.kind == "start-plan" {
		slot = "start-plan"
	}
	provider := "builtin:" + f.family + "-" + slot
	settings, _ := json.Marshal(map[string]any{"providerFamilyDomain": f.family,
		"providerFamilyConnectionSelections": map[string]any{f.family: map[string]any{"kind": f.kind}}})
	options := map[string]any{"apiKey": ""}
	if f.baseURL != "" {
		options["baseURL"] = f.baseURL
	}
	config, _ := json.Marshal(map[string]any{"provider": map[string]any{provider: map[string]any{"enabled": true, "options": options}}})
	profile, _ := json.Marshal(map[string]any{"user_id": zcodeIdentityCanary})
	if f.family != "zai" {
		profile, _ = json.Marshal(map[string]any{"id": zcodeIdentityCanary, "username": "u", "displayName": "U"})
	}
	store := map[string]any{"oauth:" + f.family + ":user_info": zcodeTestEncrypt(t, string(profile), zcodeTestSecret)}
	if f.jwt != "" {
		store["zcodejwttoken"] = zcodeTestEncrypt(t, f.jwt, zcodeTestSecret)
	}
	if f.accountKey {
		name := "account-provider:coding-plan:account:" + f.family + "-" + f.kind + ":account:" + zcodeIdentityCanary + ":api-key"
		store[name] = zcodeTestEncrypt(t, zcodeAccountCanary, zcodeTestSecret)
	}
	credentials, _ := json.Marshal(store)
	files := map[string][]byte{"setting.json": settings, "config.json": config, "credentials.json": credentials}
	if f.deviceMid {
		files["telemetry-state.json"] = []byte(`{"deviceMid":"` + zcodeMidCanary + `"}`)
	}
	for name, body := range files {
		if err := os.WriteFile(filepath.Join(dir, name), body, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

// zcodeSnapshot: every file in ZCode's folder with its bytes and modification time.
func zcodeSnapshot(t *testing.T, dir string) map[string]string {
	t.Helper()
	out := map[string]string{}
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	for _, e := range entries {
		b, _ := os.ReadFile(filepath.Join(dir, e.Name()))
		fi, _ := os.Stat(filepath.Join(dir, e.Name()))
		sum := sha256.Sum256(b)
		out[e.Name()] = base64.StdEncoding.EncodeToString(sum[:]) + "@" + fi.ModTime().String() + "/" + fi.Mode().String()
	}
	return out
}

func grantZCodeLogin(t *testing.T) {
	t.Helper()
	s, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	hooks := consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) {
		return consent.Record{ReaderID: "native:zai", Backend: "native"}, nil
	}}
	request := consent.Grant{RequestID: "d369", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeZaiAccountUsageSavedLogin}}
	if _, err := consent.ApplyGrant(consent.Path(), request, hooks); err != nil {
		t.Fatal(err)
	}
}

type zcodeServer struct {
	calls  atomic.Int32
	server *httptest.Server
	seen   chan *http.Request
}

func newZCodeServer(t *testing.T, body string, status int, hosts ...string) *zcodeServer {
	t.Helper()
	z := &zcodeServer{seen: make(chan *http.Request, 8)}
	z.server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		z.calls.Add(1)
		z.seen <- r.Clone(context.Background())
		w.WriteHeader(status)
		_, _ = w.Write([]byte(body))
	}))
	t.Cleanup(z.server.Close)
	old := nativeClient
	t.Cleanup(func() { nativeClient = old })
	nativeClient = readerFixtureClient(t, z.server, hosts...)
	return z
}

// assertNoZCodeSecret: no credential, identity or device id, raw or decrypted, in any ModelPlan
// file, the report or the diagnostics.
func assertNoZCodeSecret(t *testing.T, cache string, extra ...any) {
	t.Helper()
	canaries := []string{zcodeAccountCanary, zcodeIdentityCanary, zcodeMidCanary, "jwt-canary", "c2lnLWNhbmFyeQ", "enc:v1:"}
	check := func(where string, b []byte) {
		for _, c := range canaries {
			if bytes.Contains(b, []byte(c)) {
				t.Fatalf("%s contains %q", where, c)
			}
		}
	}
	for _, root := range []string{cache, filepath.Dir(consent.Path())} {
		_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
			if err == nil && info.Mode().IsRegular() {
				b, _ := os.ReadFile(path)
				check(path, b)
			}
			return nil
		})
	}
	for i, v := range extra {
		b, _ := json.Marshal(v)
		check("output #"+string(rune('0'+i)), b)
	}
}

func zcodeReport(t *testing.T, cache string, now time.Time) (Report, SourceStatus, []ReaderDiagnostic) {
	t.Helper()
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	r := ReadPermitted(p, now)
	s, _ := zaiSource(r)
	return r, s, ReaderDiagnostics(p, now)
}

func zcodeAccount(r Report) *Account {
	for i := range r.Accounts {
		if r.Accounts[i].Source == "native:zai" {
			return &r.Accounts[i]
		}
	}
	return nil
}

// The reset is two hours after the tests' fixed clock (2026-11-21 12:00 UTC).
var zcodeQuotaBody = `{"success":true,"code":200,"data":{"limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":40,"nextResetTime":` + jsonInt(time.Date(2026, 11, 21, 14, 0, 0, 0, time.UTC).UnixMilli()) + `}]}}`

// Consent off (the default): the sign-in is detected and the row asks for consent; ZCode's
// folder is not opened and nothing is sent.
func TestD369ConsentOffReadsNothing(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	dir := writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai", "open.bigmodel.cn", "zcode.z.ai")
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if g, ok := p.ReaderAccessGrant("zai"); ok {
		t.Fatalf("ZCode sign-in admitted without consent: %+v", g.ConfigSource)
	}
	if !p.ZCodeLoginConsent || p.ZCodeNoProviderFile {
		t.Fatalf("consent-needed state not set: login=%t noProvider=%t", p.ZCodeLoginConsent, p.ZCodeNoProviderFile)
	}
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now); err == nil {
		t.Fatal("a refresh of the saved-login scope ran without consent")
	}
	_ = RefreshNativeProviders(context.Background(), p, now, []string{"zai"})
	r, s, diags := zcodeReport(t, cache, now)
	if s.ErrorCode != "consent_required" {
		t.Fatalf("source %+v, want consent_required", s)
	}
	if a := zcodeAccount(r); a != nil {
		t.Fatalf("data shown before consent: %+v", a)
	}
	for _, d := range diags {
		if d.Provider == "zai" && d.State != "unavailable:consent_required" {
			t.Fatalf("diagnostic %+v", d)
		}
	}
	if z.calls.Load() != 0 {
		t.Fatalf("%d requests without consent", z.calls.Load())
	}
	if _, err := os.Stat(filepath.Join(dir, "credentials.json")); err != nil {
		t.Fatal(err)
	}
	assertNoZCodeSecret(t, cache, r, diags)
}

// Consent on: Coding Plan quota through the account's own key, on the z.ai host only, with the
// ZCode files untouched and nothing derived from the credential stored.
func TestD369ConsentOnReadsCodingPlanQuota(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	dir := writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true, jwt: zcodeTestJWT(time.Now().Add(time.Hour))})
	before := zcodeSnapshot(t, dir)
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if g, ok := p.ReaderAccessGrant("zai"); !ok || g.ConfigSource == nil || g.ConfigSource.Tool != zcodeLoginTool {
		t.Fatal("ZCode sign-in not admitted after consent")
	}
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatalf("refresh: %v", err)
	}
	if z.calls.Load() != 1 {
		t.Fatalf("calls = %d", z.calls.Load())
	}
	req := <-z.seen
	if req.Host != "api.z.ai" || req.URL.Path != "/api/monitor/usage/quota/limit" || req.Header.Get("Authorization") != "Bearer "+zcodeAccountCanary {
		t.Fatalf("request host=%s path=%s auth-ok=%t", req.Host, req.URL.Path, req.Header.Get("Authorization") == "Bearer "+zcodeAccountCanary)
	}
	r, s, diags := zcodeReport(t, cache, now)
	a := zcodeAccount(r)
	if a == nil || len(a.Windows) == 0 || a.Windows[0].UsedPercent == nil || *a.Windows[0].UsedPercent != 40 {
		t.Fatalf("no quota row: account=%+v source=%+v", a, s)
	}
	if a.Subscription != nil || ZCodeSubscription(cache, consent.Capture(), now) != "" {
		t.Fatalf("a reference was derived from the sign-in: %+v", a.Subscription)
	}
	if after := zcodeSnapshot(t, dir); len(after) != len(before) {
		t.Fatalf("ZCode folder changed: %v -> %v", before, after)
	} else {
		for name, v := range before {
			if after[name] != v {
				t.Fatalf("ZCode file %s changed", name)
			}
		}
	}
	assertNoZCodeSecret(t, cache, r, diags)
}

// Start Plan: the live JWT goes to ZCode's billing balance on zcode.z.ai with ZCode's device id.
func TestD369StartPlanBillingWithDeviceMid(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	jwt := zcodeTestJWT(time.Now().Add(time.Hour))
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "start-plan", jwt: jwt, deviceMid: true})
	body := `{"code":200,"data":{"plans":[{"name":"ZCode Start Plan","status":"active","plan_id":"p1","entitlements":[{"entitlement_id":"e1","period":"daily"}]}],
	 "balances":[{"entitlement_id":"e1","plan_id":"p1","show_name":"GLM-5.3","total_units":1000,"used_units":250,"remaining_units":750,"expires_at":` + jsonInt(time.Now().Add(6*time.Hour).Unix()) + `}]}}`
	z := newZCodeServer(t, body, 200, "zcode.z.ai")
	grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
	now := time.Now().UTC()
	cache := t.TempDir()
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatalf("refresh: %v", err)
	}
	if z.calls.Load() != 1 {
		t.Fatalf("calls = %d", z.calls.Load())
	}
	req := <-z.seen
	if req.Host != "zcode.z.ai" || req.URL.Path != "/api/v1/zcode-plan/billing/balance" || req.Header.Get("Authorization") != "Bearer "+jwt || req.Header.Get("X-Device-Mid") != zcodeMidCanary {
		t.Fatalf("billing request host=%s path=%s mid-ok=%t", req.Host, req.URL.Path, req.Header.Get("X-Device-Mid") == zcodeMidCanary)
	}
	r, s, diags := zcodeReport(t, cache, now)
	a := zcodeAccount(r)
	if a == nil || len(a.Windows) != 1 || a.Windows[0].UsedPercent == nil || *a.Windows[0].UsedPercent != 25 || a.Windows[0].WindowMinutes != 1440 {
		t.Fatalf("no billing row: account=%+v source=%+v", a, s)
	}
	assertNoZCodeSecret(t, cache, r, diags)
}

func jsonInt(v int64) string { b, _ := json.Marshal(v); return string(b) }

// An expired sign-in asks the user to sign in to ZCode again; it is never renewed and the expired
// JWT is not even sent. A server rejection of the account key gives the same state.
func TestD369ExpiredSignInAsksToSignInAgain(t *testing.T) {
	t.Run("expired jwt", func(t *testing.T) {
		isolateHome(t)
		t.Setenv("Z_AI_API_KEY", "")
		home, _ := os.UserHomeDir()
		dir := writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "start-plan", jwt: zcodeTestJWT(time.Now().Add(-time.Minute))})
		before := zcodeSnapshot(t, dir)
		z := newZCodeServer(t, `{}`, 200, "zcode.z.ai")
		grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
		now := time.Now().UTC()
		cache := t.TempDir()
		p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
		_ = ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now)
		if z.calls.Load() != 0 {
			t.Fatal("an expired JWT was sent")
		}
		r, s, diags := zcodeReport(t, cache, now)
		if s.ErrorCode != "login_expired" || zcodeAccount(r) != nil && len(zcodeAccount(r).Windows) > 0 {
			t.Fatalf("source %+v, want login_expired and no data", s)
		}
		for name, v := range zcodeSnapshot(t, dir) {
			if before[name] != v {
				t.Fatalf("ZCode file %s changed (renewal attempted?)", name)
			}
		}
		assertNoZCodeSecret(t, cache, r, diags)
	})
	t.Run("rejected key", func(t *testing.T) {
		isolateHome(t)
		t.Setenv("Z_AI_API_KEY", "")
		home, _ := os.UserHomeDir()
		writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
		z := newZCodeServer(t, `{"code":401,"msg":"token expired or incorrect"}`, 401, "api.z.ai")
		grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
		now := time.Now().UTC()
		cache := t.TempDir()
		_ = ExecuteScopeRefresh(context.Background(), ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), consent.ScopeZaiAccountUsageSavedLogin, now)
		if z.calls.Load() != 1 {
			t.Fatalf("calls = %d", z.calls.Load())
		}
		r, s, diags := zcodeReport(t, cache, now)
		if s.ErrorCode != "login_expired" {
			t.Fatalf("source %+v, want login_expired", s)
		}
		assertNoZCodeSecret(t, cache, r, diags)
	})
}

// Region scoping (Pulse lesson): a mainland (BigModel) sign-in goes only to open.bigmodel.cn, never
// to a z.ai host, and an international one never to the mainland host.
func TestD369RegionHostScoping(t *testing.T) {
	t.Run("bigmodel coding plan goes to open.bigmodel.cn", func(t *testing.T) {
		isolateHome(t)
		t.Setenv("Z_AI_API_KEY", "")
		home, _ := os.UserHomeDir()
		writeZCodeLogin(t, home, zcodeFixture{family: "bigmodel", kind: "individual-coding-plan", accountKey: true})
		z := newZCodeServer(t, zcodeQuotaBody, 200, "open.bigmodel.cn")
		grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
		cache := t.TempDir()
		_ = ExecuteScopeRefresh(context.Background(), ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), consent.ScopeZaiAccountUsageSavedLogin, time.Now())
		if z.calls.Load() != 1 {
			t.Fatalf("calls = %d", z.calls.Load())
		}
		if req := <-z.seen; req.Host != "open.bigmodel.cn" {
			t.Fatalf("mainland sign-in sent to %s", req.Host)
		}
	})
	t.Run("bigmodel start plan is not sent to zcode.z.ai", func(t *testing.T) {
		isolateHome(t)
		t.Setenv("Z_AI_API_KEY", "")
		home, _ := os.UserHomeDir()
		writeZCodeLogin(t, home, zcodeFixture{family: "bigmodel", kind: "start-plan", jwt: zcodeTestJWT(time.Now().Add(time.Hour))})
		z := newZCodeServer(t, `{}`, 200, "zcode.z.ai", "api.z.ai", "open.bigmodel.cn")
		grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
		cache := t.TempDir()
		_ = ExecuteScopeRefresh(context.Background(), ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), consent.ScopeZaiAccountUsageSavedLogin, time.Now())
		if z.calls.Load() != 0 {
			t.Fatalf("mainland JWT sent (%d calls)", z.calls.Load())
		}
		if _, s, _ := zcodeReport(t, cache, time.Now()); s.ErrorCode != "region_refused" {
			t.Fatalf("source %+v", s)
		}
	})
	t.Run("zai entry pointing at the mainland host is refused", func(t *testing.T) {
		isolateHome(t)
		t.Setenv("Z_AI_API_KEY", "")
		home, _ := os.UserHomeDir()
		writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true, baseURL: "https://open.bigmodel.cn/api/anthropic"})
		z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai", "open.bigmodel.cn")
		grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
		cache := t.TempDir()
		_ = ExecuteScopeRefresh(context.Background(), ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), consent.ScopeZaiAccountUsageSavedLogin, time.Now())
		if z.calls.Load() != 0 {
			t.Fatalf("international sign-in sent across regions (%d calls)", z.calls.Load())
		}
	})
	t.Run("request set refuses other hosts", func(t *testing.T) {
		c := accountReadClient(consent.ScopeZaiAccountUsageSavedLogin, nil)
		for _, u := range []string{"https://open.bigmodel.cn/api/v1/zcode-plan/billing/balance", "https://zcode.z.ai/api/monitor/usage/quota/limit", "https://api.z.ai.evil.test/api/monitor/usage/quota/limit"} {
			req, _ := http.NewRequest(http.MethodGet, u, nil)
			req.Header.Set("Authorization", "Bearer x")
			if resp, err := c.Do(req); err == nil {
				resp.Body.Close()
				t.Fatalf("%s was allowed", u)
			}
		}
	})
}

// A body code 500 inside HTTP 200 is "no Coding Plan under this sign-in", a state.
func TestD369Code500IsNoPlan(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	newZCodeServer(t, `{"code":500,"msg":"no subscription","success":false}`, 200, "api.z.ai")
	grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
	cache := t.TempDir()
	now := time.Now().UTC()
	_ = ExecuteScopeRefresh(context.Background(), ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), consent.ScopeZaiAccountUsageSavedLogin, now)
	r, s, diags := zcodeReport(t, cache, now)
	if s.ErrorCode != "no_plan" {
		t.Fatalf("source %+v, want no_plan", s)
	}
	assertNoZCodeSecret(t, cache, r, diags)
	if e := parseZCodeBilling(zcodeBillingResponse{Code: func() *int { v := 500; return &v }()}, now); e.ErrorCode != "no_plan" {
		t.Fatalf("billing code 500 = %+v", e)
	}
}

// Key first: with ZCode's provider-file key or a GLM key in the environment the sign-in is not read.
func TestD369KeyRouteStaysFirst(t *testing.T) {
	t.Run("provider file", func(t *testing.T) {
		isolateHome(t)
		t.Setenv("Z_AI_API_KEY", "")
		home, _ := os.UserHomeDir()
		writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
		writeZCodeProviders(t, home, zcodeTemplateProvider)
		grantZCodeLogin(t)
		p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
		if g, ok := p.ReaderAccessGrant("zai"); !ok || g.ConfigSource == nil || g.ConfigSource.Tool != "zcode" {
			t.Fatal("the provider-file key route lost its place")
		}
		if p.ZCodeLoginConsent {
			t.Fatal("consent asked while a key route serves")
		}
	})
	t.Run("environment key", func(t *testing.T) {
		isolateHome(t)
		t.Setenv("Z_AI_API_KEY", "env-key-canary")
		home, _ := os.UserHomeDir()
		writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
		grantZCodeLogin(t)
		p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
		if g, ok := p.ReaderAccessGrant("zai"); ok && g.ConfigSource != nil && g.ConfigSource.Tool == zcodeLoginTool {
			t.Fatal("sign-in route chosen over an environment key")
		}
	})
}

// Revoking the scope hides the reading at once and stops the route.
func TestD369RevokeHidesReading(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
	cache := t.TempDir()
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	if err := ExecuteScopeRefresh(context.Background(), ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatal(err)
	}
	if r, _, _ := zcodeReport(t, cache, now); zcodeAccount(r) == nil {
		t.Fatal("no reading before revoke")
	}
	s, _ := consent.Load(consent.Path())
	if _, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "revoke", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion, Deny: []string{consent.ScopeZaiAccountUsageSavedLogin}}, consent.GrantHooks{}); err != nil && !strings.Contains(err.Error(), "cleanup") {
		t.Fatal(err)
	}
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if g, ok := p.ReaderAccessGrant("zai"); ok && g.ConfigSource != nil && g.ConfigSource.Tool == zcodeLoginTool {
		t.Fatal("route still admitted after revoke")
	}
	if r, _, _ := zcodeReport(t, cache, now); zcodeAccount(r) != nil && len(zcodeAccount(r).Windows) > 0 {
		t.Fatal("reading shown after revoke")
	}
}

// The machine-derived secret matches ZCode's defaultCredentialSecret, so a real store decrypts
// without ZCODE_CREDENTIAL_SECRET.
func TestD369MachineSecretDerivation(t *testing.T) {
	isolateHome(t)
	t.Setenv("ZCODE_CREDENTIAL_SECRET", "")
	home, _ := os.UserHomeDir()
	u, err := user.Current()
	if err != nil {
		t.Skip("no current user")
	}
	secret := "zcode-credential-fallback:" + runtime.GOOS + ":" + home + ":" + u.Username
	if got := zcodeDecrypt(zcodeTestEncrypt(t, "plain", secret), zcodeCredentialSecret()); got != "plain" {
		t.Fatalf("derived secret does not open the store")
	}
	if zcodeDecrypt(zcodeTestEncrypt(t, "plain", "another-machine"), zcodeCredentialSecret()) != "" {
		t.Fatal("a foreign secret opened the store")
	}
	if encodeURIComponent("a b+c@d!") != "a%20b%2Bc%40d!" {
		t.Fatalf("encodeURIComponent = %q", encodeURIComponent("a b+c@d!"))
	}
}
