// SPDX-License-Identifier: MIT
package quota

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
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
// Discovery runs programs (`--version`), so it only runs once a read is admitted and due
// (refreshCodexAccount), never while the reader is off.

// codexCLI is what doctor shows about the CLI a read ran: where it came from and its version. No
// path: a folder name can be an account name (review macrevb-1316-1).
type codexCLI struct {
	Source  string `json:"source,omitempty"` // override | app | homebrew | npm | path
	Version string `json:"version,omitempty"`
}

// codexAppPaths: the desktop apps' CLIs in order (a test seam).
var codexAppPaths = toolcli.CodexAppPaths

// codexMemo remembers, across CLI processes (codex-cli.json in the cache), each binary's version
// answer and the working fallback for the desktop app's CLI. Binaries are keyed by a hash of their
// path, so the file holds no path.
type codexMemo struct {
	SchemaVersion int                          `json:"schemaVersion"`
	Versions      map[string]codexVersionProbe `json:"versions,omitempty"`
	Pin           *codexPinRecord              `json:"pin,omitempty"`
	cache         string
}

type codexVersionProbe struct {
	Key     string    `json:"key"`               // the file's mtime and size when it was asked
	Version string    `json:"version,omitempty"` // "" when it did not answer with a version
	At      time.Time `json:"at"`
}

// codexPinRecord (D487 addendum): the app CLI (App) failed the protocol at AppKey (file and
// version) and Alt worked; Alt is used until the app's CLI changes.
type codexPinRecord struct {
	App    string `json:"app"`
	AppKey string `json:"appKey"`
	Alt    string `json:"alt"`
}

// codexMemory is the memo of a caller without a cache folder (this process only).
var codexMemory = struct {
	sync.Mutex
	memo *codexMemo
}{}

const codexMemoFile = "codex-cli.json"

func codexMemoPath(cache string) string { return filepath.Join(cache, "observed", codexMemoFile) }

// codexMemoLoad reads the memo; a missing or unreadable file is an empty memo.
func codexMemoLoad(cache string) *codexMemo {
	if cache == "" {
		codexMemory.Lock()
		defer codexMemory.Unlock()
		if codexMemory.memo == nil {
			codexMemory.memo = &codexMemo{SchemaVersion: 1}
		}
		return codexMemory.memo
	}
	m := &codexMemo{}
	if b, status := readBounded(codexMemoPath(cache), 64<<10); status == "" {
		_ = json.Unmarshal(b, m)
	}
	if m.SchemaVersion != 1 {
		m = &codexMemo{SchemaVersion: 1}
	}
	m.cache = cache
	return m
}

// save writes the memo (0600, atomically); best effort.
func (m *codexMemo) save() {
	if m.cache == "" {
		return
	}
	if len(m.Versions) > codexVersionsMax {
		m.Versions = nil
	}
	b, err := json.Marshal(m)
	if err != nil || os.MkdirAll(filepath.Dir(codexMemoPath(m.cache)), 0o700) != nil {
		return
	}
	_ = writeAtomic(codexMemoPath(m.cache), b)
}

func codexPathKey(p string) string {
	sum := sha256.Sum256([]byte(filepath.Clean(p)))
	return hex.EncodeToString(sum[:16])
}

// codexChoice is the codex a read runs and its source: the first of codexOrder, unless the desktop
// app's CLI failed the protocol and another copy worked (the memo's pin).
func codexChoice(m *codexMemo, home string) (string, string) {
	order, override := codexOrder(m, home)
	if len(order) == 0 {
		return "", ""
	}
	if override {
		return order[0], "override"
	}
	if alt := m.pinned(order); alt != "" {
		return alt, codexSource(alt)
	}
	return order[0], codexSource(order[0])
}

func codexOverride() string {
	for _, env := range []string{"MODELPLAN_CODEX", "CODEX_CLI_PATH"} {
		if p := os.Getenv(env); p != "" {
			return p
		}
	}
	return ""
}

// codexOrder lists the codex binaries a read may run, best first: an explicit path alone; else the
// desktop apps' CLIs that answer --version, then the installed copies (the newest-rule pick first,
// then the rest in lookup order). override reports the explicit path.
func codexOrder(m *codexMemo, home string) (order []string, override bool) {
	if p := codexOverride(); p != "" {
		return []string{p}, true
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
		if m.versionAt(p, now) != "" {
			order = append(order, p)
		}
	}
	if best := newestCodex(m, home, exe); best != "" {
		order = append(order, best)
		for _, c := range codexCandidates(home, exe) {
			if c != best {
				order = append(order, c)
			}
		}
	}
	m.save()
	return order, false
}

// codexProtocolError marks a read that failed in the protocol itself (an unknown method or params,
// an answer this CLI cannot decode), not at the provider or the sign-in.
type codexProtocolError struct{ error }

func (e codexProtocolError) Unwrap() error { return e.error }

func (m *codexMemo) appKey(p string) string {
	return codexFileKey(p) + "|" + m.versionAt(p, codexClock())
}

// pinned is the remembered working copy while it still applies to the first app CLI in order.
func (m *codexMemo) pinned(order []string) string {
	if m.Pin == nil {
		return ""
	}
	if len(order) == 0 || codexPathKey(order[0]) != m.Pin.App || m.appKey(order[0]) != m.Pin.AppKey {
		m.Pin = nil
		m.save()
		return ""
	}
	for _, p := range order[1:] {
		if codexPathKey(p) == m.Pin.Alt {
			return p
		}
	}
	return ""
}

// codexFallbackRead tries, once, the next binary after failed in codexOrder, when failed was
// chosen by discovery (an explicit path or a binary from elsewhere has no fallback). A working
// fallback for the desktop app's CLI is remembered in the memo.
func codexFallbackRead(ctx context.Context, cache, failed string) (string, *rlResponse) {
	if codexOverride() != "" || ctx.Err() != nil {
		return "", nil
	}
	home, _ := os.UserHomeDir()
	m := codexMemoLoad(cache)
	order, _ := codexOrder(m, home)
	next := ""
	for i, p := range order {
		if p == failed && i+1 < len(order) {
			next = order[i+1]
			break
		}
	}
	if next == "" {
		return "", nil
	}
	resp, err := askCodex(ctx, next)
	if err != nil {
		return "", nil
	}
	if codexSource(failed) == "app" {
		m.Pin = &codexPinRecord{App: codexPathKey(failed), AppKey: m.appKey(failed), Alt: codexPathKey(next)}
		m.save()
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
	return "path"
}

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
func newestCodex(m *codexMemo, home, exe string) string {
	candidates := codexCandidates(home, exe)
	if len(candidates) == 0 {
		return ""
	}
	now := codexClock()
	best, bestVersion := candidates[0], m.versionAt(candidates[0], now)
	if bestVersion == "" {
		return best
	}
	for _, c := range candidates[1:] {
		v := m.versionAt(c, now)
		if v != "" && codexNewer(v, bestVersion) {
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

// versionAt is the binary's version, asked at most once a minute and again only after it changed.
func (m *codexMemo) versionAt(p string, now time.Time) string {
	key, id := codexFileKey(p), codexPathKey(p)
	if m.cache == "" {
		codexMemory.Lock()
		defer codexMemory.Unlock()
	}
	probe, seen := m.Versions[id]
	if seen && (probe.Key == key || !now.Before(probe.At) && now.Sub(probe.At) < codexVersionEvery) {
		return probe.Version
	}
	v := askCodexVersion(p)
	if m.Versions == nil {
		m.Versions = map[string]codexVersionProbe{}
	}
	m.Versions[id] = codexVersionProbe{Key: key, Version: v, At: now.UTC()}
	return v
}

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

// codexNewer: a has higher semantic-version precedence than b (semver 2.0.0 section 11): the core
// numbers first; a release outranks its own prereleases; prerelease identifiers compare left to
// right, numeric ones numerically and below alphanumeric ones, and a longer list wins a tie.
func codexNewer(a, b string) bool { return codexCompare(a, b) > 0 }

func codexCompare(a, b string) int {
	ca, pa, _ := strings.Cut(a, "-")
	cb, pb, _ := strings.Cut(b, "-")
	na, nb := strings.SplitN(ca, ".", 3), strings.SplitN(cb, ".", 3)
	for i := 0; i < 3; i++ {
		x, y := 0, 0
		if i < len(na) {
			x, _ = strconv.Atoi(na[i])
		}
		if i < len(nb) {
			y, _ = strconv.Atoi(nb[i])
		}
		if x != y {
			return cmpInt(x, y)
		}
	}
	switch {
	case pa == "" && pb == "":
		return 0
	case pa == "":
		return 1
	case pb == "":
		return -1
	}
	ia, ib := strings.Split(pa, "."), strings.Split(pb, ".")
	for i := 0; i < len(ia) && i < len(ib); i++ {
		x, xErr := strconv.Atoi(ia[i])
		y, yErr := strconv.Atoi(ib[i])
		switch {
		case xErr == nil && yErr == nil:
			if x != y {
				return cmpInt(x, y)
			}
		case xErr == nil:
			return -1
		case yErr == nil:
			return 1
		case ia[i] != ib[i]:
			if ia[i] > ib[i] {
				return 1
			}
			return -1
		}
	}
	return cmpInt(len(ia), len(ib))
}

func cmpInt(x, y int) int {
	switch {
	case x > y:
		return 1
	case x < y:
		return -1
	}
	return 0
}

// codexCLIInfo describes the binary a read ran, for doctor: its source and version only.
func codexCLIInfo(cache, codex string) *codexCLI {
	if codex == "" {
		return nil
	}
	m := codexMemoLoad(cache)
	source := codexSource(codex)
	if codexOverride() == codex {
		source = "override"
	}
	info := &codexCLI{Source: source, Version: m.versionAt(codex, codexClock())}
	m.save()
	return info
}
