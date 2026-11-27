// SPDX-License-Identifier: MIT
//go:build darwin || linux

package toolcli

import (
	"bytes"
	"context"
	"errors"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"
)

// alive: the process exists and is not a zombie waiting for a reaper.
func alive(pid int) bool {
	if syscall.Kill(pid, 0) != nil {
		return false
	}
	if b, err := os.ReadFile("/proc/" + strconv.Itoa(pid) + "/stat"); err == nil {
		if i := bytes.LastIndexByte(b, ')'); i >= 0 && i+2 < len(b) {
			return b[i+2] != 'Z'
		}
		return true
	}
	out, err := exec.Command("/bin/ps", "-o", "stat=", "-p", strconv.Itoa(pid)).Output()
	return err == nil && !strings.HasPrefix(strings.TrimSpace(string(out)), "Z")
}

func waitDead(t *testing.T, pid int) {
	t.Helper()
	for deadline := time.Now().Add(3 * time.Second); time.Now().Before(deadline); time.Sleep(20 * time.Millisecond) {
		if !alive(pid) {
			return
		}
	}
	_ = syscall.Kill(pid, syscall.SIGKILL)
	t.Fatalf("grandchild %d outlived the read", pid)
}

func grandchildPID(t *testing.T, out []byte) int {
	t.Helper()
	pid, err := strconv.Atoi(strings.TrimSpace(strings.SplitN(string(out), "\n", 2)[0]))
	if err != nil || pid <= 0 {
		t.Fatalf("no grandchild pid in %q", out)
	}
	return pid
}

// Owner build-6 #14: a child that leaves a background grandchild behind (a launcher starting an
// IDE or its updater) does not leave it running once the read is over.
func TestRunKillsGrandchildAfterChildExits(t *testing.T) {
	cmd, err := Command(context.Background(), "/bin/sh", "-c", "sleep 60 </dev/null >/dev/null 2>&1 & echo $!")
	if err != nil {
		t.Fatal(err)
	}
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := Run(cmd); err != nil {
		t.Fatalf("run: %v", err)
	}
	waitDead(t, grandchildPID(t, out.Bytes()))
}

// On the read's deadline the whole group stops, including a grandchild that still holds the
// child's stdout, and Wait returns promptly.
func TestDeadlineKillsGrandchildHoldingThePipe(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
	defer cancel()
	cmd, err := Command(ctx, "/bin/sh", "-c", "sleep 60 & echo $!; wait")
	if err != nil {
		t.Fatal(err)
	}
	var out bytes.Buffer
	cmd.Stdout = &out
	start := time.Now()
	err = Run(cmd)
	if err == nil {
		t.Fatal("deadline did not stop the child")
	}
	if took := time.Since(start); took > 3*time.Second {
		t.Fatalf("Wait took %s", took)
	}
	waitDead(t, grandchildPID(t, out.Bytes()))
}

// The pipe-driven readers (Kiro, Copilot, Codex) Start, talk and then KillGroup before Wait.
func TestKillGroupStopsPipeReaderDescendants(t *testing.T) {
	cmd, err := Command(context.Background(), "/bin/sh", "-c", "sleep 60 & echo $!; cat")
	if err != nil {
		t.Fatal(err)
	}
	in, _ := cmd.StdinPipe()
	out, _ := cmd.StdoutPipe()
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	line := make([]byte, 32)
	n, _ := out.Read(line)
	pid := grandchildPID(t, line[:n])
	_ = in.Close()
	KillGroup(cmd)
	err = cmd.Wait()
	var exit *exec.ExitError
	if err != nil && !errors.As(err, &exit) {
		t.Fatalf("wait: %v", err)
	}
	waitDead(t, pid)
	KillGroup(cmd) // a second stop after Wait is harmless
}
