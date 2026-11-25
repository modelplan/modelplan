// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
)

// D380 (owner, 2026-11-22): ZCode 3.19+ keeps its credential-store key in the macOS Keychain
// (zai-org/ZCode packages/shared/src/credential-security, systemCredentialCipher.ts): service
// "ZCode Credential Encryption", account hex(sha256(credentials.json path)), value the 32-byte key
// in base64url; entries "enc:v2:os:<fp24>:<iv>.<tag>.<ct>". Synthetic fixtures only: the key is
// generated here and handed in by a fake Keychain provider standing in for the app's operation.

const zcodeMirrorCanary = "mirror-canary-d380"

func zcodeTestKey(t *testing.T) (key []byte, encoded string) {
	t.Helper()
	key = make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		t.Fatal(err)
	}
	return key, base64.RawURLEncoding.EncodeToString(key)
}

func zcodeTestEncryptV2(t *testing.T, plain string, key []byte) string {
	t.Helper()
	block, err := aes.NewCipher(key)
	if err != nil {
		t.Fatal(err)
	}
	gcm, _ := cipher.NewGCM(block)
	iv := make([]byte, 12)
	_, _ = rand.Read(iv)
	sealed := gcm.Seal(nil, iv, []byte(plain), nil)
	body, tag := sealed[:len(sealed)-16], sealed[len(sealed)-16:]
	enc := base64.RawURLEncoding.EncodeToString
	sum := sha256.Sum256(key)
	return "enc:v2:os:" + hex.EncodeToString(sum[:])[:24] + ":" + enc(iv) + "." + enc(tag) + "." + enc(body)
}

// writeZCodeKeychainLogin writes ZCode 3.19's layout: the store re-encrypted under the Keychain
// key (enc:v2:os), credential-source "os", and a plaintext mirror canary in config.json that may
// belong to a previous account.
func writeZCodeKeychainLogin(t *testing.T, home string, f zcodeFixture, key []byte) string {
	t.Helper()
	dir := writeZCodeLogin(t, home, f)
	store := map[string]string{}
	b, _ := os.ReadFile(filepath.Join(dir, "credentials.json"))
	_ = json.Unmarshal(b, &store)
	for name, v := range store {
		store[name] = zcodeTestEncryptV2(t, zcodeDecrypt(v, zcodeTestSecret), key)
	}
	b, _ = json.Marshal(store)
	write := func(name string, body []byte) {
		if err := os.WriteFile(filepath.Join(dir, name), body, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	write("credentials.json", b)
	write("credential-source", []byte("os\n"))
	var config map[string]map[string]map[string]any
	b, _ = os.ReadFile(filepath.Join(dir, "config.json"))
	_ = json.Unmarshal(b, &config)
	for _, p := range config["provider"] {
		p["options"] = map[string]any{"apiKey": zcodeMirrorCanary}
	}
	b, _ = json.Marshal(config)
	write("config.json", b)
	return dir
}

func grantZCodeKeychain(t *testing.T, choice string) {
	t.Helper()
	s, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	hooks := consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) {
		return consent.Record{ReaderID: "native:zai", Backend: "native"}, nil
	}}
	scope := consent.ScopeZaiAccountUsageSavedLogin
	request := consent.Grant{RequestID: "d380-" + choice + "-" + time.Now().Format("150405.000000000"), ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion,
		Allow: []string{scope}, Keychain: map[string]string{scope: choice}}
	if _, err := consent.ApplyGrant(consent.Path(), request, hooks); err != nil {
		t.Fatal(err)
	}
}

// fakeKeychain stands in for the app's credential operation and counts its calls.
type fakeKeychain struct {
	calls  atomic.Int32
	value  string
	status string
	during func()
}

func (f *fakeKeychain) key(context.Context) ([]byte, string) {
	f.calls.Add(1)
	if f.during != nil {
		f.during()
	}
	if f.status != "" {
		return nil, f.status
	}
	return []byte(f.value), ""
}

func assertNoD380Secret(t *testing.T, cache, encoded string, extra ...any) {
	t.Helper()
	assertNoZCodeSecret(t, cache, extra...)
	for _, root := range []string{cache, filepath.Dir(consent.Path())} {
		_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
			if err == nil && info.Mode().IsRegular() {
				b, _ := os.ReadFile(path)
				for _, c := range []string{encoded, "enc:v2:", zcodeMirrorCanary} {
					if strings.Contains(string(b), c) {
						t.Fatalf("%s contains %q", path, c)
					}
				}
			}
			return nil
		})
	}
	for _, v := range extra {
		b, _ := json.Marshal(v)
		if strings.Contains(string(b), encoded) || strings.Contains(string(b), zcodeMirrorCanary) {
			t.Fatal("output carries the Keychain key or the mirror")
		}
	}
}

// Invariants 1, 2 and 6: the saved-login scope comes first, then the Keychain choice, default
// unset. Before Allow no reader runs, the Keychain is never asked and the mirror is never sent.
func TestD380KeychainReadWaitsForItsOwnChoice(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	key, encoded := zcodeTestKey(t)
	writeZCodeKeychainLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true}, key)
	if !detect.ZCodeLoginPresent(home) || !detect.ZCodeKeychainMarkerPresent(ZCodeLoginDir(home)) {
		t.Fatal("Keychain-bound sign-in not detected")
	}
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai", "open.bigmodel.cn", "zcode.z.ai")
	fake := &fakeKeychain{value: encoded}
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()

	if d, _ := consent.Definition(consent.ScopeZaiAccountUsageSavedLogin); !d.Keychain || d.DefaultCheck {
		t.Fatalf("scope definition %+v: want its own Keychain choice, off by default", d)
	}
	p := WithZCodeKeychain(ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), fake.key)
	if !p.ZCodeLoginConsent || p.ZCodeKeychainPending != "" {
		t.Fatalf("before any consent: login=%t keychain=%q", p.ZCodeLoginConsent, p.ZCodeKeychainPending)
	}

	for _, step := range []struct{ grant, pending, code string }{{"", "unset", "keychain_unset"}, {"deny", "denied", "keychain_denied"}} {
		if step.grant == "" {
			grantZCodeLogin(t)
		} else {
			grantZCodeKeychain(t, step.grant)
		}
		p = WithZCodeKeychain(ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), fake.key)
		if _, ok := p.ReaderAccessGrant("zai"); ok || p.ZCodeKeychainPending != step.pending {
			t.Fatalf("%s: grant admitted=%t pending=%q", step.code, ok, p.ZCodeKeychainPending)
		}
		_ = RefreshNativeProviders(context.Background(), p, now, []string{"zai"})
		r, s, diags := zcodeReport(t, cache, now)
		if s.ErrorCode != step.code || zcodeAccount(r) != nil {
			t.Fatalf("source %+v, want %s", s, step.code)
		}
		assertNoD380Secret(t, cache, encoded, r, diags)
	}
	if fake.calls.Load() != 0 || z.calls.Load() != 0 {
		t.Fatalf("keychain calls %d, requests %d before Allow", fake.calls.Load(), z.calls.Load())
	}
}

func TestD380UnexpectedMarkerRequiresChoiceBeforeOpeningLogin(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	dir := writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	// A non-regular replacement must still gate the read without opening the marker.
	if err := os.Mkdir(filepath.Join(dir, "credential-source"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(filepath.Join(dir, "setting.json")); err != nil {
		t.Fatal(err)
	}
	fake := &fakeKeychain{}
	for choice, want := range map[string]string{"unset": "keychain_unset", "denied": "keychain_denied"} {
		if _, got := readZCodeLogin(context.Background(), dir, &ZCodeKeychain{Consent: choice, Key: fake.key}, time.Now()); got != want {
			t.Fatalf("choice %q reached the file reader: got %q, want %q", choice, got, want)
		}
	}
	if fake.calls.Load() != 0 {
		t.Fatal("Keychain was used before Allow")
	}
}

// Allow: one Keychain operation, the store opened in memory, one request to the region's own
// quota host with the account's key (invariant 5), and ZCode's files untouched (invariant 3).
func TestD380KeychainAllowedReadsQuota(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	key, encoded := zcodeTestKey(t)
	dir := writeZCodeKeychainLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true}, key)
	before := zcodeSnapshot(t, dir)
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	fake := &fakeKeychain{value: encoded}
	grantZCodeKeychain(t, "allow")
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	p := WithZCodeKeychain(ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), fake.key)
	if g, ok := p.ReaderAccessGrant("zai"); !ok || !g.Keychain || g.ConfigSource.Keychain == nil || g.ConfigSource.Keychain.Key == nil {
		t.Fatal("Keychain route not admitted after Allow")
	}
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatalf("refresh: %v", err)
	}
	if fake.calls.Load() != 1 || z.calls.Load() != 1 {
		t.Fatalf("keychain %d, requests %d", fake.calls.Load(), z.calls.Load())
	}
	req := <-z.seen
	if req.Host != "api.z.ai" || req.URL.Path != "/api/monitor/usage/quota/limit" || req.Header.Get("Authorization") != "Bearer "+zcodeAccountCanary {
		t.Fatalf("request host=%s path=%s", req.Host, req.URL.Path)
	}
	r, s, diags := zcodeReport(t, cache, now)
	if a := zcodeAccount(r); a == nil || len(a.Windows) == 0 || *a.Windows[0].UsedPercent != 40 {
		t.Fatalf("no reading: %+v", s)
	}
	after := zcodeSnapshot(t, dir)
	for name, v := range before {
		if after[name] != v {
			t.Fatalf("ZCode file %s changed", name)
		}
	}
	if len(after) != len(before) {
		t.Fatal("ZCode folder gained or lost a file")
	}
	assertNoD380Secret(t, cache, encoded, r, diags)
}

// Invariant 6: every Keychain failure is its own clear state, and none falls back to the
// plaintext mirror; a standalone CLI (no app operation) says so.
func TestD380KeychainFailuresAreClearStates(t *testing.T) {
	for _, c := range []struct {
		name, status, value, code string
		noApp                     bool
	}{
		{name: "denied", status: "denied", code: "keychain_denied"},
		{name: "canceled", status: "canceled", code: "keychain_canceled"},
		{name: "background prompt needed", status: "interaction_required", code: "keychain_confirmation_needed"},
		{name: "timeout", status: "timeout", code: "keychain_confirmation_needed"},
		{name: "item missing", status: "not_found", code: "keychain_unavailable"},
		{name: "malformed item", value: "not-a-key", code: "keychain_unavailable"},
		{name: "another path's key", value: base64.RawURLEncoding.EncodeToString(make([]byte, 32)), code: "keychain_unavailable"},
		{name: "standalone CLI", noApp: true, code: "keychain_unavailable"},
	} {
		t.Run(c.name, func(t *testing.T) {
			isolateHome(t)
			t.Setenv("Z_AI_API_KEY", "")
			home, _ := os.UserHomeDir()
			key, encoded := zcodeTestKey(t)
			writeZCodeKeychainLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true}, key)
			z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai", "open.bigmodel.cn", "zcode.z.ai")
			grantZCodeKeychain(t, "allow")
			now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
			cache := t.TempDir()
			p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
			if !c.noApp {
				p = WithZCodeKeychain(p, (&fakeKeychain{status: c.status, value: c.value}).key)
			}
			_ = ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now)
			r, s, diags := zcodeReport(t, cache, now)
			if s.ErrorCode != c.code || zcodeAccount(r) != nil && len(zcodeAccount(r).Windows) > 0 {
				t.Fatalf("source %+v, want %s", s, c.code)
			}
			if z.calls.Load() != 0 {
				t.Fatalf("%d requests (mirror fallback?)", z.calls.Load())
			}
			assertNoD380Secret(t, cache, encoded, r, diags)
		})
	}
}

// Invariant 7: a consent revoked while the Keychain operation runs drops the key and plaintext
// before anything is sent, and the next construction admits nothing.
func TestD380RevokeDuringReadSendsNothing(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	key, encoded := zcodeTestKey(t)
	writeZCodeKeychainLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true}, key)
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeKeychain(t, "allow")
	fake := &fakeKeychain{value: encoded, during: func() { grantZCodeKeychain(t, "deny") }}
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	p := WithZCodeKeychain(ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), fake.key)
	_ = ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now)
	if fake.calls.Load() != 1 || z.calls.Load() != 0 {
		t.Fatalf("keychain %d, %d requests after revoke", fake.calls.Load(), z.calls.Load())
	}
	p = WithZCodeKeychain(ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), fake.key)
	if _, ok := p.ReaderAccessGrant("zai"); ok || p.ZCodeKeychainPending != "denied" {
		t.Fatalf("still admitted after revoke: pending=%q", p.ZCodeKeychainPending)
	}
	r, _, diags := zcodeReport(t, cache, now)
	assertNoD380Secret(t, cache, encoded, r, diags)
}

// Owner 11-22: every ZCode generation keeps working, the route chosen by the store's own format.
func TestD380StoreFormatMatrix(t *testing.T) {
	key, encoded := zcodeTestKey(t)
	allowed := func() *ZCodeKeychain {
		return &ZCodeKeychain{Consent: "allowed", Key: (&fakeKeychain{value: encoded}).key}
	}
	for _, c := range []struct {
		name     string
		store    func(t *testing.T, home string) string
		keychain *ZCodeKeychain
		code     string
	}{
		{"v1 file store (3.11-3.18)", func(t *testing.T, home string) string {
			return writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
		}, &ZCodeKeychain{Consent: "allowed"}, ""}, // macrev2-1162-1: read after Allow, no Keychain operation (Key nil)
		{"v1 file store without the Keychain choice", func(t *testing.T, home string) string {
			return writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
		}, nil, "keychain_unset"},
		{"v2:os Keychain store (3.19+)", func(t *testing.T, home string) string {
			return writeZCodeKeychainLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true}, key)
		}, allowed(), ""},
		{"v2:os without the Keychain choice", func(t *testing.T, home string) string {
			return writeZCodeKeychainLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true}, key)
		}, &ZCodeKeychain{Consent: "unset"}, "keychain_unset"},
		{"v2:os entries without the marker", func(t *testing.T, home string) string {
			dir := writeZCodeKeychainLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true}, key)
			_ = os.Remove(filepath.Join(dir, "credential-source"))
			return dir
		}, allowed(), ""},
		{"mixed v1 and v2:os (mid-migration)", func(t *testing.T, home string) string {
			dir := writeZCodeKeychainLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true}, key)
			addZCodeEntry(t, dir, "legacy", zcodeTestEncrypt(t, "x", zcodeTestSecret))
			return dir
		}, allowed(), "unsupported_login"},
		{"marker with v1 entries", func(t *testing.T, home string) string {
			dir := writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
			_ = os.WriteFile(filepath.Join(dir, "credential-source"), []byte("os\n"), 0o600)
			return dir
		}, allowed(), "unsupported_login"},
		{"v2:env (managed secret)", func(t *testing.T, home string) string {
			dir := writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
			addZCodeEntry(t, dir, "managed", "enc:v2:env:aaaaaaaaaaaaaaaaaaaaaaaa:a.b.c")
			return dir
		}, allowed(), "unsupported_login"},
		{"unknown envelope", func(t *testing.T, home string) string {
			dir := writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
			addZCodeEntry(t, dir, "future", "enc:v3:x")
			return dir
		}, allowed(), "unsupported_login"},
	} {
		t.Run(c.name, func(t *testing.T) {
			isolateHome(t)
			home, _ := os.UserHomeDir()
			dir := c.store(t, home)
			login, code := readZCodeLogin(context.Background(), dir, c.keychain, time.Now())
			if code != c.code {
				t.Fatalf("code %q, want %q", code, c.code)
			}
			if c.code == "" && login.credential != zcodeAccountCanary {
				t.Fatal("wrong credential chosen (mirror?)")
			}
			if c.code != "" && login.credential != "" {
				t.Fatal("a credential survived a refused store")
			}
		})
	}
	// The key route stays first whatever the store's format.
	t.Run("key route", func(t *testing.T) {
		isolateHome(t)
		t.Setenv("Z_AI_API_KEY", "")
		home, _ := os.UserHomeDir()
		writeZCodeKeychainLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true}, key)
		writeZCodeProviders(t, home, zcodeTemplateProvider)
		grantZCodeKeychain(t, "allow")
		p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
		if g, ok := p.ReaderAccessGrant("zai"); !ok || g.ConfigSource == nil || g.ConfigSource.Tool != "zcode" {
			t.Fatal("the provider-file key route lost its place")
		}
	})
}

// The Keychain account is ZCode's own: hex(sha256(absolute credentials.json path)).
func TestD380KeychainAccountDerivation(t *testing.T) {
	path := "/Users/someone/.zcode/v2/credentials.json"
	sum := sha256.Sum256([]byte(path))
	if ZCodeKeychainAccount(path) != hex.EncodeToString(sum[:]) || zcodeKeychainService != "ZCode Credential Encryption" {
		t.Fatal("Keychain item naming differs from ZCode's")
	}
}

func addZCodeEntry(t *testing.T, dir, name, value string) {
	t.Helper()
	store := map[string]string{}
	b, _ := os.ReadFile(filepath.Join(dir, "credentials.json"))
	_ = json.Unmarshal(b, &store)
	store[name] = value
	b, _ = json.Marshal(store)
	if err := os.WriteFile(filepath.Join(dir, "credentials.json"), b, 0o600); err != nil {
		t.Fatal(err)
	}
}
