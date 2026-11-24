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

// G3-127 (owner test build 15): the first-run page read ZCode's GLM Coding Plan through ZCode's own provider file (the
// default route), but the Done grant recorded the environment-key source Z_AI_API_KEY. A recorded key source counts as
// a chosen source, so ZCode's default route switched off and GLM was read from an environment variable the app does not
// have: no reading, so no widget ring and no cockpit column. Done must keep the source the first-run page showed.
func TestFirstRunDoneKeepsZCodesDetectedGLMSource(t *testing.T) {
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
	// What the first-run page reads before Done: ZCode's own provider file.
	if g, ok := paths(consent.Capture()).ReaderAccess.Grants["zai"]; !ok || g.ConfigSource == nil || g.ConfigSource.Tool != "zcode" {
		t.Fatalf("fixture: before Done the default ZCode route must be read: %+v", g)
	}
	// Done: the ticked ZCode / GLM row allows both of its standard paths in one grant.
	state := consent.Capture().State()
	if _, err := b.Grant(context.Background(), wire.ConsentGrantParams{RequestID: "first-run-done", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation,
		TextVersion: consent.TextVersion, Allow: []string{consent.ScopeZaiLocalHistory, consent.ScopeZaiAccountUsageAPIKey}, Deny: []string{}}); err != nil {
		t.Fatal(err)
	}
	after := consent.Capture().State()
	if !after.AllowsScope(consent.ScopeZaiAccountUsageAPIKey, consent.Automatic) {
		t.Fatal("Done did not allow the GLM key path")
	}
	if got := after.Tools["zai"].KeyEnv; got != "" {
		t.Fatalf("Done recorded an environment-key source the app cannot read: %q", got)
	}
	g, ok := paths(consent.Capture()).ReaderAccess.Grants["zai"]
	if !ok || g.ConfigSource == nil || g.ConfigSource.Tool != "zcode" {
		t.Fatalf("after Done ZCode's detected source must still be read: %+v", g)
	}
}

// macrevd-1037-1: another provider's key grant never consults the GLM manual-key store (nor ZCode's file). Every
// explicit-key scope other than GLM's is granted with a GLM manual key stored and GLM's key path refused.
func TestOtherProvidersKeyGrantDoesNotReadTheGLMKeyStore(t *testing.T) {
	granted := 0
	for _, d := range consent.Definitions() {
		if d.Class != consent.ExplicitKey || d.Tool == "zai" {
			continue
		}
		t.Run(d.ID, func(t *testing.T) {
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
			if err := quota.SetManualKey(cache, "zai", "fake-zai-key-0001", "global"); err != nil {
				t.Fatal(err)
			}
			if _, err := consent.EnsureStore(consent.Path()); err != nil {
				t.Fatal(err)
			}
			glmLookups := 0
			paths := func(a consent.Admission) quota.Paths { return quota.ProductionPathsWithAdmission(cache, "1.0.0", a) }
			b, err := NewSharedBackend(SharedConfig{
				Detect: func() detect.Report {
					return detect.Report{Tools: []detect.Tool{
						{Entry: detect.Entry{ProviderID: "zai", Preferred: "native", ReaderID: "native:zai"}, Detected: true},
						{Entry: detect.Entry{ProviderID: d.Tool, Preferred: "native", ReaderID: "native:" + d.Tool}, Detected: true},
					}}
				},
				ManualKeyPresent: func(p string) bool {
					if p == "zai" {
						glmLookups++
					}
					return quota.ManualKeyPresent(cache, p)
				},
				Paths: paths, Cleanup: func(string, bool, consent.EraseGuard) error { return nil },
			})
			if err != nil {
				t.Fatal(err)
			}
			state := consent.Capture().State()
			if _, err := b.Grant(context.Background(), wire.ConsentGrantParams{RequestID: "deny-glm", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation,
				TextVersion: consent.TextVersion, Allow: []string{}, Deny: []string{consent.ScopeZaiAccountUsageAPIKey}}); err != nil {
				t.Fatal(err)
			}
			glmLookups = 0
			state = consent.Capture().State()
			_, err = b.Grant(context.Background(), wire.ConsentGrantParams{RequestID: "allow-" + d.Tool, ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation,
				TextVersion: consent.TextVersion, Allow: []string{d.ID}, Deny: []string{}})
			if err == nil {
				granted++
			} else {
				t.Logf("%s not admitted here (%v); the lookup count is still checked", d.ID, err)
			}
			if glmLookups != 0 {
				t.Fatalf("granting %s consulted the GLM manual-key store %d time(s)", d.ID, glmLookups)
			}
		})
	}
	if granted == 0 {
		t.Fatal("no other explicit-key grant was admitted, so the boundary was not exercised")
	}
}
