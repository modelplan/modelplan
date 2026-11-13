package quota

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// Synthetic effective registry, deliberately larger than the legacy allowlist.
// No upstream provider is certified by this metadata/process fixture.
var fixtureRegistry = []string{"claude", "codex", "cursor", "windsurf", "devin", "zai", "opencodego", "copilot", "kiro", "new-provider"}

func fakeConfigMetadata(t *testing.T) string {
	t.Helper()
	bin, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	b, _ := json.Marshal(fixtureRegistry)
	t.Setenv("MODELPLAN_TEST_METADATA_BINARY", bin)
	t.Setenv("GORACE", strings.TrimSpace(os.Getenv("GORACE")+" atexit_sleep_ms=0"))
	t.Setenv("MODELPLAN_TEST_REGISTRY", string(b))
	return `if [ "$1" = config ]; then
exec "$MODELPLAN_TEST_METADATA_BINARY" -test.run=^TestHelperConfigProcess$ -- "$@"
fi
`
}

// Model the pinned helper's normalization: omitted registry entries are added
// with default enablement and no explicit cookie-Off control. This catches the
// old one-provider config, including for a newly added registry ID.
func TestHelperConfigProcess(t *testing.T) {
	if os.Getenv("MODELPLAN_TEST_REGISTRY") == "" || !strings.Contains(strings.Join(os.Args, " "), " -- config ") {
		return
	}
	if os.Getenv("CODEXBAR_DISABLE_KEYCHAIN_ACCESS") != "1" {
		os.Exit(8) // Metadata never needs Keychain access, even for advanced reads.
	}
	var registry []string
	if json.Unmarshal([]byte(os.Getenv("MODELPLAN_TEST_REGISTRY")), &registry) != nil {
		os.Exit(9)
	}
	args := os.Args[len(os.Args)-3:]
	if len(args) != 3 || args[0] != "config" || args[2] != "--json" || os.Getenv("MODELPLAN_TEST_METADATA_FAIL") == args[1] {
		os.Exit(10)
	}
	switch args[1] {
	case "providers":
		out := []map[string]string{}
		for _, id := range registry {
			out = append(out, map[string]string{"provider": id})
		}
		json.NewEncoder(os.Stdout).Encode(out)
	case "dump":
		b, err := os.ReadFile(os.Getenv("CODEXBAR_CONFIG"))
		var config codexBarUsageDocument
		if err != nil || json.Unmarshal(b, &config) != nil {
			os.Exit(11)
		}
		if id := os.Getenv("MODELPLAN_TEST_REGISTRY_EXTRA"); id != "" {
			registry = append(registry, id)
		}
		seen := map[string]bool{}
		for i, p := range config.Providers {
			seen[p.ID] = true
			if p.ID == os.Getenv("MODELPLAN_TEST_IGNORE_COOKIE_OFF") {
				config.Providers[i].CookieSource = "" // Unsupported/ignored Off control.
			}
		}
		for _, id := range registry {
			if !seen[id] {
				config.Providers = append(config.Providers, codexBarProviderConfig{ID: id, Enabled: true})
			}
		}
		json.NewEncoder(os.Stdout).Encode(config)
	default:
		os.Exit(12)
	}
	os.Exit(0)
}

func TestHelperNormalizesCompleteRegistryAndBlocksUnsafeDefaults(t *testing.T) {
	for _, v := range []struct{ name, key, value string }{
		{"new-registry-provider", "", ""},
		{"unknown-target", "MODELPLAN_TEST_REGISTRY", `["cursor"]`},
		{"empty-registry", "MODELPLAN_TEST_REGISTRY", `[]`},
		{"duplicate", "MODELPLAN_TEST_REGISTRY", `["new-provider","new-provider"]`},
		{"aggregate", "MODELPLAN_TEST_REGISTRY", `["new-provider","all"]`},
		{"late-provider-default", "MODELPLAN_TEST_REGISTRY_EXTRA", "late-provider"},
		{"off-unsupported", "MODELPLAN_TEST_IGNORE_COOKIE_OFF", "new-provider"},
		{"registry-failed", "MODELPLAN_TEST_METADATA_FAIL", "providers"},
		{"dump-failed", "MODELPLAN_TEST_METADATA_FAIL", "dump"},
	} {
		t.Run(v.name, func(t *testing.T) {
			isolateHome(t)
			dir := t.TempDir()
			bin, log := filepath.Join(dir, "helper"), filepath.Join(dir, "usage-started")
			t.Setenv("MODELPLAN_TEST_USAGE_LOG", log)
			script := "#!/bin/sh\n" + fakeConfigMetadata(t) + `printf started > "$MODELPLAN_TEST_USAGE_LOG"
cat "$CODEXBAR_CONFIG"
`
			if err := os.WriteFile(bin, []byte(script), 0700); err != nil {
				t.Fatal(err)
			}
			if v.key != "" {
				t.Setenv(v.key, v.value)
			}
			out, err := runCodexBar(context.Background(), bin, "new-provider", "standard")
			if v.key != "" {
				if err == nil {
					t.Fatal("unsafe normalization accepted", string(out))
				}
				if _, err := os.Stat(log); !os.IsNotExist(err) {
					t.Fatal("usage started before registry/Off validation", err)
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			var config codexBarUsageDocument
			if err := json.Unmarshal(out, &config); err != nil {
				t.Fatal(err)
			}
			if len(config.Providers) != len(fixtureRegistry) {
				t.Fatal("effective normalized registry incomplete", config)
			}
			for _, p := range config.Providers {
				if p.CookieSource != "off" || p.Enabled != (p.ID == "new-provider") {
					t.Fatal("new provider inherited unsafe defaults", p)
				}
			}
		})
	}
}

func TestHelperConsentChangeDuringConfigValidationBlocksUsage(t *testing.T) {
	isolateHome(t)
	dir := t.TempDir()
	bin, started, release, usage := filepath.Join(dir, "helper"), filepath.Join(dir, "dump-started"), filepath.Join(dir, "release"), filepath.Join(dir, "usage")
	t.Setenv("MODELPLAN_TEST_DUMP_STARTED", started)
	t.Setenv("MODELPLAN_TEST_DUMP_RELEASE", release)
	t.Setenv("MODELPLAN_TEST_USAGE_LOG", usage)
	script := `#!/bin/sh
if [ "$1 $2" = 'config dump' ]; then
: > "$MODELPLAN_TEST_DUMP_STARTED"
while [ ! -f "$MODELPLAN_TEST_DUMP_RELEASE" ]; do sleep 0.01; done
fi
` + fakeConfigMetadata(t) + `printf started > "$MODELPLAN_TEST_USAGE_LOG"
`
	if err := os.WriteFile(bin, []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	defer os.WriteFile(release, nil, 0600)
	done := make(chan error, 1)
	go func() { _, err := runCodexBar(ctx, bin, "cursor", "browser-session"); done <- err }()
	for {
		if _, err := os.Stat(started); err == nil {
			break
		}
		if ctx.Err() != nil {
			t.Fatal("normalization did not start")
		}
		time.Sleep(5 * time.Millisecond)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		return consent.Set(s, "cursor", false, "", "", time.Now())
	}); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(release, nil, 0600); err != nil {
		t.Fatal(err)
	}
	if err := <-done; err == nil || !strings.Contains(err.Error(), "consent changed") {
		t.Fatal("revoked helper launched after config normalization", err)
	}
	if _, err := os.Stat(usage); !os.IsNotExist(err) {
		t.Fatal("usage launched despite revocation", err)
	}
}
