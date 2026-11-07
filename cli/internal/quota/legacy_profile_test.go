// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func writeLegacyConsent(t *testing.T, tools string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(consent.Path()), 0o700); err != nil {
		t.Fatal(err)
	}
	body := `{"schemaVersion":1,"privacy":"automatic","generation":3,"tools":{` + tools + `}}`
	if err := os.WriteFile(consent.Path(), []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
}

const legacyAt = `"consentTextVersion":2,"at":"2026-10-20T00:00:00Z"`

// The real profile's shape: a schema-1 bare GLM allow from before ZCode's route. It is not
// a choice of another source, so ZCode's own Coding Plan key is read.
func TestLegacyBareGLMAllowReadsZCode(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	writeZCodeProviders(t, home, zcodeTemplateProvider)
	writeLegacyConsent(t, `"zai":{"allowed":true,`+legacyAt+`,"readerId":"native:zai","backend":"native"}`)
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		_, _ = w.Write([]byte(`{"success":true,"code":200,"data":{"limits":[]}}`))
	}))
	defer server.Close()
	oldClient := nativeClient
	t.Cleanup(func() { nativeClient = oldClient })
	nativeClient = readerFixtureClient(t, server, "api.z.ai", "open.bigmodel.cn")
	p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
	if g, ok := p.ReaderAccessGrant("zai"); !ok || g.ConfigSource == nil || g.ConfigSource.Tool != "zcode" {
		t.Fatalf("legacy GLM allow did not reach ZCode's route: %+v %v", g, ok)
	}
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageAPIKey, now); err != nil {
		t.Fatal(err)
	}
	if calls.Load() != 1 {
		t.Fatalf("quota endpoint calls = %d", calls.Load())
	}
}

// A refusal or a recorded source keeps ZCode's key unread.
func TestLegacyGLMDecisionsKeepZCodeUnread(t *testing.T) {
	for name, record := range map[string]string{
		"refused":  `"allowed":false,` + legacyAt,
		"key":      `"allowed":true,` + legacyAt + `,"readerId":"native:zai","backend":"native","keyEnv":"Z_AI_API_KEY"`,
		"profile":  `"allowed":true,` + legacyAt + `,"readerId":"native:zai","backend":"native","profiles":["claude-code"]`,
		"codexbar": `"allowed":true,` + legacyAt + `,"readerId":"codexbar:zai","backend":"codexbar"`,
	} {
		t.Run(name, func(t *testing.T) {
			isolateHome(t)
			home, _ := os.UserHomeDir()
			writeZCodeProviders(t, home, zcodeTemplateProvider)
			writeLegacyConsent(t, `"zai":{`+record+`}`)
			p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
			if g, ok := p.ReaderAccessGrant("zai"); ok && g.ConfigSource != nil && g.ConfigSource.Tool == "zcode" {
				t.Fatal("ZCode's key was admitted over a recorded decision")
			}
		})
	}
}

// Codex has no native reader but is still listed, with its runtime route.
func TestDoctorReadersListsCodex(t *testing.T) {
	isolateHome(t)
	writeLegacyConsent(t, `"codex":{"allowed":true,`+legacyAt+`}`)
	p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
	for _, row := range ReaderDiagnostics(p, now) {
		if row.Provider == "codex" {
			if row.Admitted != "yes" || row.Consent != "granted" || row.State != "unavailable:not_read" {
				t.Fatalf("codex row = %+v", row)
			}
			return
		}
	}
	t.Fatal("doctor readers does not list Codex")
}
