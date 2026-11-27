// SPDX-License-Identifier: MIT
package toolcli

import (
	"context"
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

// Command is the one way ModelPlan starts a tool program. It refuses a program inside another
// app's bundle (ErrInsideAppBundle), and it starts the child in its own process group: a context
// deadline or cancel stops the whole group, so no descendant the child spawned outlives the read.
// Callers stop the group on every other exit too, with KillGroup after Run or Wait.
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
	cmd := exec.CommandContext(ctx, bin, args...)
	ownProcessGroup(cmd)
	cmd.WaitDelay = childWaitDelay
	return cmd, nil
}

// KillGroup stops whatever is left of the child's process group, then the child itself. It is
// safe to call more than once and after Wait: while any member is alive the group id stays
// reserved, so the signal cannot reach an unrelated process.
func KillGroup(cmd *exec.Cmd) {
	if cmd == nil || cmd.Process == nil {
		return
	}
	killProcessGroup(cmd)
}

// Run runs the command and then stops any descendant left in its process group.
func Run(cmd *exec.Cmd) error {
	err := cmd.Run()
	KillGroup(cmd)
	return err
}
