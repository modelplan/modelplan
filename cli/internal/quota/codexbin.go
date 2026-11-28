// SPDX-License-Identifier: MIT
package quota

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/toolcli"
)

// Owner diagnostics 2026-11-28: an npm Codex CLI from August (0.146.0), first on PATH, could not
// decode the owner's plan; the ChatGPT app carried 0.171. Owner decision D487 sets the order:
//  1. an explicit path: $MODELPLAN_CODEX, or $CODEX_CLI_PATH as CodexBar reads it;
//  2. the CLI the ChatGPT or Codex desktop app carries (toolcli.CodexAppPaths, CodexBar a26ca57b5
//     Sources/CodexBarCore/PathEnvironment.swift:185-197), the first that answers --version. CodexBar
//     keeps PATH first and these as a fallback; D487 inverts that because the desktop app keeps its
//     CLI current while an npm or Homebrew copy does not update itself;
//  3. the newest by `codex --version` among every runnable codex on PATH and in the usual install
//     folders (the places CodexBar and Pulse d34d708 Sources/Pulse/Providers/CodexAppServer.swift:263
//     look; both take the first hit, comparing versions is ours).

// codexCLI is what doctor shows about the CLI a read ran: where it came from, a display path and a version.
type codexCLI struct {
	Source  string `json:"source,omitempty"` // override | app | homebrew | npm | other
	Path    string `json:"path"`
	Version string `json:"version,omitempty"`
}

// codexAppPaths: the desktop apps' CLIs in order (a test seam).
var codexAppPaths = toolcli.CodexAppPaths

// codexChoice is the codex a read runs and its source (codexCLI.Source): the first of codexOrder,
// unless the desktop app's CLI failed the protocol and another copy worked (codexPin).
func codexChoice(home string) (string, string) {
	order, override := codexOrder(home)
	if len(order) == 0 {
		return "", ""
	}
	if override {
		return order[0], "override"
	}
	if alt := codexPinned(order); alt != "" {
		return alt, codexSource(alt)
	}
	return order[0], codexSource(order[0])
}

// codexOrder lists the codex binaries a read may run, best first: an explicit path alone; else the
// desktop apps' CLIs that answer --version, then the installed copies (the newest-rule pick first,
// then the rest in lookup order). override reports the explicit path.
func codexOrder(home string) (order []string, override bool) {
	for _, env := range []string{"MODELPLAN_CODEX", "CODEX_CLI_PATH"} {
		if p := os.Getenv(env); p != "" {
			return []string{p}, true
		}
	}
	exe := "codex"
	if runtime.GOOS == "windows" {
		exe = "codex.exe"
	}
	now := codexClock()
	for _, p := range codexAppPaths(home) {
		info, err := os.Stat(p)
		if err != nil || !info.Mode().IsRegular() || info.Mode()&0o111 == 0 || toolcli.InsideOtherApp(p) {
			continue
		}
		if codexVersionAt(p, now) != "" {
			order = append(order, p)
		}
	}
	if best := newestCodex(home, exe); best != "" {
		order = append(order, best)
		for _, c := range codexCandidates(home, exe) {
			if c != best {
				order = append(order, c)
			}
		}
	}
	return order, false
}

// codexProtocolError marks a read that failed in the protocol itself, not at the provider.
type codexProtocolError struct{ error }

func (e codexProtocolError) Unwrap() error { return e.error }

// codexPin (D487 addendum): the desktop app's CLI failed the protocol and alt worked; alt is used
// until the app's CLI changes (its version or file).
var codexPin = struct {
	sync.Mutex
	app, appKey, alt string
}{}

func codexAppKey(p string) string { return codexFileKey(p) + "|" + codexVersionFor(p) }

// codexPinned is the remembered working copy while it still applies to the first app CLI in order.
func codexPinned(order []string) string {
	codexPin.Lock()
	defer codexPin.Unlock()
	if codexPin.alt == "" {
		return ""
	}
	if len(order) == 0 || order[0] != codexPin.app || codexAppKey(codexPin.app) != codexPin.appKey {
		codexPin.app, codexPin.appKey, codexPin.alt = "", "", ""
		return ""
	}
	for _, p := range order[1:] {
		if p == codexPin.alt {
			return p
		}
	}
	return ""
}

// codexFallbackRead tries, once, the next binary after failed in codexOrder, when failed was
// chosen by discovery (an explicit path or a binary from elsewhere has no fallback). A working
// fallback for the desktop app's CLI is remembered.
func codexFallbackRead(ctx context.Context, failed string) (string, *rlResponse) {
	home, _ := os.UserHomeDir()
	order, override := codexOrder(home)
	if override {
		return "", nil
	}
	next := ""
	for i, p := range order {
		if p == failed && i+1 < len(order) {
			next = order[i+1]
			break
		}
	}
	if next == "" || ctx.Err() != nil {
		return "", nil
	}
	resp, err := askCodex(ctx, next)
	if err != nil {
		return "", nil
	}
	if codexSource(failed) == "app" {
		codexPin.Lock()
		codexPin.app, codexPin.appKey, codexPin.alt = failed, codexAppKey(failed), next
		codexPin.Unlock()
	}
	return next, resp
}

// codexSource names where an installed codex came from, by its path and the file it links to.
func codexSource(p string) string {
	if p == "" {
		return ""
	}
	home, _ := os.UserHomeDir()
	for _, app := range toolcli.CodexAppPaths(home) {
		if p == app {
			return "app"
		}
	}
	spelled := []string{filepath.ToSlash(p)}
	if real, err := filepath.EvalSymlinks(p); err == nil {
		spelled = append(spelled, filepath.ToSlash(real))
	}
	for _, s := range spelled {
		switch {
		case strings.Contains(s, "/node_modules/"), strings.Contains(s, "/.nvm/"), strings.Contains(s, "/.npm-global/"), strings.Contains(s, "/.volta/"):
			return "npm"
		case strings.HasPrefix(s, "/opt/homebrew/"), strings.Contains(s, "/Cellar/"), strings.Contains(s, "/Caskroom/"), strings.HasPrefix(s, "/home/linuxbrew/"):
			return "homebrew"
		}
	}
	return "other"
}

type codexVersionProbe struct {
	key     string // the file's mtime and size when it was asked
	version string // "" when it did not answer with a version
	at      time.Time
}

// codexVersions remembers each binary's answer while the file is unchanged. A changed file is
// asked again, but never more often than codexVersionEvery.
var codexVersions = struct {
	sync.Mutex
	m map[string]codexVersionProbe
}{m: map[string]codexVersionProbe{}}

var codexClock = time.Now

// codexSearchDirs: the usual install folders after PATH (a test seam).
var codexSearchDirs = toolcli.SearchDirs

const (
	codexVersionEvery   = time.Minute
	codexVersionTimeout = 3 * time.Second
	codexVersionsMax    = 64
)

var codexVersionPattern = regexp.MustCompile(`\b(\d{1,6})\.(\d{1,6})\.(\d{1,6})(-[0-9A-Za-z.]{1,32})?`)

// codexCandidates lists every runnable codex in lookup order (PATH, then toolcli.SearchDirs),
// once per real file, skipping copies inside another app's bundle.
func codexCandidates(home, exe string) []string {
	var dirs []string
	for _, d := range filepath.SplitList(os.Getenv("PATH")) {
		if d != "" && filepath.IsAbs(d) {
			dirs = append(dirs, d)
		}
	}
	dirs = append(dirs, codexSearchDirs(home)...)
	seen := map[string]bool{}
	var out []string
	for _, d := range dirs {
		p := filepath.Join(d, exe)
		info, err := os.Stat(p)
		if err != nil || !info.Mode().IsRegular() || info.Mode()&0o111 == 0 || toolcli.InsideOtherApp(p) {
			continue
		}
		real := p
		if r, err := filepath.EvalSymlinks(p); err == nil {
			real = r
		}
		if seen[real] {
			continue
		}
		seen[real] = true
		out = append(out, p)
	}
	return out
}

// newestCodex is the candidate with the newest version. The first one in lookup order stays the
// choice unless it answers with a version and another answers with a newer one: a copy that does
// not answer is never passed over for one that merely does.
func newestCodex(home, exe string) string {
	candidates := codexCandidates(home, exe)
	if len(candidates) == 0 {
		return ""
	}
	now := codexClock()
	best, bestVersion := candidates[0], codexVersionAt(candidates[0], now)
	if bestVersion == "" {
		return best
	}
	for _, c := range candidates[1:] {
		v := codexVersionAt(c, now)
		if v != "" && (bestVersion == "" || codexNewer(v, bestVersion)) {
			best, bestVersion = c, v
		}
	}
	return best
}

func codexFileKey(p string) string {
	info, err := os.Stat(p)
	if err != nil {
		return ""
	}
	return fmt.Sprintf("%d:%d", info.ModTime().UnixNano(), info.Size())
}

// codexVersionAt is the binary's version, asked at most once a minute and again only after it changed.
func codexVersionAt(p string, now time.Time) string {
	key := codexFileKey(p)
	codexVersions.Lock()
	probe, seen := codexVersions.m[p]
	codexVersions.Unlock()
	if seen && (probe.key == key || !now.Before(probe.at) && now.Sub(probe.at) < codexVersionEvery) {
		return probe.version
	}
	v := askCodexVersion(p)
	codexVersions.Lock()
	if len(codexVersions.m) >= codexVersionsMax {
		codexVersions.m = map[string]codexVersionProbe{}
	}
	codexVersions.m[p] = codexVersionProbe{key: key, version: v, at: now}
	codexVersions.Unlock()
	return v
}

// codexVersionFor is the remembered (or newly asked) version of one binary.
func codexVersionFor(p string) string { return codexVersionAt(p, codexClock()) }

// askCodexVersion runs `codex --version` with a short deadline and keeps only the version number.
func askCodexVersion(p string) string {
	ctx, cancel := context.WithTimeout(context.Background(), codexVersionTimeout)
	defer cancel()
	cmd, err := toolcli.CommandContext(ctx, p, "--version")
	if err != nil {
		return ""
	}
	var out bytes.Buffer
	cmd.Stdout = &limitedWriter{w: &out, n: 4096}
	cmd.Stderr = io.Discard
	_ = toolcli.Run(cmd)
	m := codexVersionPattern.FindStringSubmatch(out.String())
	if m == nil {
		return ""
	}
	return m[1] + "." + m[2] + "." + m[3] + m[4]
}

type limitedWriter struct {
	w io.Writer
	n int
}

func (l *limitedWriter) Write(b []byte) (int, error) {
	if l.n > 0 {
		k := min(len(b), l.n)
		_, _ = l.w.Write(b[:k])
		l.n -= k
	}
	return len(b), nil
}

// codexNewer: a is a later version than b; a release is later than its own prerelease.
func codexNewer(a, b string) bool {
	pa, xa := codexVersionParts(a)
	pb, xb := codexVersionParts(b)
	for i := range pa {
		if pa[i] != pb[i] {
			return pa[i] > pb[i]
		}
	}
	if xa == "" || xb == "" {
		return xa == "" && xb != ""
	}
	return xa > xb
}

func codexVersionParts(v string) ([3]int, string) {
	var out [3]int
	core, pre, _ := strings.Cut(v, "-")
	for i, part := range strings.SplitN(core, ".", 3) {
		out[i], _ = strconv.Atoi(part)
	}
	return out, pre
}

// codexCLIInfo describes the binary a read runs, for doctor; nil when there is none.
func codexCLIInfo(codex string) *codexCLI {
	if codex == "" {
		return nil
	}
	home, _ := os.UserHomeDir()
	source := codexSource(codex)
	for _, env := range []string{"MODELPLAN_CODEX", "CODEX_CLI_PATH"} {
		if os.Getenv(env) == codex {
			source = "override"
		}
	}
	return &codexCLI{Source: source, Path: codexDisplayPath(codex, home), Version: codexVersionFor(codex)}
}

var codexDisplaySafe = regexp.MustCompile(`^[A-Za-z0-9._@+/-]{1,200}$`)

// codexSystemDirs are install prefixes that name no person.
var codexSystemDirs = []string{"/Applications/", "/opt/homebrew/", "/usr/local/", "/usr/bin/", "/bin/", "/opt/local/", "/nix/"}

// codexDisplayPath shows a path under the home folder as ~/..., a system install path as is, and
// anything else as "other", so doctor output never carries a user name.
func codexDisplayPath(p, home string) string {
	p = filepath.Clean(p)
	if home != "" {
		if rest, ok := strings.CutPrefix(p, filepath.Clean(home)+string(filepath.Separator)); ok {
			if codexDisplaySafe.MatchString(rest) {
				return "~/" + filepath.ToSlash(rest)
			}
			return "other"
		}
	}
	for _, dir := range codexSystemDirs {
		if strings.HasPrefix(p, dir) && codexDisplaySafe.MatchString(p) {
			return p
		}
	}
	return "other"
}
