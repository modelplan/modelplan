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
