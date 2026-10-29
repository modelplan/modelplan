// SPDX-License-Identifier: MIT
package appserver

import (
	"bytes"
	"encoding/json"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appcontract"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func TestRealBinaryProtocolLifecycle(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	cliRoot := filepath.Clean(filepath.Join(filepath.Dir(file), "../.."))
	bin := filepath.Join(t.TempDir(), "modelplan")
	build := exec.Command("go", "build", "-trimpath", "-o", bin, "./cmd/modelplan")
	build.Dir = cliRoot
	if output, err := build.CombinedOutput(); err != nil {
		t.Fatalf("build real CLI: %v\n%s", err, output)
	}
	validator, err := appcontract.NewValidator(filepath.Dir(cliRoot))
	if err != nil {
		t.Fatal(err)
	}
	spawn := func(t *testing.T) (*pipeClient, *bytes.Buffer, string) {
		t.Helper()
		home := t.TempDir()
		stderr := &bytes.Buffer{}
		cmd := exec.Command(bin, "app-server")
		cmd.Env = []string{"HOME=" + home, "PATH=/nonexistent", "TMPDIR=" + home, "LANG=C"}
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
		c.validate = func(m map[string]json.RawMessage) error {
			b, _ := json.Marshal(m)
			return validator.Validate("app-server", b)
		}
		go func() { _ = cmd.Wait(); close(c.done) }()
		t.Cleanup(func() {
			_ = stdin.Close()
			_ = stdout.Close()
			select {
			case <-c.done:
			case <-time.After(2 * time.Second):
				_ = cmd.Process.Kill()
				<-c.done
				t.Error("real binary did not exit")
			}
		})
		return c, stderr, home
	}
	t.Run("handshake rows diagnostics shutdown", func(t *testing.T) {
		c, stderr, home := spawn(t)
		c.initialize(t)
		c.send(t, 2, "rows/subscribe", wire.Empty{})
		m := c.response(t, 2)
		var snapshot wire.Envelope[wire.RowsSnapshot]
		if err := json.Unmarshal(m["result"], &snapshot); err != nil {
			t.Fatal(err)
		}
		if snapshot.Data.Projection.RowsSummary.State != rows.SummaryStateReadersOff || len(snapshot.Data.Projection.Rows) != 0 {
			t.Fatal("unavailable U2 backend did not fail closed")
		}
		c.send(t, 3, "diagnostics/get", wire.Empty{})
		m = c.response(t, 3)
		if m["error"] != nil {
			t.Fatal("diagnostics failed")
		}
		// Tokens on another method are refused, never reflected in the error.
		c.send(t, 4, "diagnostics/get", map[string]string{"accessToken": "binary-token-canary"})
		m = c.response(t, 4)
		if errorOf(t, m).Code != wire.CodeInvalidParams {
			t.Fatal("token on wrong method accepted")
		}
		b, _ := json.Marshal(m)
		if bytes.Contains(b, []byte("binary-token-canary")) {
			t.Fatal("token reflected")
		}
		c.send(t, 5, "shutdown", wire.Empty{})
		c.response(t, 5)
		select {
		case <-c.done:
		case <-time.After(time.Second):
			t.Fatal("shutdown did not end real process")
		}
		if stderr.Len() != 0 {
			t.Fatalf("unexpected stderr: %s", stderr.String())
		}
		entries, err := os.ReadDir(home)
		if err != nil {
			t.Fatal(err)
		}
		if len(entries) != 0 {
			t.Fatal("unavailable backend wrote the synthetic home")
		}
	})
	t.Run("major mismatch terminates", func(t *testing.T) {
		c, _, _ := spawn(t)
		c.readMessages()
		c.send(t, 1, "initialize", wire.InitializeParams{SessionID: "s-major", ProtocolVersion: "2.0", AppVersion: "test", Capabilities: []string{}})
		if errorOf(t, c.response(t, 1)).Code != wire.CodeProtocolMismatch {
			t.Fatal("wrong mismatch code")
		}
		select {
		case <-c.done:
		case <-time.After(time.Second):
			t.Fatal("real process stayed alive after protocol mismatch")
		}
	})
	t.Run("oversized frame without terminator", func(t *testing.T) {
		c, _, _ := spawn(t)
		sent := make(chan struct{})
		go func() { defer close(sent); _, _ = io.WriteString(c.in, strings.Repeat("x", wire.MaxFrameBytes+1)) }()
		select {
		case <-c.done:
		case <-time.After(2 * time.Second):
			t.Fatal("real binary waited for newline after frame overflow")
		}
		<-sent
	})
	t.Run("EOF terminates", func(t *testing.T) {
		c, _, _ := spawn(t)
		c.initialize(t)
		_ = c.in.Close()
		select {
		case <-c.done:
		case <-time.After(time.Second):
			t.Fatal("real binary did not end on EOF")
		}
	})
}
