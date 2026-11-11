package quota

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"testing"
	"time"
)

// A launcher whose descendant inherits stdout and outlives the launcher must not hold the
// refresh worker past its deadline (audit C, P1).
func TestCodexTimeoutBoundsDescendantHoldingStdout(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("process groups are unix only")
	}
	cases := map[string]string{
		// The descendant stays in the launcher's process group and ignores SIGTERM.
		"group": "#!/bin/sh\ntrap '' TERM\nsleep 20 &\nwait\n",
	}
	if _, err := exec.LookPath("setsid"); err == nil {
		// The descendant leaves the process group: only closing the pipe frees the reader.
		cases["session"] = "#!/bin/sh\ntrap '' TERM\nsetsid sleep 8 &\nwait\n"
	}
	for name, script := range cases {
		t.Run(name, func(t *testing.T) {
			isolateHome(t)
			defer captureReaderReasonLogs(t)()
			cache := t.TempDir()
			bin := filepath.Join(t.TempDir(), "runtime")
			if err := os.WriteFile(bin, []byte(script), 0700); err != nil {
				t.Fatal(err)
			}
			ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
			defer cancel()
			done := make(chan error, 1)
			start := time.Now()
			go func() { done <- RefreshCodexAccount(ctx, cache, bin, acctNow) }()
			select {
			case err := <-done:
				if errorCode(err) != "timeout" {
					t.Fatalf("err = %v, want timeout", err)
				}
				if d := time.Since(start); d > 4*time.Second {
					t.Fatalf("refresh took %v", d)
				}
			case <-time.After(5 * time.Second):
				t.Fatal("refresh worker blocked by a descendant holding stdout")
			}
		})
	}
}
