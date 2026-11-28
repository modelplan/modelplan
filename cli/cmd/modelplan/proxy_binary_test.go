// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// A proxy password given in the environment must not reach any output or any file, whatever fails.
func TestProxyPasswordCanaryRealBinary(t *testing.T) {
	const canary = "CANARY-PROXY-PASSWORD-7f3a"
	binary := filepath.Join(t.TempDir(), "modelplan")
	if b, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, b)
	}
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	closed := l.Addr().String()
	l.Close()
	for _, c := range []struct{ name, proxy, class, source string }{
		{"dead proxy", "http://user:" + canary + "@" + closed, "proxy-unreachable", "env"},
		{"malformed proxy", "http://user:" + canary + "%zz@" + closed, "proxy-invalid", "invalid"},
	} {
		t.Run(c.name, func(t *testing.T) {
			testenv.IsolateHome(t)
			home := t.TempDir()
			env := []string{"HOME=" + home, "PATH=" + os.Getenv("PATH"), "MODELPLAN_CACHE=" + filepath.Join(home, "cache"), "XDG_CONFIG_HOME=" + filepath.Join(home, "config"),
				"MODELPLAN_BASE=https://publication.invalid", "MODELPLAN_LANG=en", "HTTPS_PROXY=" + c.proxy, "NO_COLOR=1", "TMPDIR=" + t.TempDir()}
			var seen bytes.Buffer
			run := func(stdin string, args ...string) (string, string) {
				cmd := exec.Command(binary, args...)
				cmd.Env = env
				cmd.Stdin = strings.NewReader(stdin)
				var stdout, stderr bytes.Buffer
				cmd.Stdout, cmd.Stderr = &stdout, &stderr
				done := make(chan error, 1)
				_ = cmd.Start()
				go func() { done <- cmd.Wait() }()
				select {
				case <-done:
				case <-time.After(40 * time.Second):
					_ = cmd.Process.Kill()
					t.Fatalf("%v hung", args)
				}
				seen.Write(stdout.Bytes())
				seen.Write(stderr.Bytes())
				return stdout.String(), stderr.String()
			}
			_, syncErr := run("", "sync", "--force")
			if !strings.Contains(strings.ToLower(syncErr), "proxy") {
				t.Fatalf("no plain reason: %q", syncErr)
			}
			doctor, _ := run("", "doctor")
			var report struct {
				State struct {
					LastError string `json:"lastError"`
				} `json:"state"`
				Proxy struct {
					Source string `json:"source"`
				} `json:"proxy"`
				SyncReason string `json:"syncReason"`
			}
			if err := json.Unmarshal([]byte(doctor), &report); err != nil {
				t.Fatalf("doctor: %v %q", err, doctor)
			}
			if report.State.LastError != c.class || report.Proxy.Source != c.source || report.SyncReason == "" {
				t.Fatalf("doctor: %+v", report)
			}
			share, _ := run("", "doctor", "--share")
			if !strings.Contains(share, `"proxy": "`+c.source+`"`) {
				t.Fatalf("share: %q", share)
			}
			run("", "diagnostics", "--share")
			run("", "desktop", "--json")
			run("", "quota", "--json")
			run("", "app-server")
			if strings.Contains(seen.String(), canary) || strings.Contains(seen.String(), strings.TrimPrefix(c.proxy, "http://")) {
				t.Fatalf("proxy value in output: %s", seen.String())
			}
			// Every file the runs wrote: state.json, the cache, any log.
			if err := filepath.WalkDir(home, func(path string, entry os.DirEntry, err error) error {
				if err != nil || entry.IsDir() {
					return err
				}
				b, err := os.ReadFile(path)
				if err == nil && bytes.Contains(b, []byte(canary)) {
					t.Fatalf("canary in %s", path)
				}
				return nil
			}); err != nil {
				t.Fatal(err)
			}
		})
	}
}
