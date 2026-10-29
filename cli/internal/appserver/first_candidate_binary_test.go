// SPDX-License-Identifier: MIT
package appserver

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"runtime"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appcontract"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/plugininstall"
)

func candidateRoot() string {
	_, file, _, _ := runtime.Caller(0)
	return filepath.Clean(filepath.Join(filepath.Dir(file), "../../.."))
}
func candidateBinary(t *testing.T, pkg string) string {
	t.Helper()
	binary := filepath.Join(t.TempDir(), "fixture")
	if err := appcontract.Build(candidateRoot(), binary, pkg); err != nil {
		t.Fatal(err)
	}
	return binary
}
func candidateClient(t *testing.T, bin, home string, args, extraEnv []string) (*pipeClient, *bytes.Buffer) {
	t.Helper()
	stderr := &bytes.Buffer{}
	cmd := exec.Command(bin, append([]string{"app-server"}, args...)...)
	cmd.Env = append([]string{"HOME=" + home, "PATH=" + filepath.Join(home, "bin"), "TMPDIR=" + home, "LANG=C", "MODELPLAN_CACHE=" + filepath.Join(home, "cache")}, extraEnv...)
	cmd.Stderr = stderr
	stdin, err := cmd.StdinPipe()
	if err != nil {
		t.Fatal(err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	c := &pipeClient{in: stdin.(*os.File), out: stdout.(*os.File), done: make(chan struct{})}
	go func() { _ = cmd.Wait(); close(c.done) }()
	t.Cleanup(func() {
		_ = stdin.Close()
		_ = stdout.Close()
		select {
		case <-c.done:
		case <-time.After(2 * time.Second):
			_ = cmd.Process.Kill()
			<-c.done
			t.Error("candidate app-server did not exit")
		}
	})
	return c, stderr
}
func finishCandidate(t *testing.T, c *pipeClient) {
	t.Helper()
	c.send(t, 900, "shutdown", wire.Empty{})
	c.response(t, 900)
	select {
	case <-c.done:
	case <-time.After(2 * time.Second):
		t.Fatal("candidate did not shut down")
	}
}

func TestRealBinaryPluginInstallMatchesStandaloneContract(t *testing.T) {
	bin := candidateBinary(t, "./cmd/modelplan")
	host := candidateBinary(t, "./internal/appcontract/cmd")
	validator, err := appcontract.NewValidator(candidateRoot())
	if err != nil {
		t.Fatal(err)
	}
	for _, tool := range []string{"claude-code", "codex"} {
		for _, test := range []struct {
			mode, status     string
			completed, calls int
			offline          bool
		}{
			{"installed", "installed", 2, 2, false}, {"failed-first", "failed", 0, 1, false}, {"failed-manual-step", "failed", 1, 2, false}, {"instructions", "instructions", 0, 0, false}, {"planned", "planned", 0, 0, true},
		} {
			t.Run(tool+"/"+test.mode, func(t *testing.T) {
				home := t.TempDir()
				binDir := filepath.Join(home, "bin")
				if err := os.MkdirAll(binDir, 0700); err != nil {
					t.Fatal(err)
				}
				hostName := tool
				if hostName == "claude-code" {
					hostName = "claude"
				}
				if test.mode != "instructions" {
					if err := os.Symlink(host, filepath.Join(binDir, hostName)); err != nil {
						t.Fatal(err)
					}
				}
				trace := filepath.Join(home, "plugin-calls.jsonl")
				c, stderr := candidateClient(t, bin, home, nil, []string{"MODELPLAN_CONTRACT_PLUGIN_MODE=" + test.mode, "MODELPLAN_CONTRACT_PLUGIN_CALLS=" + trace})
				c.validate = func(message map[string]json.RawMessage) error {
					raw, _ := json.Marshal(message)
					return validator.Validate("app-server", raw)
				}
				c.initialize(t)
				c.send(t, 2, "plugin/install", map[string]any{"tool": tool, "offline": test.offline})
				response := c.response(t, 2)
				if response["error"] != nil {
					t.Fatalf("plugin/install did not return the standalone result: %s", response["error"])
				}
				var result wire.Envelope[plugininstall.Result]
				if err := json.Unmarshal(response["result"], &result); err != nil {
					t.Fatal(err)
				}
				if result.Data.Tool != tool || result.Data.Status != test.status || result.Data.Completed != test.completed {
					t.Fatalf("wrong install result: %+v", result.Data)
				}
				raw, _ := json.Marshal(result.Data)
				if err := validator.Validate("plugin-install", raw); err != nil {
					t.Fatal(err)
				}
				calls := [][]string{}
				traceBytes, err := os.ReadFile(trace)
				if err != nil && !os.IsNotExist(err) {
					t.Fatal(err)
				}
				for _, line := range bytes.Split(bytes.TrimSpace(traceBytes), []byte{'\n'}) {
					if len(line) == 0 {
						continue
					}
					var argv []string
					if err := json.Unmarshal(line, &argv); err != nil {
						t.Fatal(err)
					}
					calls = append(calls, argv)
				}
				if len(calls) != test.calls || !reflect.DeepEqual(calls, result.Data.Commands[:test.calls]) {
					t.Fatalf("host calls escaped fixed prefix: %v", calls)
				}
				finishCandidate(t, c)
				if stderr.Len() != 0 {
					t.Fatalf("host output escaped protocol logging: %s", stderr.String())
				}
			})
		}
	}
}

func seedRefreshHome(t *testing.T, home, scope string) {
	t.Helper()
	file := filepath.Join(home, ".config", "modelplan", "consent.json")
	state, err := consent.EnsureStore(file)
	if err != nil {
		t.Fatal(err)
	}
	definition, _ := consent.Definition(scope)
	record := consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion, ReaderID: "native:" + definition.Tool, Backend: "native", At: time.Now().UTC()}
	state.Scopes[scope] = record
	state.Tools[definition.Tool] = record
	state.Generation++
	raw, _ := json.Marshal(state)
	if err := os.WriteFile(file, raw, 0600); err != nil {
		t.Fatal(err)
	}
}
func refreshReply(t *testing.T, c *pipeClient, id int, scope string) []wire.RefreshScheduled {
	t.Helper()
	c.send(t, id, "refresh/request", wire.RefreshRequestParams{Scopes: []string{scope}})
	response := c.response(t, id)
	if response["error"] != nil {
		t.Fatalf("refresh was not a normal scheduled result: %s", response["error"])
	}
	var result wire.Envelope[[]wire.RefreshScheduled]
	if err := json.Unmarshal(response["result"], &result); err != nil {
		t.Fatal(err)
	}
	if len(result.Data) != 1 || result.Data[0].Scope != scope {
		t.Fatalf("wrong scheduled scopes: %+v", result.Data)
	}
	return result.Data
}
func runtimeReadCount(t *testing.T, path string) int {
	t.Helper()
	body, err := os.ReadFile(path)
	if err != nil && !os.IsNotExist(err) {
		t.Fatal(err)
	}
	count := 0
	for _, line := range bytes.Split(bytes.TrimSpace(body), []byte{'\n'}) {
		if len(line) == 0 {
			continue
		}
		var message struct {
			Method string `json:"method"`
		}
		if err := json.Unmarshal(line, &message); err != nil {
			t.Fatal(err)
		}
		if message.Method == "account/rateLimits/read" {
			count++
		}
	}
	return count
}
func TestRealBinaryRefreshSharedBudgetAndDeferrals(t *testing.T) {
	bin := candidateBinary(t, "./cmd/modelplan")
	runtimeHost := candidateBinary(t, "./internal/appserver/testdata/runtime")
	validator, err := appcontract.NewValidator(candidateRoot())
	if err != nil {
		t.Fatal(err)
	}
	for _, test := range []struct {
		name, scope string
		args, env   []string
		budget      bool
		want        wire.RefreshDisabledReason
	}{
		{name: "budget deferral", scope: consent.ScopeCodexRuntimeUsage, budget: true, want: wire.RefreshCooldown},
		{name: "offline", scope: consent.ScopeCodexRuntimeUsage, args: []string{"--offline"}, want: wire.RefreshOffline},
		{name: "read only", scope: consent.ScopeCodexRuntimeUsage, args: []string{"--read-only"}, want: wire.RefreshReadOnly},
		{name: "readers off", scope: consent.ScopeCodexRuntimeUsage, env: []string{"MODELPLAN_READERS=off"}, want: wire.RefreshReadOnly},
		{name: "policy pending", scope: consent.ScopeGeminiAccountUsageSavedLogin, want: wire.RefreshReadOnly},
	} {
		t.Run(test.name, func(t *testing.T) {
			home := t.TempDir()
			seedRefreshHome(t, home, test.scope)
			binDir := filepath.Join(home, "bin")
			if err := os.MkdirAll(binDir, 0700); err != nil {
				t.Fatal(err)
			}
			if err := os.Symlink(runtimeHost, filepath.Join(binDir, "codex")); err != nil {
				t.Fatal(err)
			}
			trace := filepath.Join(home, "runtime.jsonl")
			budgetPath := filepath.Join(home, "cache", "observed", "reader-attempts", "codex.json")
			next := time.Now().Add(19 * time.Minute).UTC()
			if test.budget {
				if err := os.MkdirAll(filepath.Dir(budgetPath), 0700); err != nil {
					t.Fatal(err)
				}
				raw, _ := json.Marshal(map[string]any{"schemaVersion": 1, "nextAttemptAt": next})
				if err := os.WriteFile(budgetPath, raw, 0600); err != nil {
					t.Fatal(err)
				}
			}
			env := append([]string{"MODELPLAN_U3B_RUNTIME_CALLS=" + trace}, test.env...)
			c, stderr := candidateClient(t, bin, home, test.args, env)
			c.validate = func(message map[string]json.RawMessage) error {
				raw, _ := json.Marshal(message)
				return validator.Validate("app-server", raw)
			}
			c.initialize(t)
			reply := refreshReply(t, c, 2, test.scope)
			if reply[0].DisabledReason == nil || *reply[0].DisabledReason != test.want {
				t.Fatalf("wrong deferral: %+v", reply)
			}
			if test.budget && !reply[0].At.Equal(next) {
				t.Fatal("lost shared budget deadline")
			}
			finishCandidate(t, c)
			if runtimeReadCount(t, trace) != 0 {
				t.Fatal("deferred runtime was called")
			}
			if stderr.Len() != 0 {
				t.Fatalf("unexpected protocol stderr: %s", stderr.String())
			}
			if test.scope == consent.ScopeGeminiAccountUsageSavedLogin {
				if _, err := os.Stat(filepath.Join(home, "cache", "observed", "reader-attempts", "gemini.json")); !os.IsNotExist(err) {
					t.Fatal("policy_pending reached budget reservation")
				}
			}
		})
	}
	t.Run("two requests and independent CLI share one read", func(t *testing.T) {
		home := t.TempDir()
		seedRefreshHome(t, home, consent.ScopeCodexRuntimeUsage)
		binDir := filepath.Join(home, "bin")
		if err := os.MkdirAll(binDir, 0700); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(runtimeHost, filepath.Join(binDir, "codex")); err != nil {
			t.Fatal(err)
		}
		trace := filepath.Join(home, "runtime.jsonl")
		env := []string{"MODELPLAN_U3B_RUNTIME_CALLS=" + trace}
		c, stderr := candidateClient(t, bin, home, nil, env)
		c.initialize(t)
		first := refreshReply(t, c, 2, consent.ScopeCodexRuntimeUsage)
		if first[0].DisabledReason != nil {
			t.Fatalf("due refresh not scheduled: %+v", first)
		}
		deadline := time.Now().Add(5 * time.Second)
		for runtimeReadCount(t, trace) == 0 && time.Now().Before(deadline) {
			time.Sleep(5 * time.Millisecond)
		}
		if runtimeReadCount(t, trace) != 1 {
			t.Fatal("first refresh did not make one logical read")
		}
		second := refreshReply(t, c, 3, consent.ScopeCodexRuntimeUsage)
		if second[0].DisabledReason == nil || *second[0].DisabledReason != wire.RefreshCooldown {
			t.Fatalf("second refresh was not deferred: %+v", second)
		}
		command := exec.Command(bin, "quota", "--refresh-account", "--quiet")
		command.Env = append([]string{"HOME=" + home, "PATH=" + binDir, "TMPDIR=" + home, "LANG=C", "MODELPLAN_CACHE=" + filepath.Join(home, "cache")}, env...)
		if output, err := command.CombinedOutput(); err != nil {
			t.Fatalf("independent refresh: %v %s", err, output)
		}
		finishCandidate(t, c)
		if runtimeReadCount(t, trace) != 1 {
			t.Fatal("independent CLI bypassed the shared budget")
		}
		if stderr.Len() != 0 {
			t.Fatalf("unexpected stderr: %s", stderr.String())
		}
	})
}

func TestRealBinaryFirstCandidateRequestInventory(t *testing.T) {
	bin := candidateBinary(t, "./cmd/modelplan")
	home := t.TempDir()
	seedRefreshHome(t, home, consent.ScopeCodexRuntimeUsage)
	c, _ := candidateClient(t, bin, home, nil, nil)
	c.initialize(t)
	for index, test := range []struct {
		method string
		params any
	}{
		{"rows/subscribe", wire.Empty{}}, {"consent/get", wire.Empty{}}, {"consent/grant", wire.ConsentGrantParams{}}, {"credentials/result", wire.CredentialResult{}}, {"refresh/request", wire.RefreshRequestParams{Scopes: []string{consent.ScopeCodexRuntimeUsage}}}, {"plugin/install", map[string]string{"tool": "unsupported"}}, {"diagnostics/get", wire.Empty{}},
	} {
		id := 100 + index
		c.send(t, id, test.method, test.params)
		response := c.response(t, id)
		if response["error"] != nil && errorOf(t, response).Code == wire.CodeMethodNotFound {
			t.Fatalf("first-candidate request not served: %s", test.method)
		}
	}
	finishCandidate(t, c)
}
