// SPDX-License-Identifier: MIT
package appserver

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

// The real binary on a schema-1 profile shaped like the owner's: a native Gemini allow with
// an expired login is read after start, a bare GLM allow reaches ZCode's route (its selected
// provider has no key, so nothing is sent), and doctor reports both plus Codex.
func TestLegacySchemaOneProfileReadsThroughAppServer(t *testing.T) {
	bin := candidateBinary(t, "./cmd/modelplan")
	home := t.TempDir()
	write := func(path, body string) {
		t.Helper()
		file := filepath.Join(home, path)
		if err := os.MkdirAll(filepath.Dir(file), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(file, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.MkdirAll(filepath.Join(home, "bin"), 0o700); err != nil {
		t.Fatal(err)
	}
	write(".gemini/oauth_creds.json", fmt.Sprintf(`{"access_token":"legacy-synthetic-canary","expiry_date":%d}`, time.Now().Add(-time.Hour).UnixMilli()))
	write(".zcode/v2/provider_config.json", `{"schemaVersion":1,"config":{"providerConfigRules":{"providerRules":[{"providerId":"glm-plan","templateId":"zai-api","enabled":true,"config":{"access":{"type":"zhipu-coding-plan-api-key","apiKey":""}}}]},"modelConfigRules":{"providerModelRules":[],"manualProviderModelRules":[]},"defaultModelSelection":{"providerId":"glm-plan","modelId":"glm-5"}}}`)
	at := `"consentTextVersion":2,"at":"2026-10-20T00:00:00Z"`
	write(".config/modelplan/consent.json", `{"schemaVersion":1,"privacy":"automatic","generation":3,"tools":{`+
		`"gemini":{"allowed":true,`+at+`,"readerId":"native:gemini","backend":"native"},`+
		`"zai":{"allowed":true,`+at+`,"readerId":"native:zai","backend":"native"}}}`)
	c, stderr := candidateClient(t, bin, home, nil, []string{"MODELPLAN_CODEX_ACCOUNT=off"})
	c.initialize(t)
	c.send(t, 2, "rows/subscribe", wire.Empty{})
	c.response(t, 2)
	state := filepath.Join(home, "cache", "observed", "readers", "gemini.json")
	deadline := time.Now().Add(30 * time.Second)
	for {
		if _, err := os.Stat(state); err == nil {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("the legacy Gemini grant was never read")
		}
		time.Sleep(100 * time.Millisecond)
	}
	finishCandidate(t, c)
	if stderr.Len() != 0 {
		t.Fatalf("unexpected protocol stderr: %s", stderr.String())
	}
	cmd := exec.Command(bin, "doctor", "readers", "--json")
	cmd.Env = []string{"HOME=" + home, "PATH=" + filepath.Join(home, "bin"), "TMPDIR=" + home, "LANG=C", "MODELPLAN_CACHE=" + filepath.Join(home, "cache")}
	out, err := cmd.Output()
	if err != nil {
		t.Fatalf("doctor readers: %v", err)
	}
	var report struct {
		Readers []struct{ Provider, Admitted, State string } `json:"readers"`
	}
	if err := json.Unmarshal(out, &report); err != nil {
		t.Fatal(err)
	}
	seen := map[string]string{}
	for _, row := range report.Readers {
		seen[row.Provider] = row.Admitted + " " + row.State
	}
	if got := seen["gemini"]; got == "" || got == "yes unavailable:not_read" {
		t.Fatalf("gemini after a read = %q", got)
	}
	if got := seen["zai"]; len(got) < 3 || got[:3] != "yes" {
		t.Fatalf("zai on a bare legacy allow = %q", got)
	}
	if _, ok := seen["codex"]; !ok {
		t.Fatal("doctor readers does not list Codex")
	}
}
