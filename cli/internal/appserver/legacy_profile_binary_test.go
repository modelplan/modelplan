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
	"github.com/modelplan/modelplan/cli/internal/consent"
)

// The real binary on a schema-1 profile shaped like the owner's: a native Gemini allow with
// an expired login is read after start, and doctor reports it and lists Codex.
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
	at := `"consentTextVersion":2,"at":"2026-10-20T00:00:00Z"`
	write(".config/modelplan/consent.json", `{"schemaVersion":1,"privacy":"automatic","generation":3,"tools":{`+
		`"gemini":{"allowed":true,`+at+`,"readerId":"native:gemini","backend":"native"}}}`)
	c, stderr := candidateClient(t, bin, home, nil, []string{"MODELPLAN_CODEX_ACCOUNT=off"})
	c.initialize(t)
	c.send(t, 2, "rows/subscribe", wire.Empty{})
	c.response(t, 2)
	state := filepath.Join(home, "cache", "observed", "readers", "gemini.json")
	deadline := time.Now().Add(90 * time.Second)
	for {
		// The file exists as soon as the attempt is reserved; wait for its recorded result.
		var saved struct {
			Entries []json.RawMessage `json:"entries"`
		}
		if b, err := os.ReadFile(state); err == nil && json.Unmarshal(b, &saved) == nil && len(saved.Entries) > 0 {
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
	if _, ok := seen["codex"]; !ok {
		t.Fatal("doctor readers does not list Codex")
	}
}

// Another process, such as a plugin hook, holding the reader lock past the two-second wait
// must not cost the app ten minutes. No test request follows the automatic one.
func TestReadLostToTheReaderLockRetriesSoon(t *testing.T) {
	bin := candidateBinary(t, "./cmd/modelplan")
	home := t.TempDir()
	t.Setenv("HOME", home)
	for _, dir := range []string{"bin", ".gemini", filepath.Join(".config", "modelplan")} {
		if err := os.MkdirAll(filepath.Join(home, dir), 0o700); err != nil {
			t.Fatal(err)
		}
	}
	login := fmt.Sprintf(`{"access_token":"lock-synthetic-canary","expiry_date":%d}`, time.Now().Add(-time.Hour).UnixMilli())
	if err := os.WriteFile(filepath.Join(home, ".gemini", "oauth_creds.json"), []byte(login), 0o600); err != nil {
		t.Fatal(err)
	}
	record := `{"schemaVersion":1,"privacy":"automatic","generation":3,"tools":{"gemini":{"allowed":true,"consentTextVersion":2,"at":"2026-10-20T00:00:00Z","readerId":"native:gemini","backend":"native"}}}`
	if err := os.WriteFile(consent.Path(), []byte(record), 0o600); err != nil {
		t.Fatal(err)
	}
	release, err := consent.ReaderLock()
	if err != nil {
		t.Fatal(err)
	}
	c, _ := candidateClient(t, bin, home, nil, []string{"MODELPLAN_CODEX_ACCOUNT=off"})
	c.initialize(t)
	c.send(t, 2, "rows/subscribe", wire.Empty{})
	c.response(t, 2)
	time.Sleep(4 * time.Second) // past the two-second lock wait
	release()
	state := filepath.Join(home, "cache", "observed", "readers", "gemini.json")
	deadline := time.Now().Add(90 * time.Second) // one automatic pass is a minute; the failure wait is ten
	for {
		var saved struct {
			Entries []json.RawMessage `json:"entries"`
		}
		if b, err := os.ReadFile(state); err == nil && json.Unmarshal(b, &saved) == nil && len(saved.Entries) > 0 {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("a read lost to the reader lock was not retried soon")
		}
		time.Sleep(100 * time.Millisecond)
	}
	finishCandidate(t, c)
}
