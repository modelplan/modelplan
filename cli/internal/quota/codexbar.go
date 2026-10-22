package quota

import (
	_ "embed"

	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"
	"time"
)

// CodexBar (github.com/steipete/CodexBar, MIT) reads usage for vendors whose meters sit behind
// their own sign-ins. This client never handles those credentials: CodexBar's CLI finds them
// where the user keeps them (its own config, another CLI's login, browser cookies without
// Keychain prompts in the background) and we only parse its JSON. It runs only for the
// providers the user enabled in ~/.config/modelplan/codexbar.json, one provider per call, in the
// background and at most every 10 minutes. The reading is cached in <cache>/observed/codexbar.json
// without identities, account ids or error text that names local paths.

const (
	// CodexBarEvery: how often a refresh may run CodexBar; when every provider failed, wait longer.
	CodexBarEvery      = 10 * time.Minute
	codexbarRetryAfter = 30 * time.Minute
	codexbarKeep       = 6 * time.Hour
	codexbarTimeout    = 60 * time.Second // per provider; Kiro alone may take 20 s
	codexbarMaxOut     = 1 << 20
	codexbarMaxArchive = 200 << 20
	codexbarMaxFiles   = 800 << 20
	codexbarBase       = "https://github.com/steipete/CodexBar/releases/download"
)

// codexbar-pin.json: the pinned CodexBar CLI release and, per platform, the archive suffix and
// its SHA-256 (from the release's .sha256 files). scripts/pin-codexbar.mjs writes it; the
// codexbar-pin workflow proposes a newer release after checking its JSON still parses.
//
//go:embed codexbar-pin.json
var codexbarPinJSON []byte

var CodexBarVersion, codexbarPin = func() (string, map[string][2]string) {
	var p struct {
		Version string               `json:"version"`
		Assets  map[string][2]string `json:"assets"`
	}
	if err := json.Unmarshal(codexbarPinJSON, &p); err != nil || p.Version == "" {
		panic("codexbar-pin.json: " + fmt.Sprint(err))
	}
	return p.Version, p.Assets
}()

// CodexBarProviders: the CodexBar providers this client reads, and what each needs. CodexBar
// keeps the credential; the setup hint says where it goes.
var CodexBarProviders = map[string]struct{ Name, Needs string }{
	"copilot":    {"GitHub Copilot", "a GitHub token in CodexBar's config: gh auth token | <codexbar> config set-api-key --provider copilot --stdin"},
	"cursor":     {"Cursor", "signed in to cursor.com in the browser, or to the Cursor app; on macOS run `<codexbar> --provider cursor` once in Terminal to allow Keychain access"},
	"zai":        {"Z.ai / GLM Coding Plan", "an API key in CodexBar's config: printf '%s' \"$KEY\" | <codexbar> config set-api-key --provider zai --stdin"},
	"kiro":       {"Kiro", "kiro-cli installed and signed in (kiro-cli login)"},
	"opencodego": {"OpenCode Go", "an OpenCode API key in CodexBar's config (<codexbar> config set-api-key --provider opencodego --stdin), or signed in to opencode.ai; without one CodexBar only estimates from this machine's history, which is not shown"},
}

// CodexBarOff: MODELPLAN_CODEXBAR turns the CodexBar bridge off.
func CodexBarOff() bool { return codexbarOff() }

func codexbarOff() bool {
	v := strings.ToLower(os.Getenv("MODELPLAN_CODEXBAR"))
	return v == "off" || v == "0" || v == "false"
}

// ---- Which providers the user enabled.

type codexbarConfig struct {
	SchemaVersion int      `json:"schemaVersion"`
	Providers     []string `json:"providers"`
}

// CodexBarEnabled: the known providers listed in the config file, sorted; nil when none. Which of
// them CodexBar actually reads is CodexBarActive: connections.json may override them.
func CodexBarEnabled(file string) []string {
	if codexbarOff() {
		return nil
	}
	return legacyCodexBar(file)
}

func legacyCodexBar(file string) []string {
	if file == "" {
		return nil
	}
	b, status := readBounded(file, 16<<10)
	if status != "" {
		return nil
	}
	var c codexbarConfig
	if json.Unmarshal(b, &c) != nil || c.SchemaVersion != 1 {
		return nil
	}
	return knownProviders(c.Providers)
}

func knownProviders(ps []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, p := range ps {
		if _, ok := CodexBarProviders[p]; ok && !seen[p] {
			seen[p] = true
			out = append(out, p)
		}
	}
	sort.Strings(out)
	return out
}

// SetCodexBarEnabled writes the provider list; unknown names are an error.
func SetCodexBarEnabled(file string, providers []string) error {
	for _, p := range providers {
		if _, ok := CodexBarProviders[p]; !ok {
			return fmt.Errorf("unknown provider %q (known: %s)", p, strings.Join(knownProviders(keys(CodexBarProviders)), ", "))
		}
	}
	if err := os.MkdirAll(filepath.Dir(file), 0o700); err != nil {
		return err
	}
	b, _ := json.MarshalIndent(codexbarConfig{SchemaVersion: 1, Providers: nonNilStrings(knownProviders(providers))}, "", "  ")
	return writeAtomic(file, append(b, '\n'))
}

func keys[V any](m map[string]V) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}

func nonNilStrings(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}

// ---- Which CodexBar CLI runs.

func codexbarPinnedDir(cache string) string { return filepath.Join(cache, "codexbar", CodexBarVersion) }

// CodexBarBin: $MODELPLAN_CODEXBAR (a path), the pinned copy this client fetched, else one the
// user installed (PATH, then the usual places; hooks run with a short PATH). Empty when none.
func CodexBarBin(cache, home string) string {
	if p := os.Getenv("MODELPLAN_CODEXBAR"); p != "" && !codexbarOff() {
		return p
	}
	if p := filepath.Join(codexbarPinnedDir(cache), "CodexBarCLI"); executable(p) {
		return p
	}
	for _, name := range []string{"codexbar", "CodexBarCLI"} {
		if p, err := exec.LookPath(name); err == nil {
			return p
		}
		for _, d := range []string{"/opt/homebrew/bin", "/usr/local/bin", filepath.Join(home, ".local", "bin")} {
			if p := filepath.Join(d, name); executable(p) {
				return p
			}
		}
	}
	return ""
}

// CodexBarPinned reports whether the pinned copy is in place.
func CodexBarPinned(cache string) bool {
	return executable(filepath.Join(codexbarPinnedDir(cache), "CodexBarCLI"))
}

func codexbarFetchMark(cache string) string { return filepath.Join(cache, "codexbar", "fetch-result") }

// CodexBarFetchDue: the pinned copy is missing and no fetch was tried in the last 30 minutes.
// A copy the user installed does not make it unnecessary: its provider code may be months
// older than the pinned release, and only the pinned release's output is tested.
func CodexBarFetchDue(cache string, now time.Time) bool {
	if codexbarOff() || os.Getenv("MODELPLAN_CODEXBAR") != "" || cache == "" || CodexBarPinned(cache) {
		return false
	}
	if _, ok := codexbarPin[runtime.GOOS+"/"+runtime.GOARCH]; !ok {
		return false
	}
	fi, err := os.Stat(codexbarFetchMark(cache))
	return err != nil || now.Sub(fi.ModTime()) >= codexbarRetryAfter
}

// CodexBarFetchResult: the last fetch's outcome ("" when none was tried).
func CodexBarFetchResult(cache string) string {
	b, _ := os.ReadFile(codexbarFetchMark(cache))
	return strings.TrimSpace(string(b))
}

func markFetch(cache, result string) {
	_ = os.MkdirAll(filepath.Join(cache, "codexbar"), 0o700)
	_ = writeAtomic(codexbarFetchMark(cache), []byte(CodexBarVersion+" "+result+"\n"))
}

func executable(p string) bool {
	fi, err := os.Stat(p)
	return err == nil && fi.Mode().IsRegular() && fi.Mode()&0o111 != 0
}

// FetchCodexBar downloads the pinned CodexBar CLI for this platform into the cache, checks it
// against the pinned SHA-256 and unpacks it; older pinned versions are removed. base "" is GitHub.
func FetchCodexBar(ctx context.Context, cache, base string) (bin string, err error) {
	markFetch(cache, "started")
	defer func() {
		if err != nil {
			markFetch(cache, "failed: "+short(err.Error()))
		} else {
			markFetch(cache, "ok")
		}
	}()
	pin, ok := codexbarPin[runtime.GOOS+"/"+runtime.GOARCH]
	if !ok {
		return "", fmt.Errorf("no CodexBar CLI build for %s/%s", runtime.GOOS, runtime.GOARCH)
	}
	if base == "" {
		base = codexbarBase
	}
	dest := codexbarPinnedDir(cache)
	if bin := filepath.Join(dest, "CodexBarCLI"); executable(bin) {
		return bin, nil
	}
	name := "CodexBarCLI-v" + CodexBarVersion + "-" + pin[0] + ".tar.gz"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimRight(base, "/")+"/v"+CodexBarVersion+"/"+name, nil)
	if err != nil {
		return "", err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("download failed: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("download failed: HTTP %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, codexbarMaxArchive+1))
	if err != nil {
		return "", fmt.Errorf("download failed: %w", err)
	}
	if len(body) > codexbarMaxArchive {
		return "", errors.New("download failed: archive too large")
	}
	sum := sha256.Sum256(body)
	if got := hex.EncodeToString(sum[:]); got != pin[1] {
		return "", fmt.Errorf("checksum mismatch (got %s); nothing installed", got[:12])
	}
	root := filepath.Join(cache, "codexbar")
	if err := os.MkdirAll(root, 0o700); err != nil {
		return "", err
	}
	tmp, err := os.MkdirTemp(root, ".fetch-")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(tmp)
	if err := untar(body, tmp); err != nil {
		return "", fmt.Errorf("unpack failed: %w", err)
	}
	if !executable(filepath.Join(tmp, "CodexBarCLI")) {
		return "", errors.New("unpack failed: no CodexBarCLI in the archive")
	}
	_ = os.RemoveAll(dest)
	if err := os.Rename(tmp, dest); err != nil {
		return "", err
	}
	if es, err := os.ReadDir(root); err == nil {
		for _, e := range es {
			if e.IsDir() && e.Name() != CodexBarVersion && !strings.HasPrefix(e.Name(), ".") {
				_ = os.RemoveAll(filepath.Join(root, e.Name()))
			}
		}
	}
	return filepath.Join(dest, "CodexBarCLI"), nil
}

// untar unpacks regular files and directories under dir; links and paths leaving dir are skipped.
func untar(archive []byte, dir string) error {
	gz, err := gzip.NewReader(bytes.NewReader(archive))
	if err != nil {
		return err
	}
	tr := tar.NewReader(gz)
	var total int64
	for {
		h, err := tr.Next()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		name := path.Clean(strings.TrimPrefix(h.Name, "./"))
		if name == "." || path.IsAbs(name) || name == ".." || strings.HasPrefix(name, "../") {
			continue
		}
		target := filepath.Join(dir, filepath.FromSlash(name))
		switch h.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(target, 0o755); err != nil {
				return err
			}
		case tar.TypeReg:
			total += h.Size
			if total > codexbarMaxFiles {
				return errors.New("archive contents too large")
			}
			if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
				return err
			}
			f, err := os.OpenFile(target, os.O_CREATE|os.O_EXCL|os.O_WRONLY, os.FileMode(h.Mode)&0o755|0o600)
			if err != nil {
				return err
			}
			_, err = io.Copy(f, io.LimitReader(tr, h.Size))
			if cerr := f.Close(); err == nil {
				err = cerr
			}
			if err != nil {
				return err
			}
		}
	}
}

// ---- The cached reading.

type codexbarEntry struct {
	Provider   string    `json:"provider"`
	Source     string    `json:"source,omitempty"` // CodexBar's: api | web | cli | oauth | local | …
	Status     string    `json:"status"`           // ok | estimated | error
	Error      string    `json:"error,omitempty"`
	Plan       string    `json:"plan,omitempty"`
	ObservedAt time.Time `json:"observedAt"`
	Windows    []Window  `json:"windows,omitempty"`
}

type codexbarSnap struct {
	SchemaVersion int             `json:"schemaVersion"`
	ObservedAt    time.Time       `json:"observedAt"`
	Status        string          `json:"status"` // ok | error (CodexBar could not run at all)
	Error         string          `json:"error,omitempty"`
	Providers     []codexbarEntry `json:"providers,omitempty"`
}

func codexbarPath(cache string) string { return filepath.Join(cache, "observed", "codexbar.json") }

func loadCodexBar(cache string) *codexbarSnap {
	if cache == "" {
		return nil
	}
	b, status := readBounded(codexbarPath(cache), 256<<10)
	if status != "" {
		return nil
	}
	var s codexbarSnap
	if json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 {
		return nil
	}
	return &s
}

// CodexBarDue: providers are enabled and the cached reading is old enough to run CodexBar again.
func CodexBarDue(p Paths, now time.Time) bool {
	enabled := CodexBarActive(p)
	if len(enabled) == 0 || p.Cache == "" {
		return false
	}
	s := loadCodexBar(p.Cache)
	if s == nil {
		return true
	}
	have := map[string]bool{}
	failed := s.Status != "ok"
	if !failed {
		failed = true
		for _, e := range s.Providers {
			have[e.Provider] = true
			if e.Status != "error" {
				failed = false
			}
		}
	}
	for _, e := range enabled {
		if !have[e] && s.Status == "ok" {
			return true // a provider enabled since the last run
		}
	}
	wait := CodexBarEvery
	if failed {
		wait = codexbarRetryAfter
	}
	return now.Sub(s.ObservedAt) >= wait
}

// RefreshCodexBar runs CodexBar once per enabled provider and caches the sanitised reading
// (or why it could not run). One refresh at a time.
func RefreshCodexBar(ctx context.Context, p Paths, bin string, now time.Time) error {
	if codexbarOff() {
		return errors.New("disabled by MODELPLAN_CODEXBAR")
	}
	enabled := CodexBarActive(p)
	if len(enabled) == 0 {
		return errors.New("no CodexBar provider enabled")
	}
	if bin == "" {
		return saveCodexBar(p.Cache, &codexbarSnap{SchemaVersion: 1, ObservedAt: now.UTC(), Status: "error", Error: "CodexBar CLI not found"})
	}
	unlock, ok := lockFile(filepath.Join(p.Cache, "observed", "codexbar.lock"), now, time.Duration(len(enabled)+1)*codexbarTimeout)
	if !ok {
		return errors.New("another refresh is running")
	}
	defer unlock()
	home, _ := os.UserHomeDir()
	s := &codexbarSnap{SchemaVersion: 1, ObservedAt: now.UTC(), Status: "ok", Providers: []codexbarEntry{}}
	for _, prov := range enabled {
		out, err := runCodexBar(ctx, bin, prov)
		e := parseCodexBar(out, prov, home, now)
		if e.Status == "error" && e.Error == "" && err != nil {
			e.Error = clean(err.Error(), home)
		}
		s.Providers = append(s.Providers, e)
	}
	return saveCodexBar(p.Cache, s)
}

func saveCodexBar(cache string, s *codexbarSnap) error {
	p := codexbarPath(cache)
	if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
		return err
	}
	b, _ := json.MarshalIndent(s, "", "  ")
	return writeAtomic(p, append(b, '\n'))
}

func lockFile(p string, now time.Time, stale time.Duration) (func(), bool) {
	_ = os.MkdirAll(filepath.Dir(p), 0o700)
	if fi, err := os.Stat(p); err == nil && now.Sub(fi.ModTime()) > stale {
		_ = os.Remove(p) // left behind by a killed refresh
	}
	f, err := os.OpenFile(p, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		return nil, false
	}
	f.Close()
	return func() { _ = os.Remove(p) }, true
}

// runCodexBar: one provider, JSON only, English text, bounded output. CodexBar exits 1 when the
// provider failed and still prints the JSON, so the exit code is not an error by itself.
func runCodexBar(ctx context.Context, bin, provider string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, codexbarTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, bin, "--provider", provider, "--format", "json", "--json-only")
	cmd.Env = append(os.Environ(), "LANG=en_US.UTF-8", "LC_ALL=en_US.UTF-8")
	cmd.Stdin = nil
	cmd.Stderr = io.Discard
	var out bytes.Buffer
	cmd.Stdout = &limited{w: &out, n: codexbarMaxOut}
	err := cmd.Run()
	if ctx.Err() != nil {
		return out.Bytes(), errors.New("timed out")
	}
	return out.Bytes(), err
}

type limited struct {
	w io.Writer
	n int
}

func (l *limited) Write(p []byte) (int, error) {
	if len(p) > l.n {
		_, _ = l.w.Write(p[:l.n])
		l.n = 0
		return len(p), nil
	}
	l.n -= len(p)
	return l.w.Write(p)
}

// Wire types: the part of CodexBar's CLI JSON (Sources/CodexBarCLI/CLIPayloads.swift) used here.
type cbWindow struct {
	UsedPercent   *float64 `json:"usedPercent"`
	WindowMinutes *int     `json:"windowMinutes"`
	ResetsAt      string   `json:"resetsAt"`
}

type cbPayload struct {
	Provider string `json:"provider"`
	Source   string `json:"source"`
	Error    *struct {
		Kind    string `json:"kind"`
		Message string `json:"message"`
	} `json:"error"`
	Usage *struct {
		Primary   *cbWindow `json:"primary"`
		Secondary *cbWindow `json:"secondary"`
		Tertiary  *cbWindow `json:"tertiary"`
		Extra     []struct {
			ID     string    `json:"id"`
			Title  string    `json:"title"`
			Window *cbWindow `json:"window"`
		} `json:"extraRateWindows"`
		DataConfidence string `json:"dataConfidence"`
		UpdatedAt      string `json:"updatedAt"`
		LoginMethod    string `json:"loginMethod"`
	} `json:"usage"`
	Labels *struct {
		Primary   string `json:"primary"`
		Secondary string `json:"secondary"`
		Tertiary  string `json:"tertiary"`
	} `json:"rateWindowLabels"`
}

// parseCodexBar turns one provider's CLI output into a cache entry. Only the requested
// provider's record counts (CodexBar falls back to its default providers for a name it does
// not know). Identities, account ids and window descriptions are never copied.
func parseCodexBar(out []byte, provider, home string, now time.Time) codexbarEntry {
	e := codexbarEntry{Provider: provider, Status: "error", ObservedAt: now.UTC()}
	var ps []cbPayload
	if err := json.Unmarshal(bytes.TrimSpace(out), &ps); err != nil {
		e.Error = "unreadable CodexBar output"
		return e
	}
	var p *cbPayload
	for i := range ps {
		if ps[i].Provider == provider {
			p = &ps[i]
			break
		}
	}
	if p == nil {
		e.Error = "CodexBar returned no " + provider + " record"
		return e
	}
	e.Source = oneOf(p.Source, "auto", "api", "web", "cli", "oauth", "local")
	if p.Error != nil || p.Usage == nil {
		e.Error = "no usage"
		if p.Error != nil {
			e.Error = clean(p.Error.Message, home)
		}
		return e
	}
	u := p.Usage
	if t := stamp(u.UpdatedAt); t != nil && !t.After(now.Add(5*time.Minute)) {
		e.ObservedAt = t.UTC()
	}
	if u.DataConfidence == "estimated" {
		// e.g. OpenCode Go from local history against fixed denominators: not the account's quota.
		e.Status = "estimated"
		return e
	}
	if m := label(u.LoginMethod); m != "" && !strings.Contains(m, "@") {
		e.Plan = m
	}
	labels := [3]string{}
	if l := p.Labels; l != nil {
		labels = [3]string{label(l.Primary), label(l.Secondary), label(l.Tertiary)}
	}
	for i, w := range []*cbWindow{u.Primary, u.Secondary, u.Tertiary} {
		if x, ok := cbWindowOf(w, labels[i], e.ObservedAt); ok {
			e.Windows = append(e.Windows, x)
		}
	}
	for _, x := range u.Extra {
		name := label(x.Title)
		if name == "" {
			name = label(x.ID)
		}
		if w, ok := cbWindowOf(x.Window, name, e.ObservedAt); ok {
			e.Windows = append(e.Windows, w)
		}
	}
	e.Status = "ok"
	return e
}

func cbWindowOf(w *cbWindow, label string, observed time.Time) (Window, bool) {
	if w == nil || w.UsedPercent == nil || math.IsNaN(*w.UsedPercent) || math.IsInf(*w.UsedPercent, 0) || *w.UsedPercent < 0 {
		return Window{}, false
	}
	used := math.Min(*w.UsedPercent, 100)
	x := Window{Kind: "unknown", Limit: label, UsedPercent: &used, ResetsAt: stamp(w.ResetsAt), ResetMode: "fixed", ObservedAt: observed}
	if w.WindowMinutes != nil && *w.WindowMinutes > 0 && *w.WindowMinutes < 1<<20 {
		x.WindowMinutes = *w.WindowMinutes
		x.Kind = kindOf(*w.WindowMinutes)
	}
	if x.Kind != "unknown" && restatesKind.MatchString(label) {
		x.Limit = "" // "5 hours", "Weekly": the kind already says it
	}
	return x, true
}

var restatesKind = regexp.MustCompile(`(?i)^(\d+[ -]?(h|hr|hrs|hours?)|session|daily|day|weekly|week|monthly|month)( (window|limit|usage))?$`)

var labelRe = regexp.MustCompile(`^[\p{L}\p{N}][\p{L}\p{N} ._:/+()-]{0,39}$`)

// label keeps a display label CodexBar reported (a window title, a plan name) short and plain.
func label(s string) string {
	s = strings.TrimSpace(s)
	if !labelRe.MatchString(s) {
		return ""
	}
	return s
}

var (
	emailRe = regexp.MustCompile(`[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}`)
	tokenRe = regexp.MustCompile(`[A-Za-z0-9_\-]{24,}`)
	userDir = regexp.MustCompile(`(/Users|/home)/[^/\s]+`)
)

// clean: one short line without the home directory, e-mail addresses or token-like strings.
func clean(s, home string) string {
	if home != "" {
		s = strings.ReplaceAll(s, home, "~")
	}
	s = userDir.ReplaceAllString(s, "~")
	s = emailRe.ReplaceAllString(s, "<email>")
	s = tokenRe.ReplaceAllString(s, "<id>")
	return short(s)
}

// applyCodexBar adds one account per enabled provider with a recent usable reading, and one
// source status per enabled provider saying what was read or why not.
func applyCodexBar(r *Report, p Paths, now time.Time) {
	enabled := CodexBarActive(p)
	if len(enabled) == 0 {
		return
	}
	s := loadCodexBar(p.Cache)
	by := map[string]codexbarEntry{}
	if s != nil && s.Status == "ok" {
		for _, e := range s.Providers {
			by[e.Provider] = e
		}
	}
	for _, prov := range enabled {
		st := SourceStatus{Source: "codexbar:" + prov}
		e, ok := by[prov]
		switch {
		case s == nil:
			st.Status, st.Reason = "missing", "no CodexBar reading yet"
		case s.Status != "ok":
			st.Status, st.Reason = "unreadable", s.Error
		case !ok:
			st.Status, st.Reason = "missing", "not read yet"
		case now.Sub(e.ObservedAt) > codexbarKeep || e.ObservedAt.After(now.Add(5*time.Minute)):
			st.Status, st.Reason = "stale", "last reading older than 6 hours"
		case e.Status == "estimated":
			st.Status, st.Reason = "estimated", "CodexBar only estimated from this machine's history; not shown as quota"
		case e.Status != "ok":
			st.Status, st.Reason = "unavailable", e.Error
		case len(e.Windows) == 0:
			st.Status, st.Reason = "empty", "no usage windows"
		default:
			st.Status = "ok"
			r.Accounts = append(r.Accounts, Account{Source: st.Source, Plan: e.Plan, ObservedAt: e.ObservedAt, Windows: append([]Window(nil), e.Windows...), Via: "codexbar"})
		}
		r.Sources = append(r.Sources, st)
	}
}
