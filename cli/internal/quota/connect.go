package quota

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
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
	Blocked string `json:"blocked,omitempty"`
}

var envName = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]{0,63}$`)

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
	if s.KeyEnv != "" && !envName.MatchString(s.KeyEnv) {
		return fmt.Errorf("connections.json: %s: keyEnv is not an environment variable name", s.Provider)
	}
	if n := nativeReaders[s.Provider]; s.Backend == BackendNative && n != nil && s.Region != "" && !contains(n.Regions, s.Region) {
		return fmt.Errorf("connections.json: %s: region must be one of %s", s.Provider, strings.Join(n.Regions, ", "))
	}
	return nil
}

// Selections: the effective backend of every provider that is configured anywhere, sorted.
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
			if x.Provider == "kimi" {
				x.Host = KimiHost(x.Region)
				x.EndpointNotice = KimiEndpointNotice
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
		out = append(out, x)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Provider < out[j].Provider })
	return out, nil
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
