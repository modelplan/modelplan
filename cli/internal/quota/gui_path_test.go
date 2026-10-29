// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/toolcli"
)

// The fake node runs synthetic shell fixtures; no installed runtime or account is used.
func makeGUINodeScript(t *testing.T, bin string) {
	t.Helper()
	body, err := os.ReadFile(bin)
	if err != nil {
		t.Fatal(err)
	}
	body = []byte(strings.Replace(string(body), "#!/bin/sh", "#!/usr/bin/env node", 1))
	if err := os.WriteFile(bin, body, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(filepath.Dir(bin), "node"), []byte("#!/bin/sh\nexec /bin/sh \"$@\"\n"), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", "/usr/bin:/bin:/usr/sbin:/sbin")
}

func TestCodexAppServerEnvNodeGUIPath(t *testing.T) {
	isolateHome(t)
	bin, log := fakeCodex(t, acctResponse)
	makeGUINodeScript(t, bin)
	resp, err := askCodex(context.Background(), bin)
	if err != nil || resp.RateLimitResetCredit == nil {
		t.Fatal(resp, err)
	}
	calls, _ := os.ReadFile(log)
	if !strings.Contains(string(calls), "account/rateLimits/read") || strings.Contains(string(calls), "thread/start") {
		t.Fatal(string(calls))
	}
}
func TestCopilotEnvNodeGUIPath(t *testing.T) {
	isolateHome(t)
	bin, _ := fakeCopilot(t)
	makeGUINodeScript(t, bin)
	raw, err := askCopilot(context.Background(), bin)
	if err != nil || len(raw) == 0 {
		t.Fatal(string(raw), err)
	}
}
func TestKiroEnvNodeGUIPath(t *testing.T) {
	isolateHome(t)
	bin, log := fakeKiro(t, kiroUsage)
	makeGUINodeScript(t, bin)
	raw, err := askKiro(context.Background(), bin)
	if err != nil || len(raw) == 0 {
		t.Fatal(string(raw), err)
	}
	calls, _ := os.ReadFile(log)
	if !strings.Contains(string(calls), "_kiro/account/getUsage") {
		t.Fatal(string(calls))
	}
}
func TestAmpEnvNodeKeepsVerifiedDescriptorUnderGUIPath(t *testing.T) {
	if runtime.GOOS != "linux" {
		t.Skip("existing immutable artifact execution is Linux-only")
	}
	isolateHome(t)
	bin := filepath.Join(t.TempDir(), "amp")
	body := []byte("#!/usr/bin/env node\n[ \"$1\" = usage ] && [ \"$2\" = --no-color ] || exit 3\nprintf 'Paid: $10 remaining\\n'\n")
	if err := os.WriteFile(bin, body, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(filepath.Dir(bin), "node"), []byte("#!/bin/sh\n[ \"$1\" = --preserve-symlinks-main ] && shift\nexec /bin/sh \"$@\"\n"), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", "/usr/bin:/bin:/usr/sbin:/sbin")
	sum := sha256.Sum256(body)
	artifact, err := ampVerifiedArtifact(bin, hex.EncodeToString(sum[:]))
	if err != nil {
		t.Fatal(err)
	}
	defer artifact.Close()
	// Replacing the installed script cannot change the verified bytes executed.
	if err := os.WriteFile(bin, []byte("#!/usr/bin/env node\nprintf unaudited\n"), 0700); err != nil {
		t.Fatal(err)
	}
	ctx := context.WithValue(context.Background(), ampArtifactKey{}, artifact)
	out, err := runAmpUsage(ctx, bin)
	if err != nil || string(out) != "Paid: $10 remaining\n" {
		t.Fatal(string(out), err)
	}
}
func TestToolFindersUseUserPackageBinsUnderGUIPath(t *testing.T) {
	isolateHome(t)
	t.Setenv("PATH", "/usr/bin:/bin:/usr/sbin:/sbin")
	home := os.Getenv("HOME")
	for _, tc := range []struct {
		name, env, dir string
		find           func() string
	}{{"codex", "MODELPLAN_CODEX", ".npm-global/bin", func() string { return CodexBin(home) }}, {"copilot", "MODELPLAN_COPILOT", ".volta/bin", copilotBin}, {"amp", "MODELPLAN_AMP", ".bun/bin", ampBin}, {"kiro-cli", "MODELPLAN_KIRO", ".npm-global/bin", kiroBin}} {
		t.Setenv(tc.env, "")
		bin := filepath.Join(home, tc.dir, tc.name)
		if err := os.MkdirAll(filepath.Dir(bin), 0700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(bin, []byte("#!/bin/sh\nexit 0\n"), 0700); err != nil {
			t.Fatal(err)
		}
		if got := tc.find(); got != bin {
			t.Fatalf("%s=%s want %s", tc.name, got, bin)
		}
	}
}
func TestCodexRuntimeMissingReachesReport(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	now := time.Now().UTC()
	if err := save(cache, &accountSnap{SchemaVersion: 1, ObservedAt: now, Status: toolcli.RuntimeMissing, Error: toolcli.RuntimeNextStep}); err != nil {
		t.Fatal(err)
	}
	r := Report{}
	applyAccount(&r, cache, now)
	if len(r.Accounts) != 0 || len(r.Sources) != 1 || r.Sources[0].Status != toolcli.RuntimeMissing || r.Sources[0].Reason != toolcli.RuntimeNextStep {
		t.Fatalf("%+v", r)
	}
	if diagnosticState(toolcli.RuntimeMissing) != "unavailable:"+toolcli.RuntimeMissing {
		t.Fatal("runtime reason lost in doctor diagnostics")
	}
}

func TestAmpVerifiedScriptWithRealNode(t *testing.T) {
	if runtime.GOOS != "linux" {
		t.Skip("existing immutable execution gate")
	}
	node, err := exec.LookPath("node")
	if err != nil {
		t.Skip("Node runtime unavailable")
	}
	isolateHome(t)
	bin := filepath.Join(t.TempDir(), "amp")
	body := []byte("#!/usr/bin/env node\nconsole.log('Paid: $10 remaining');\n")
	if err := os.WriteFile(bin, body, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(node, filepath.Join(filepath.Dir(bin), "node")); err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(body)
	artifact, err := ampVerifiedArtifact(bin, hex.EncodeToString(sum[:]))
	if err != nil {
		t.Fatal(err)
	}
	defer artifact.Close()
	t.Setenv("PATH", "/usr/bin:/bin:/usr/sbin:/sbin")
	out, err := runAmpUsage(context.WithValue(context.Background(), ampArtifactKey{}, artifact), bin)
	if err != nil || string(out) != "Paid: $10 remaining\n" {
		t.Fatal(string(out), err)
	}
}

func TestCopilotRuntimeMissingSurvivesNativeCacheAndDoctor(t *testing.T) {
	isolateHome(t)
	p := nativePaths(t)
	at := time.Now().UTC()
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "copilot", Backend: BackendNative, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	s := copilotState{SchemaVersion: 1, Availability: toolcli.RuntimeMissing, AttemptAt: at, NextAt: at.Add(time.Hour)}
	if !saveCopilotState(p.Cache, s) {
		t.Fatal("seed synthetic failure")
	}
	if r := ReadCopilotCache(context.Background(), p.Cache, at); r.Availability != toolcli.RuntimeMissing || r.NextStep != toolcli.RuntimeNextStep {
		t.Fatalf("cache=%+v", r)
	}
	if err := RefreshNative(context.Background(), p, at); err != nil {
		t.Fatal(err)
	}
	found := false
	for _, s := range Read(p, at).Sources {
		if s.Source == "native:copilot" {
			found = true
			if s.Status != toolcli.RuntimeMissing || s.Reason != toolcli.RuntimeNextStep {
				t.Fatalf("source=%+v", s)
			}
		}
	}
	if !found {
		t.Fatal("missing native source")
	}
	for _, d := range ReaderDiagnostics(p, at) {
		if d.Provider == "copilot" {
			if d.State != "unavailable:"+toolcli.RuntimeMissing {
				t.Fatalf("doctor=%+v", d)
			}
			return
		}
	}
	t.Fatal("missing Copilot doctor row")
}
