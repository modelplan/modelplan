// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/testenv"
	"os"
	"path/filepath"
	"testing"
)

func TestSampling1122SettingsGrantKeepsQRLoginWhenNoEnvironmentKey(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	dir := filepath.Join(home, ".zcode", "v2")
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"setting.json", "config.json", "credentials.json"} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(`{}`), 0600); err != nil {
			t.Fatal(err)
		}
	}
	cache := t.TempDir()
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	paths := func(a consent.Admission) quota.Paths { return quota.ProductionPathsWithAdmission(cache, "1.0.0", a) }
	b, err := NewSharedBackend(SharedConfig{Detect: func() detect.Report {
		return detect.Report{Tools: []detect.Tool{{Entry: detect.Entry{ProviderID: "zai", Preferred: "native", ReaderID: "native:zai"}, Detected: true}}}
	}, Paths: paths, Cleanup: func(string, bool) error { return nil }})
	if err != nil {
		t.Fatal(err)
	}
	state := consent.Capture().State()
	_, err = b.Grant(context.Background(), wire.ConsentGrantParams{RequestID: "sampling-qr", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation, TextVersion: consent.TextVersion, Allow: []string{consent.ScopeZaiAccountUsageAPIKey, consent.ScopeZaiAccountUsageSavedLogin}})
	if err != nil {
		t.Fatal(err)
	}
	after := consent.Capture()
	if after.State().Tools["zai"].KeyEnv != "" {
		t.Fatal("grant selected an absent environment key")
	}
	g, ok := paths(after).ReaderAccessGrant("zai")
	if !ok || g.ConfigSource == nil || g.ConfigSource.Tool != "zcode-login" {
		t.Fatalf("saved-login route not selected: %+v", g)
	}
}
