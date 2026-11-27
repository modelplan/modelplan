// SPDX-License-Identifier: MIT
package toolcli

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// ErrInsideAppBundle: the program lives inside another application's bundle. ModelPlan never runs
// it: whatever that program writes into its own bundle (a self-update, an Electron updater) is
// charged to ModelPlan by macOS App Management ("update or delete other apps", owner build-6 #14).
var ErrInsideAppBundle = errors.New("inside_app_bundle: ModelPlan does not run programs inside other apps; install the standalone CLI")

// childWaitDelay bounds Wait once the child has exited or been stopped, for a descendant that
// still holds its pipes.
const childWaitDelay = time.Second

// asciiLower lowers ASCII letters only, so byte offsets stay valid (macOS volumes are usually
// case-insensitive: "Foo.APP/contents/" names the same bundle).
func asciiLower(s string) string {
	b := []byte(s)
	for i, c := range b {
		if 'A' <= c && c <= 'Z' {
			b[i] = c + 'a' - 'A'
		}
	}
	return string(b)
}

// bundleRoot: the outermost "<name>.app" a path lies inside ("…/X.app/Contents/…"), "" when none.
func bundleRoot(p string) string {
	s := filepath.ToSlash(filepath.Clean(p)) + "/"
	i := strings.Index(asciiLower(s), ".app/contents/")
	if i < 0 {
		return ""
	}
	return asciiLower(s[:i+len(".app")])
}

// ownBundle: the bundle this process itself runs from (the Mac app's engine helper), "" for a
// standalone CLI. Re-running ModelPlan's own binaries is not running another app.
var ownBundle = sync.OnceValue(func() string {
	exe, err := os.Executable()
	if err != nil {
		return ""
	}
	if real, err := filepath.EvalSymlinks(exe); err == nil {
		exe = real
	}
	return bundleRoot(exe)
})

func otherBundle(p string) bool {
	root := bundleRoot(p)
	return root != "" && root != ownBundle()
}

// InsideOtherApp reports a path that is, as spelled or after following symlinks, inside an
// application bundle other than ModelPlan's own. Such a program is never executed.
func InsideOtherApp(p string) bool {
	if p == "" {
		return false
	}
	if otherBundle(p) {
		return true
	}
	if real, err := filepath.EvalSymlinks(p); err == nil && otherBundle(real) {
		return true
	}
	return false
}

// runTag names the environment variable that marks every process a tool run started. Descendants
// inherit it even when they leave the process group (setsid, a daemonizing launcher), so cleanup
// can still find and stop them (review macrev2-1284-3).
const runTag = "MODELPLAN_TOOL_RUN"

// runTags: the tag of each command Command made, until Finish or Run cleans it up.
var runTags sync.Map

// Command is the one way ModelPlan starts a tool program. It refuses a program inside another
// app's bundle (ErrInsideAppBundle). The child runs in its own process group and carries a
// per-run tag in its environment: a deadline or cancel stops the group and every tagged
// descendant, so nothing the child spawned outlives the read. Start it with Start or Run, and end
// it with Run or Finish.
func Command(ctx context.Context, bin string, args ...string) (*exec.Cmd, error) {
	resolved := bin
	if !strings.ContainsRune(bin, filepath.Separator) && !strings.ContainsRune(bin, '/') {
		// A bare name runs what PATH resolves it to; check that file, not the name.
		if p, err := exec.LookPath(bin); err == nil {
			resolved = p
		}
	}
	if InsideOtherApp(resolved) {
		return nil, ErrInsideAppBundle
	}
	tag := make([]byte, 16)
	if _, err := rand.Read(tag); err != nil {
		return nil, err
	}
	cmd := exec.CommandContext(ctx, bin, args...)
	runTags.Store(cmd, hex.EncodeToString(tag))
	ownProcessGroup(cmd)
	cmd.Cancel = func() error { KillGroup(cmd); return nil }
	cmd.WaitDelay = childWaitDelay
	return cmd, nil
}

func tagOf(cmd *exec.Cmd) string {
	if v, ok := runTags.Load(cmd); ok {
		return v.(string)
	}
	return ""
}

// Start starts a command from Command with its run tag added to the environment the caller set.
func Start(cmd *exec.Cmd) error {
	if tag := tagOf(cmd); tag != "" {
		env := cmd.Env
		if env == nil {
			env = os.Environ()
		}
		cmd.Env = append(append([]string(nil), env...), runTag+"="+tag)
	}
	return cmd.Start()
}

// KillGroup stops whatever is left of the child's process group, the child itself, and every
// process carrying the run's tag (descendants that left the group). It is safe to call more than
// once. After Wait the group is no longer signalled (its id may have been recycled); the tag
// still finds every descendant, in the group or not.
func KillGroup(cmd *exec.Cmd) {
	if cmd == nil || cmd.Process == nil {
		return
	}
	if cmd.ProcessState == nil {
		killProcessGroup(cmd)
	}
	if tag := tagOf(cmd); tag != "" {
		killTagged(runTag + "=" + tag)
	}
}

// Finish ends a command started with Start: it stops everything the run started, waits for the
// child and sweeps once more for a descendant started meanwhile.
func Finish(cmd *exec.Cmd) error {
	KillGroup(cmd)
	err := cmd.Wait()
	KillGroup(cmd)
	runTags.Delete(cmd)
	return err
}

// Run runs the command and then stops anything it left behind.
func Run(cmd *exec.Cmd) error {
	if err := Start(cmd); err != nil {
		runTags.Delete(cmd)
		return err
	}
	err := cmd.Wait()
	KillGroup(cmd)
	runTags.Delete(cmd)
	return err
}
