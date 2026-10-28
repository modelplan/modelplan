package quota

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// Which reader serves each optional quota provider. ~/.config/modelplan/connections.json (optional,
// schema 1) names a backend per provider: native (this client's own reader, quota_native.go) or
// codexbar-compat (CodexBar's CLI, codexbar.go), or turns the provider off. A provider it does not
// list keeps its legacy setting: enabled in codexbar.json means CodexBar. There is never a silent
// fallback from one backend to the other, and an entry naming a native reader that does not exist
// reads nothing. MODELPLAN_CODEXBAR=off stops the CodexBar backend only; MODELPLAN_NATIVE=off stops
// the native one only.

const (
	BackendNative   = "native"
	BackendCodexBar = "codexbar-compat"
	BackendOff      = "off"
)

// QuotaSource is one entry of connections.json. KeyEnv names the environment variable that holds
// the API key; the key itself is never written anywhere.
type QuotaSource struct {
	Provider string `json:"provider"`
	Backend  string `json:"backend"`
	Enabled  bool   `json:"enabled"`
	Region   string `json:"region,omitempty"`
	KeyEnv   string `json:"keyEnv,omitempty"`
}

type connectionsFile struct {
	SchemaVersion int           `json:"schemaVersion"`
	QuotaSources  []QuotaSource `json:"quotaSources"`
}

// Selection is the effective choice for one provider.
type Selection struct {
	Host           string `json:"host,omitempty"`
	EndpointNotice string `json:"endpointNotice,omitempty"`
	Provider       string `json:"provider"`
	Name           string `json:"name"`
	Backend        string `json:"backend"` // native | codexbar-compat | off
	Origin         string `json:"origin"`  // connections.json | codexbar.json
	Region         string `json:"region,omitempty"`
	KeyEnv         string `json:"keyEnv,omitempty"`
	// KeySet: the variable is set and not empty in this process's environment.
	KeySet       bool     `json:"keySet"`
	Read         string   `json:"read,omitempty"`
	Hosts        []string `json:"hosts,omitempty"`
	SecretPolicy string   `json:"secretPolicy,omitempty"`
	// Blocked: why the selected backend does not run: codexbar-off, native-off, no-native-reader,
	// no-key.
	Blocked     string `json:"blocked,omitempty"`
	AccessClass string `json:"accessClass,omitempty"`
}

var envName = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]{0,63}$`)

func ValidateSource(s QuotaSource) error { return s.check() }

// LoadConnections reads connections.json. A missing file is no entries; an unusable one is an
// error, and then no provider is read through it (nor through a legacy setting it may override).
func LoadConnections(file string) ([]QuotaSource, error) {
	if file == "" {
		return nil, nil
	}
	b, status := readBounded(file, 64<<10)
	if status == "missing" {
		return nil, nil
	}
	if status != "" {
		return nil, fmt.Errorf("connections.json: %s", status)
	}
	var c connectionsFile
	if err := json.Unmarshal(b, &c); err != nil || c.SchemaVersion != 1 {
		return nil, fmt.Errorf("connections.json: not schema 1")
	}
	seen := map[string]bool{}
	for _, s := range c.QuotaSources {
		if err := s.check(); err != nil {
			return nil, err
		}
		if seen[s.Provider] {
			return nil, fmt.Errorf("connections.json: %s listed twice", s.Provider)
		}
		seen[s.Provider] = true
	}
	return c.QuotaSources, nil
}

func (s QuotaSource) check() error {
	if ProviderName(s.Provider) == "" {
		return fmt.Errorf("connections.json: unknown provider %q", s.Provider)
	}
	if s.Backend != BackendNative && s.Backend != BackendCodexBar {
		return fmt.Errorf("connections.json: %s: backend must be native or codexbar-compat", s.Provider)
	}
	if s.Backend == BackendCodexBar && s.Provider == "kimi" {
		return fmt.Errorf("connections.json: Kimi uses only the native environment-key reader")
	}
	if s.Backend == BackendCodexBar && s.Provider == "minimax" {
		return fmt.Errorf("connections.json: MiniMax uses only the native environment-key reader")
	}
	if s.KeyEnv != "" && !envName.MatchString(s.KeyEnv) {
		return fmt.Errorf("connections.json: %s: keyEnv is not an environment variable name", s.Provider)
	}
	if n := nativeReaders[s.Provider]; s.Backend == BackendNative && n != nil && s.Region != "" && !contains(n.Regions, s.Region) {
		return fmt.Errorf("connections.json: %s: region must be one of %s", s.Provider, strings.Join(n.Regions, ", "))
	}
	return nil
}

// Selections: the effective backend of every provider that is configured anywhere, sorted.
var loadReaderCatalogue = func(cache string) *detect.Catalogue {
	if d, _, err := publication.Load(&store.Store{Dir: cache}); err == nil {
		return d.Catalogue
	}
	return nil
}

func Selections(p Paths) ([]Selection, error) {
	entries, err := LoadConnections(p.ConnectionsFile)
	if err != nil {
		return nil, err
	}
	by := map[string]Selection{}
	for _, prov := range legacyCodexBar(p.CodexBarFile) {
		by[prov] = Selection{Provider: prov, Backend: BackendCodexBar, Origin: "codexbar.json"}
	}
	for _, s := range entries {
		x := Selection{Provider: s.Provider, Backend: s.Backend, Origin: "connections.json", Region: s.Region, KeyEnv: s.KeyEnv}
		if !s.Enabled {
			x.Backend, x.Region, x.KeyEnv = BackendOff, "", ""
		}
		by[s.Provider] = x
	}
	policy, mode := consent.Current()
	publishedRoutes := map[string]detect.Entry{}
	if cat := loadReaderCatalogue(p.Cache); cat != nil {
		for _, e := range cat.Detectors {
			publishedRoutes[e.ProviderID] = e
		}
	}
	for id, r := range policy.Tools {
		if !r.Allowed {
			if x, ok := by[id]; ok {
				x.Backend = BackendOff
				by[id] = x
			}
			continue
		}
		backend := r.Backend
		if backend == "codexbar" {
			backend = BackendCodexBar
		}
		if backend != BackendNative && backend != BackendCodexBar {
			continue
		}
		x := by[id]
		x.Provider = id
		x.Backend = backend
		x.Origin = "consent.json"
		x.Region = r.Region
		x.KeyEnv = r.KeyEnv
		by[id] = x
	}
	out := make([]Selection, 0, len(by))
	for _, x := range by {
		x.Name = ProviderName(x.Provider)
		switch x.Backend {
		case BackendCodexBar:
			if codexbarOff() {
				x.Blocked = "codexbar-off"
			}
		case BackendNative:
			if x.Provider == "copilot" {
				x.Read = "copilot --headless --no-auto-update --stdio: account.getQuota; Copilot-managed sign-in, no credential file opened by modelplan (MODELPLAN_COPILOT selects executable)"
				x.Hosts = []string{"none from modelplan; Copilot runtime: api.github.com (enterprise host follows runtime configuration)"}
				x.SecretPolicy = "Credentials are never printed or stored by modelplan; only sanitized quota is cached. No identity is collected."
			}
			n := nativeReaders[x.Provider]
			if n == nil {
				x.Blocked = "no-native-reader"
				break
			}
			if x.Region == "" {
				x.Region = n.Regions[0]
			}
			if n.KeyEnv == "" {
				x.KeyEnv = "" // the agent's own CLI keeps the sign-in
			} else if x.KeyEnv == "" {
				x.KeyEnv = n.KeyEnv
			}
			if x.Provider == "cursor" {
				home, _ := os.UserHomeDir()
				x.Read = CursorReadPath(home) + " (ItemTable cursorAuth/accessToken only; read-only, including existing WAL)"
				x.Host, x.Hosts = "https://cursor.com", []string{"https://cursor.com", "https://api2.cursor.sh"}
				x.EndpointNotice = CursorEndpointNotice
				x.SecretPolicy = "No credential refresh, rewrite, copy, keychain or browser access. Only sanitized quota and keyed-hash identity references are stored."
			}
			if x.Provider == "kimi" {
				x.Host = KimiHost(x.Region)
				x.EndpointNotice = KimiEndpointNotice
			}
			if x.Provider == "minimax" {
				x.Host = MiniMaxHost(x.Region)
				x.Hosts = []string{x.Host}
				x.EndpointNotice = MiniMaxEndpointNotice
				x.Read = "env:" + x.KeyEnv
				x.SecretPolicy = "Key is never printed, stored or copied; no credential files, browser sessions, refresh or cross-region requests. Only sanitized quota and keyed-hash references are cached."
			}
			if x.KeyEnv != "" {
				x.KeySet = os.Getenv(x.KeyEnv) != "" // only whether it is there; the value stays in the environment
			}
			switch {
			case nativeOff():
				x.Blocked = "native-off"
			case x.KeyEnv != "" && !x.KeySet:
				x.Blocked = "no-key"
			}
		}
		class := consent.Credential
		if x.Backend == BackendCodexBar {
			class = consent.Bridge
		} else if x.Provider == "copilot" || x.Provider == "kiro" {
			class = consent.Runtime
		} else if n := nativeReaders[x.Provider]; n != nil && n.KeyEnv != "" {
			class = consent.ExplicitKey
		}
		allowed := policy.Allows(x.Provider, class, mode)
		if _, decided := policy.Tools[x.Provider]; !decided && mode == consent.Automatic && (x.Origin == "connections.json" || x.Origin == "codexbar.json") {
			allowed = true
		}
		if !allowed {
			x.Blocked = "reader-consent-or-privacy"
		}
		if route, ok := publishedRoutes[x.Provider]; ok {
			if route.Preferred == "off" {
				x.Blocked = "catalogue-off"
			}
		}
		if x.Backend == BackendCodexBar {
			// No automatic native-to-helper fallback. A helper is selected only
			// by an audited catalogue route explicitly accepted by the user.
			route, ok := publishedRoutes[x.Provider]
			if !ok {
				x.Blocked = "codexbar-not-audited"
			} else if reason := route.HelperStatus(); reason != "" {
				x.Blocked = reason
			} else {
				x.AccessClass = route.CodexBar.AccessClass
				if route.Preferred != "codexbar" {
					x.Blocked = "catalogue-off"
				}
				if x.AccessClass == "browser-session" && !policy.Tools[x.Provider].BrowserSession {
					x.Blocked = "browser-session-consent-required"
				}
			}
		}
		if n := nativeReaders[x.Provider]; p.ReaderAccess != nil && x.Backend == BackendNative && n != nil && n.Managed == nil && n.KeyEnv == "" {
			if _, admitted := p.ReaderAccessGrant(x.Provider); !admitted {
				x.Blocked = "reader-consent-or-privacy"
			}
		}
		if g, ok := p.ReaderAccessGrant(x.Provider); ok && (g.SavedLogin || g.ConfigSource != nil) && x.Backend == BackendNative && x.Blocked == "no-key" {
			x.Blocked = ""
			x.KeyEnv, x.KeySet = "", false
		}
		if route, ok := publishedRoutes[x.Provider]; ok && !detect.Compatible(p.CLIVersion, route.MinCLI) {
			x.Blocked = "update-required"
		}
		out = append(out, x)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Provider < out[j].Provider })
	return out, nil
}

// ReadPermitted is framework admission for existing readers. FEEDFIX owns the
// implementations and will consume the same consent/generation contract in its
// router. No credential-reading implementation lives here.
func ReadPermitted(p Paths, now time.Time) Report {
	s, mode := consent.Current()
	r := Report{ConsentGeneration: s.Generation, SchemaVersion: 1, EvaluatedAt: now.UTC(), Note: note, Accounts: []Account{}}
	if mode == consent.Off {
		r.Sources = []SourceStatus{{Source: "readers", Status: "off", Reason: "reader-privacy"}}
		return r
	}
	add := func(a []Account, st SourceStatus) {
		r.Accounts = append(r.Accounts, a...)
		r.Sources = append(r.Sources, st)
	}
	if s.Allows("claude", consent.Local, mode) {
		add(readClaudeCode(p.Cache, p.ClaudeSession))
	}
	if s.Allows("codex", consent.Local, mode) {
		add(readCodex(p.CodexHome, p.CodexThread))
		if p.CodexHome != "" {
			applyAccount(&r, p.Cache, now)
		}
	}
	add(readLocal(p.LocalFile, now))
	applyCodexBar(&r, p, now)
	applyNative(&r, p, now)
	for i := range r.Accounts {
		Evaluate(&r.Accounts[i], now)
	}
	if !consent.CurrentGeneration(s.Generation) {
		return Report{SchemaVersion: 1, EvaluatedAt: now.UTC(), Accounts: []Account{}, Sources: []SourceStatus{{Source: "readers", Status: "off", Reason: "consent-changed"}}}
	}
	return r
}

// ForgetTool deletes only ModelPlan-owned readings while holding the same cache
// locks as the current readers. Attempt gates/identities are retained so revoke,
// reconnect and catalogue rollback cannot reset a provider's request budget.
func ForgetTool(p Paths, tool string) error {
	admission, err := consent.ReaderLock()
	if err != nil {
		return err
	}
	defer admission()
	if !consent.ValidTool(tool) {
		return errors.New("invalid tool")
	}
	observed := filepath.Join(p.Cache, "observed")
	if _, err := os.Stat(observed); os.IsNotExist(err) {
		return nil
	}
	locks := []string{"native.lock", "codexbar.lock", "cycles.lock", "pace.lock", "speed.lock", "perf.lock"}
	if tool == "codex" {
		locks = append(locks, "codex-account.lock")
	}
	var releases []func()
	defer func() {
		for _, release := range releases {
			release()
		}
	}()
	for _, name := range locks {
		path := filepath.Join(observed, name)
		f, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
		if err != nil {
			return errors.New("readings busy; retry disconnect")
		}
		f.Close()
		releases = append(releases, func() { os.Remove(path) })
	}
	if n := nativeReaders[tool]; n != nil && n.Managed != nil {
		if _, err := os.Stat(readerPath(p.Cache, tool)); err == nil {
			if err := ForgetReader(p.Cache, tool); err != nil {
				return err
			}
		} else if !os.IsNotExist(err) {
			return err
		}
	}
	if err := forgetProductionReaderState(p.Cache, tool); err != nil {
		return err
	}
	files := []string{}
	if tool == "claude" {
		files = append(files, "claude-code.json")
	}
	if tool == "codex" {
		files = append(files, "codex-account.json")
	}
	for _, name := range files {
		if err := os.Remove(filepath.Join(observed, name)); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
	}
	for _, name := range []string{"native.json", "codexbar.json", "cycles.json", "pace.json", "speed.json", "perf.json", "daily-long.json"} {
		path := filepath.Join(observed, name)
		f, err := os.Open(path)
		if errors.Is(err, os.ErrNotExist) {
			continue
		}
		if err != nil {
			return err
		}
		b, err := io.ReadAll(io.LimitReader(f, (4<<20)+1))
		f.Close()
		if err != nil || len(b) > 4<<20 {
			return errors.New("cached readings unreadable")
		}
		var doc map[string]json.RawMessage
		if json.Unmarshal(b, &doc) != nil {
			return errors.New("cached readings invalid")
		}
		keys := []string{"providers"}
		if name == "cycles.json" || name == "pace.json" {
			keys = []string{"cycles"}
		}
		if name == "speed.json" || name == "daily-long.json" {
			keys = []string{"rows"}
		}
		if name == "perf.json" {
			keys = []string{"rows", "sessions", "hourly", "live"}
		}
		for _, key := range keys {
			if doc[key] == nil || string(doc[key]) == "null" {
				continue
			}
			var rows []map[string]json.RawMessage
			if json.Unmarshal(doc[key], &rows) != nil {
				return errors.New("cached rows invalid")
			}
			kept := []map[string]json.RawMessage{}
			for _, row := range rows {
				var id string
				if key == "providers" {
					json.Unmarshal(row["provider"], &id)
				} else {
					json.Unmarshal(row["source"], &id)
					id = strings.TrimPrefix(strings.TrimPrefix(id, "native:"), "codexbar:")
					switch id {
					case "claude-code":
						id = "claude"
					case "zcode":
						id = "zai"
					case "opencode":
						id = "opencodego"
					}
				}
				if id != tool {
					kept = append(kept, row)
				}
			}
			doc[key], _ = json.Marshal(kept)
		}
		b, _ = json.Marshal(doc)
		if err := writeAtomic(path, append(b, '\n')); err != nil {
			return err
		}
	}
	return nil
}

// active: the providers whose selected backend is this one and runs.
func active(p Paths, backend string) []Selection {
	ss, err := Selections(p)
	if err != nil {
		return nil
	}
	var out []Selection
	for _, s := range ss {
		if s.Backend == backend && s.Blocked == "" {
			out = append(out, s)
		}
	}
	return out
}

// CodexBarActive: the providers read through CodexBar now.
func CodexBarActive(p Paths) []string {
	var out []string
	for _, s := range active(p, BackendCodexBar) {
		out = append(out, s.Provider)
	}
	return out
}

// Overridden: connections.json decides the provider, so codexbar.json no longer does.
func Overridden(p Paths, provider string) (Selection, bool) {
	entries, err := LoadConnections(p.ConnectionsFile)
	if err != nil {
		return Selection{}, false
	}
	for _, s := range entries {
		if s.Provider == provider {
			b := s.Backend
			if !s.Enabled {
				b = BackendOff
			}
			return Selection{Provider: provider, Backend: b, Origin: "connections.json"}, true
		}
	}
	return Selection{}, false
}

// SetConnection writes (or replaces) the provider's entry; the rest of the file is kept.
func SetConnection(file string, s QuotaSource) error {
	if err := s.check(); err != nil {
		return err
	}
	entries, err := LoadConnections(file)
	if err != nil {
		return err
	}
	out := []QuotaSource{s}
	for _, e := range entries {
		if e.Provider != s.Provider {
			out = append(out, e)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Provider < out[j].Provider })
	if err := os.MkdirAll(filepath.Dir(file), 0o700); err != nil {
		return err
	}
	b, _ := json.MarshalIndent(connectionsFile{SchemaVersion: 1, QuotaSources: out}, "", "  ")
	return writeAtomic(file, append(b, '\n'))
}

// nativeOff: MODELPLAN_NATIVE=off stops every native quota reader.
func nativeOff() bool {
	v := strings.ToLower(os.Getenv("MODELPLAN_NATIVE"))
	return v == "off" || v == "0" || v == "false"
}

func ProviderName(provider string) string {
	if n := nativeReaders[provider]; n != nil && n.Name != "" {
		return n.Name
	}
	return CodexBarProviders[provider].Name
}
