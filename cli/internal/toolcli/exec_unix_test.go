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
	if err := Start(cmd); err != nil {
		t.Fatal(err)
	}
	line := make([]byte, 32)
	n, _ := out.Read(line)
	pid := grandchildPID(t, line[:n])
	_ = in.Close()
	err = Finish(cmd)
	var exit *exec.ExitError
	if err != nil && !errors.As(err, &exit) {
		t.Fatalf("wait: %v", err)
	}
	waitDead(t, pid)
	KillGroup(cmd) // a second stop after Wait is harmless
}

// The test binary doubles as the tool for the detached-worker tests: as a "launcher" it starts a
// "worker" in a new session (out of the process group, as a daemonizing launcher does), prints the
// worker's pid and exits or stays; as a "worker" it sleeps.
func TestToolcliHelperProcess(t *testing.T) {
	switch os.Getenv("TOOLCLI_HELPER") {
	case "worker":
		time.Sleep(60 * time.Second)
		os.Exit(0)
	case "launcher", "launcher-stay":
		w := exec.Command(os.Args[0], "-test.run=^TestToolcliHelperProcess$")
		w.Env = append(os.Environ(), "TOOLCLI_HELPER=worker")
		w.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
		if err := w.Start(); err != nil {
			os.Exit(2)
		}
		os.Stdout.WriteString(strconv.Itoa(w.Process.Pid) + "\n")
		if os.Getenv("TOOLCLI_HELPER") == "launcher-stay" {
			time.Sleep(60 * time.Second)
		}
		os.Exit(0)
	}
}

func detachedLauncher(t *testing.T, ctx context.Context, mode string) *exec.Cmd {
	t.Helper()
	cmd, err := Command(ctx, os.Args[0], "-test.run=^TestToolcliHelperProcess$")
	if err != nil {
		t.Fatal(err)
	}
	cmd.Env = append(os.Environ(), "TOOLCLI_HELPER="+mode)
	return cmd
}

// Review macrev2-1284-3: a worker that left the process group (setsid) does not outlive the read,
// when the launcher returns normally and when the read is cancelled.
func TestDetachedWorkerDoesNotOutliveRun(t *testing.T) {
	cmd := detachedLauncher(t, context.Background(), "launcher")
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := Run(cmd); err != nil {
		t.Fatalf("run: %v (%s)", err, out.String())
	}
	waitDead(t, grandchildPID(t, out.Bytes()))
}

func TestDetachedWorkerDoesNotOutliveCancel(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cmd := detachedLauncher(t, ctx, "launcher-stay")
	out, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err := Start(cmd); err != nil {
		t.Fatal(err)
	}
	line := make([]byte, 32)
	n, _ := out.Read(line)
	pid := grandchildPID(t, line[:n])
	cancel()
	_ = Finish(cmd)
	waitDead(t, pid)
}

// The pipe-reader shape (Kiro, Copilot, Codex): Start, talk, Finish.
func TestDetachedWorkerDoesNotOutliveFinish(t *testing.T) {
	cmd := detachedLauncher(t, context.Background(), "launcher")
	out, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err := Start(cmd); err != nil {
		t.Fatal(err)
	}
	line := make([]byte, 32)
	n, _ := out.Read(line)
	pid := grandchildPID(t, line[:n])
	_ = Finish(cmd)
	waitDead(t, pid)
}
