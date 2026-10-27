package quota

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestHelperCookieConfigAndKeychainAreAccessScoped(t *testing.T) {
	isolateHome(t)
	t.Setenv("CODEXBAR_DISABLE_KEYCHAIN_ACCESS", "0")
	dir := t.TempDir()
	ambient := filepath.Join(dir, "ambient.json")
	ambientJSON := []byte(`{"version":1,"providers":[{"id":"cursor","cookieSource":"auto","cookieHeader":"synthetic-cookie"},{"id":"windsurf","cookieSource":"auto"}],"hooks":{"enabled":true}}`)
	if err := os.WriteFile(ambient, ambientJSON, 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("CODEXBAR_CONFIG", ambient)
	t.Setenv("HTTPS_PROXY", "http://proxy.invalid:1234")
	bin := filepath.Join(dir, "helper")
	script := `#!/bin/sh
printf '%s\n' "$CODEXBAR_DISABLE_KEYCHAIN_ACCESS" "$CODEXBAR_CONFIG" "$HTTPS_PROXY"
cat "$CODEXBAR_CONFIG"
exit "$MODELPLAN_TEST_HELPER_EXIT"
`
	if err := os.WriteFile(bin, []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	for _, exit := range []string{"0", "7"} {
		t.Setenv("MODELPLAN_TEST_HELPER_EXIT", exit)
		for _, v := range []struct{ access, keychain, cookies string }{{"standard", "1", "off"}, {"browser-session", "0", "auto"}, {"unknown", "1", "off"}, {"", "1", "off"}} {
			out, err := runCodexBar(context.Background(), bin, "cursor", v.access)
			if (err == nil) != (exit == "0") {
				t.Fatalf("%+v exit %s: %v", v, exit, err)
			}
			parts := strings.SplitN(string(out), "\n", 4)
			if len(parts) != 4 || parts[0] != v.keychain || parts[1] == ambient || parts[2] != "http://proxy.invalid:1234" {
				t.Fatalf("%+v: %s", v, out)
			}
			var config struct {
				Version   int              `json:"version"`
				Providers []map[string]any `json:"providers"`
			}
			if err := json.Unmarshal([]byte(parts[3]), &config); err != nil {
				t.Fatal(err, string(out))
			}
			if config.Version != 1 || len(config.Providers) != 1 {
				t.Fatal("usage must select only its explicit provider", config)
			}
			p := config.Providers[0]
			if len(p) != 3 || p["id"] != "cursor" || p["enabled"] != true || p["cookieSource"] != v.cookies || strings.Contains(parts[3], "synthetic-cookie") || strings.Contains(parts[3], "hooks") {
				t.Fatalf("%+v: ambient config leaked or wrong cookie source: %s", v, parts[3])
			}
			if _, err := os.Stat(filepath.Dir(parts[1])); !os.IsNotExist(err) {
				t.Fatal("temporary config retained after helper exit", err)
			}
		}
	}
	if b, err := os.ReadFile(ambient); err != nil || string(b) != string(ambientJSON) {
		t.Fatal("ambient config changed", err)
	}
}

func TestHelperUsageConfigIsPrivateAndFailsClosed(t *testing.T) {
	isolateHome(t)
	file, cleanup, err := codexBarUsageConfig("cursor", "standard")
	if err != nil {
		t.Fatal(err)
	}
	defer cleanup()
	for _, p := range []string{file, filepath.Dir(file)} {
		info, err := os.Stat(p)
		if err != nil || info.Mode().Perm()&0077 != 0 {
			t.Fatal("usage config must be private", p, info, err)
		}
	}
	for _, provider := range []string{"all", "both", "cursor,windsurf", "../cursor"} {
		if _, _, err := codexBarUsageConfig(provider, "browser-session"); err == nil {
			t.Fatal("accepted non-single provider", provider)
		}
	}
	t.Setenv("TMPDIR", filepath.Join(t.TempDir(), "missing"))
	if out, err := runCodexBar(context.Background(), "/nonexistent/helper", "cursor"); err == nil || !strings.Contains(err.Error(), "config unavailable") || len(out) != 0 {
		t.Fatal("helper must not run without its generated config", string(out), err)
	}
}

func TestHelperRefreshCookieAutoRequiresCurrentBrowserRouteAndGrant(t *testing.T) {
	isolateHome(t)
	p := cbPaths(t, "cursor") // Synthetic audit only; not an upstream route certification.
	cat := loadReaderCatalogue(p.Cache)
	dir := t.TempDir()
	bin, log := filepath.Join(dir, "helper"), filepath.Join(dir, "configs")
	t.Setenv("MODELPLAN_TEST_HELPER_CONFIGS", log)
	if err := os.WriteFile(bin, []byte(`#!/bin/sh
cat "$CODEXBAR_CONFIG" >> "$MODELPLAN_TEST_HELPER_CONFIGS"
printf '\n' >> "$MODELPLAN_TEST_HELPER_CONFIGS"
printf '[]'
`), 0700); err != nil {
		t.Fatal(err)
	}
	for _, v := range []struct {
		access string
		grant  bool
		want   string
	}{{"standard", false, "off"}, {"browser-session", false, ""}, {"browser-session", true, "auto"}, {"standard", true, "off"}} {
		for i := range cat.Detectors {
			if cat.Detectors[i].ProviderID == "cursor" {
				cat.Detectors[i].CodexBar.Access = v.access
			}
		}
		if err := consent.Change(consent.Path(), func(s *consent.State) error {
			if err := consent.Set(s, "cursor", true, "codexbar:cursor", "codexbar", cbNow); err != nil {
				return err
			}
			r := s.Tools["cursor"]
			r.BrowserSession = v.grant
			s.Tools["cursor"] = r
			return nil
		}); err != nil {
			t.Fatal(err)
		}
		_ = os.Remove(log)
		err := RefreshCodexBar(context.Background(), p, bin, cbNow)
		b, readErr := os.ReadFile(log)
		if v.want == "" {
			if err == nil || !os.IsNotExist(readErr) {
				t.Fatal("browser helper ran without a separate grant", err, readErr)
			}
			continue
		}
		if err != nil || readErr != nil || !strings.Contains(string(b), `"cookieSource":"`+v.want+`"`) {
			t.Fatal(v, string(b), err, readErr)
		}
	}
}

func TestNativeRefreshRevocationFencesPublication(t *testing.T) {
	isolateHome(t)
	p := nativePaths(t)
	started, release := make(chan struct{}), make(chan struct{})
	defer func() {
		select {
		case <-release:
		default:
			close(release)
		}
	}()
	old := nativeReaders["fixture"]
	nativeReaders["fixture"] = &nativeReader{Name: "Synthetic", Regions: []string{"global"}, Collect: func(ctx context.Context, _ *http.Client, _ string, now time.Time) codexbarEntry {
		close(started)
		select {
		case <-release:
		case <-ctx.Done():
		}
		return codexbarEntry{Status: "ok", ObservedAt: now}
	}}
	t.Cleanup(func() {
		if old == nil {
			delete(nativeReaders, "fixture")
		} else {
			nativeReaders["fixture"] = old
		}
	})
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		return consent.Set(s, "fixture", true, "native:fixture", "native", time.Now())
	}); err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	go func() { done <- RefreshNative(ctx, p, time.Now()) }()
	select {
	case <-started:
	case <-ctx.Done():
		t.Fatal("reader did not enter")
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "fixture", false, "", "", time.Now()) }); err != nil {
		t.Fatal(err)
	}
	if err := ForgetTool(p, "fixture"); err == nil {
		t.Fatal("cleanup succeeded during an admitted writer")
	}
	close(release)
	if err := <-done; err == nil || !strings.Contains(err.Error(), "consent changed") {
		t.Fatal("stale native result published", err)
	}
	if _, err := os.Stat(nativePath(p.Cache)); !os.IsNotExist(err) {
		t.Fatal("stale reading cached")
	}
	if err := ForgetTool(p, "fixture"); err != nil {
		t.Fatal(err)
	}
	if err := RefreshNative(ctx, p, time.Now()); err == nil {
		t.Fatal("revoked reader re-admitted")
	}
}

func TestHelperRefreshRevocationFencesPublication(t *testing.T) {
	isolateHome(t)
	p := cbPaths(t, "cursor")
	inner, _ := fakeCodexBar(t)
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		return consent.Set(s, "cursor", true, "codexbar:cursor", "codexbar", time.Now())
	}); err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	bin, started, release := filepath.Join(dir, "paused-helper"), filepath.Join(dir, "started"), filepath.Join(dir, "release")
	t.Setenv("MODELPLAN_TEST_HELPER_STARTED", started)
	t.Setenv("MODELPLAN_TEST_HELPER_RELEASE", release)
	t.Setenv("MODELPLAN_TEST_HELPER_INNER", inner)
	script := `#!/bin/sh
: > "$MODELPLAN_TEST_HELPER_STARTED"
while [ ! -f "$MODELPLAN_TEST_HELPER_RELEASE" ]; do sleep 0.01; done
exec "$MODELPLAN_TEST_HELPER_INNER" "$@"
`
	os.WriteFile(bin, []byte(script), 0700)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	defer os.WriteFile(release, nil, 0600)
	done := make(chan error, 1)
	go func() { done <- RefreshCodexBar(ctx, p, bin, cbNow) }()
	for {
		if _, err := os.Stat(started); err == nil {
			break
		}
		if ctx.Err() != nil {
			t.Fatal("helper did not enter")
		}
		time.Sleep(time.Millisecond)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "cursor", false, "", "", time.Now()) }); err != nil {
		t.Fatal(err)
	}
	if err := ForgetTool(p, "cursor"); err == nil {
		t.Fatal("cleanup succeeded during a helper writer")
	}
	os.WriteFile(release, nil, 0600)
	if err := <-done; err == nil || !strings.Contains(err.Error(), "consent changed") {
		t.Fatal("stale helper result published", err)
	}
	if _, err := os.Stat(codexbarPath(p.Cache)); !os.IsNotExist(err) {
		t.Fatal("stale helper cache written")
	}
	if err := ForgetTool(p, "cursor"); err != nil {
		t.Fatal(err)
	}
	if err := RefreshCodexBar(ctx, p, bin, cbNow); err == nil {
		t.Fatal("revoked helper admitted")
	}
}

func TestCodexRuntimeRevocationFencesPublication(t *testing.T) {
	isolateHome(t)
	p := Paths{Cache: t.TempDir()}
	inner, _ := fakeCodex(t, acctResponse)
	dir := t.TempDir()
	bin, started, release := filepath.Join(dir, "paused-codex"), filepath.Join(dir, "started"), filepath.Join(dir, "release")
	t.Setenv("MODELPLAN_TEST_HELPER_STARTED", started)
	t.Setenv("MODELPLAN_TEST_HELPER_RELEASE", release)
	t.Setenv("MODELPLAN_TEST_HELPER_INNER", inner)
	script := `#!/bin/sh
: > "$MODELPLAN_TEST_HELPER_STARTED"
while [ ! -f "$MODELPLAN_TEST_HELPER_RELEASE" ]; do sleep 0.01; done
exec "$MODELPLAN_TEST_HELPER_INNER" "$@"
`
	os.WriteFile(bin, []byte(script), 0700)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	defer os.WriteFile(release, nil, 0600)
	done := make(chan error, 1)
	go func() { done <- RefreshCodexAccount(ctx, p.Cache, bin, acctNow) }()
	for {
		if _, err := os.Stat(started); err == nil {
			break
		}
		if ctx.Err() != nil {
			t.Fatal("runtime did not enter")
		}
		time.Sleep(time.Millisecond)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "codex", false, "", "", time.Now()) }); err != nil {
		t.Fatal(err)
	}
	if err := ForgetTool(p, "codex"); err == nil {
		t.Fatal("cleanup succeeded during runtime read")
	}
	os.WriteFile(release, nil, 0600)
	if err := <-done; err == nil || !strings.Contains(err.Error(), "consent changed") {
		t.Fatal("stale runtime result published", err)
	}
	if _, err := os.Stat(accountPath(p.Cache)); !os.IsNotExist(err) {
		t.Fatal("stale runtime cache written")
	}
	if err := ForgetTool(p, "codex"); err != nil {
		t.Fatal(err)
	}
	if err := RefreshCodexAccount(ctx, p.Cache, bin, acctNow); err == nil {
		t.Fatal("revoked runtime re-admitted")
	}
}
