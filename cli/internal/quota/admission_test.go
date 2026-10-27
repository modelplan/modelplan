package quota

import (
	"context"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestHelperKeychainEnvironmentIsAccessScoped(t *testing.T) {
	isolateHome(t)
	t.Setenv("CODEXBAR_DISABLE_KEYCHAIN_ACCESS", "0")
	dir := t.TempDir()
	bin := filepath.Join(dir, "helper")
	os.WriteFile(bin, []byte("#!/bin/sh\nprintf '%s' \"$CODEXBAR_DISABLE_KEYCHAIN_ACCESS\"\n"), 0700)
	for _, v := range []struct{ access, want string }{{"standard", "1"}, {"browser-session", "0"}, {"unknown", "1"}} {
		out, err := runCodexBar(context.Background(), bin, "fixture", v.access)
		if err != nil || string(out) != v.want {
			t.Fatal(v, string(out), err)
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
