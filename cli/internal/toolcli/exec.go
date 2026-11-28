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

// CodexAppPaths are the signed Codex CLIs the ChatGPT and Codex desktop apps carry, in CodexBar's
// order (a26ca57b5 Sources/CodexBarCore/PathEnvironment.swift:185-197): the user's Applications
// folder first, then the system one. Owner decision D487 (2026-11-28): these exact files are the one
// exception to the bundle rule below, because the desktop app keeps its CLI current while an npm or
// Homebrew copy does not update itself.
func CodexAppPaths(home string) []string {
	var out []string
	for _, apps := range []string{filepath.Join(home, "Applications"), "/Applications"} {
		if apps == "Applications" {
			continue // no home folder
		}
		out = append(out,
			filepath.Join(apps, "ChatGPT.app", "Contents", "Resources", "codex"),
			filepath.Join(apps, "ChatGPT.app", "Contents", "Resources", "codex-cli", "bin", "codex"),
			filepath.Join(apps, "Codex.app", "Contents", "Resources", "codex"))
	}
	return out
}

// codexAppAllowed: p is, as spelled, exactly one of CodexAppPaths, and the file it names stays
// inside that same bundle. Nothing else inside another app is ever run.
func codexAppAllowed(p string) bool {
	if p == "" || !filepath.IsAbs(p) || filepath.Clean(p) != p {
		return false
	}
	home, _ := os.UserHomeDir()
	for _, allowed := range CodexAppPaths(home) {
		if p != allowed {
			continue
		}
		real, err := filepath.EvalSymlinks(p)
		return err == nil && bundleRoot(real) == bundleRoot(p)
	}
	return false
}

// InsideOtherApp reports a path that is, as spelled or after following symlinks, inside an
// application bundle other than ModelPlan's own. Such a program is never executed, except the
// desktop apps' own Codex CLI at its exact place (CodexAppPaths, owner decision D487).
func InsideOtherApp(p string) bool {
	if p == "" || codexAppAllowed(p) {
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

// runState is one tool run: its tag, and whether its child may be reaped. The process group is
// signalled only while reaping is false, under mu, and Run/Finish set reaping under mu before
// Wait reaps the child. An unreaped child (running or a zombie) keeps its process-group id
// reserved, so a group signal can never reach a recycled group (macrev2-1284-6).
type runState struct {
	tag     string
	mu      sync.Mutex
	reaping bool
}

// runs: the state of each command Command made, until Run or Finish cleans it up.
var runs sync.Map

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
	runs.Store(cmd, &runState{tag: hex.EncodeToString(tag)})
	ownProcessGroup(cmd)
	cmd.Cancel = func() error { KillGroup(cmd); return nil }
	cmd.WaitDelay = childWaitDelay
	return cmd, nil
}

func stateOf(cmd *exec.Cmd) *runState {
	if v, ok := runs.Load(cmd); ok {
		return v.(*runState)
	}
	return nil
}

// Start starts a command from Command with its run tag added to the environment the caller set.
func Start(cmd *exec.Cmd) error {
	if st := stateOf(cmd); st != nil {
		env := cmd.Env
		if env == nil {
			env = os.Environ()
		}
		cmd.Env = append(append([]string(nil), env...), runTag+"="+st.tag)
	}
	return cmd.Start()
}

// KillGroup stops the child, its process group while the child is not reaped, and every process
// carrying the run's tag (descendants that left the group). It is safe to call more than once and
// at any time: once the child may be reaped the group is not signalled again.
func KillGroup(cmd *exec.Cmd) {
	if cmd == nil || cmd.Process == nil {
		return
	}
	st := stateOf(cmd)
	if st == nil {
		_ = cmd.Process.Kill() // not a Command run, or already cleaned up: no group to trust
		return
	}
	st.mu.Lock()
	if !st.reaping {
		killProcessGroup(cmd)
	} else {
		_ = cmd.Process.Kill() // os.Process never signals a reaped child
	}
	st.mu.Unlock()
	killTagged(runTag + "=" + st.tag)
}

// beforeReap stops the group one last time and marks the child reapable, atomically with respect to
// KillGroup.
func beforeReap(cmd *exec.Cmd) *runState {
	st := stateOf(cmd)
	if st == nil {
		return nil
	}
	st.mu.Lock()
	if !st.reaping && cmd.Process != nil {
		killProcessGroup(cmd)
	}
	st.reaping = true
	st.mu.Unlock()
	return st
}

func afterReap(cmd *exec.Cmd, st *runState) {
	if st != nil && st.tag != "" {
		killTagged(runTag + "=" + st.tag)
	}
	runs.Delete(cmd)
}

// Finish ends a command started with Start: it stops everything the run started, waits for the
// child and sweeps once more for a tagged descendant started meanwhile.
func Finish(cmd *exec.Cmd) error {
	st := beforeReap(cmd)
	err := cmd.Wait()
	afterReap(cmd, st)
	return err
}

// Run runs the command and then stops anything it left behind, in its process group or tagged.
// It waits for the child to exit without reaping it (waitExited), stops the group while the
// exited child still holds the group id, and only then reaps it.
func Run(cmd *exec.Cmd) error {
	if err := Start(cmd); err != nil {
		runs.Delete(cmd)
		return err
	}
	if waitExited(cmd.Process.Pid) != nil {
		// No way to wait without reaping on this platform: the group cannot be signalled safely
		// after Wait, so only the tag sweep runs.
		st := stateOf(cmd)
		if st != nil {
			st.mu.Lock()
			st.reaping = true
			st.mu.Unlock()
		}
		err := cmd.Wait()
		afterReap(cmd, st)
		return err
	}
	st := beforeReap(cmd)
	err := cmd.Wait()
	afterReap(cmd, st)
	return err
}
