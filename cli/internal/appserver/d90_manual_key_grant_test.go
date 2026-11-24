// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// Post-merge #795 (1): saving a manual GLM key allows the GLM scope, and that grant must not record an environment-key
// source when ZCode's own provider file is the detected source; otherwise ZCode's default route is switched off and
// removing the manual key leaves GLM unread.
func TestManualKeyGrantKeepsZCodesDetectedSourceForWhenTheKeyIsRemoved(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	provider := quota.ZCodeProviderConfig(home)
	if err := os.MkdirAll(filepath.Dir(provider), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(provider, []byte("{}"), 0o600); err != nil {
		t.Fatal(err)
	}
	cache := t.TempDir()
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	paths := func(a consent.Admission) quota.Paths { return quota.ProductionPathsWithAdmission(cache, "1.0.0", a) }
	b, err := NewSharedBackend(SharedConfig{
		Detect: func() detect.Report {
			return detect.Report{Tools: []detect.Tool{{Entry: detect.Entry{ProviderID: "zai", Preferred: "native", ReaderID: "native:zai"}, Detected: true}}}
		},
		ManualKeyPresent: func(provider string) bool { return quota.ManualKeyPresent(cache, provider) },
		Paths:            paths, Cleanup: func(string, bool, consent.EraseGuard) error { return nil },
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := quota.SetManualKey(cache, "zai", "fake-zai-key-0001", "global"); err != nil {
		t.Fatal(err)
	}
	state := consent.Capture().State()
	if _, err := b.Grant(context.Background(), wire.ConsentGrantParams{RequestID: "save-key", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation,
		TextVersion: consent.TextVersion, Allow: []string{consent.ScopeZaiAccountUsageAPIKey}, Deny: []string{}}); err != nil {
		t.Fatal(err)
	}
	after := consent.Capture().State()
	if after.Tools["zai"].KeyEnv != "" {
		t.Fatalf("the grant recorded an environment-key source: %q", after.Tools["zai"].KeyEnv)
	}
	if err := quota.RemoveManualKey(cache, "zai"); err != nil {
		t.Fatal(err)
	}
	grant, ok := paths(consent.Capture()).ReaderAccess.Grants["zai"]
	if !ok || grant.ConfigSource == nil || grant.ConfigSource.Tool != "zcode" {
		t.Fatalf("after the manual key is removed ZCode's detected source must be read again: %+v", grant)
	}
}

// macrev2-993-2: an explicit environment-key source chosen before the manual key stays chosen when the key is saved,
// even though ZCode's provider file exists.
func TestManualKeyGrantKeepsAnExplicitEnvironmentSource(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("Z_AI_API_KEY", "fake-env-key-0003")
	home, _ := os.UserHomeDir()
	provider := quota.ZCodeProviderConfig(home)
	if err := os.MkdirAll(filepath.Dir(provider), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(provider, []byte("{}"), 0o600); err != nil {
		t.Fatal(err)
	}
	cache := t.TempDir()
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	paths := func(a consent.Admission) quota.Paths { return quota.ProductionPathsWithAdmission(cache, "1.0.0", a) }
	b, err := NewSharedBackend(SharedConfig{
		Detect: func() detect.Report {
			return detect.Report{Tools: []detect.Tool{{Entry: detect.Entry{ProviderID: "zai", Preferred: "native", ReaderID: "native:zai"}, Detected: true}}}
		},
		ManualKeyPresent: func(provider string) bool { return quota.ManualKeyPresent(cache, provider) },
		Paths:            paths, Cleanup: func(string, bool, consent.EraseGuard) error { return nil },
	})
	if err != nil {
		t.Fatal(err)
	}
	grant := func(id string) {
		state := consent.Capture().State()
		if _, err := b.Grant(context.Background(), wire.ConsentGrantParams{RequestID: id, ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation,
			TextVersion: consent.TextVersion, Allow: []string{consent.ScopeZaiAccountUsageAPIKey}, Deny: []string{}}); err != nil {
			t.Fatal(err)
		}
	}
	grant("env-first") // no manual key yet: the explicit environment-key source
	if got := consent.Capture().State().Tools["zai"].KeyEnv; got != "Z_AI_API_KEY" {
		t.Fatalf("the environment source was not recorded: %q", got)
	}
	if err := quota.SetManualKey(cache, "zai", "fake-zai-key-0001", "global"); err != nil {
		t.Fatal(err)
	}
	grant("save-key")
	if got := consent.Capture().State().Tools["zai"].KeyEnv; got != "Z_AI_API_KEY" {
		t.Fatalf("saving a manual key erased the explicitly selected environment source: %q", got)
	}
}
