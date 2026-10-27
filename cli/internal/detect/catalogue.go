// Package detect evaluates presence hints, never sign-in, credentials or quota.
package detect

import (
	"encoding/json"
	"errors"
	"regexp"
	"strconv"
	"strings"
)

// These consumer DTOs follow FEEDFIX's D590 catalogue contract. Reader and seed
// ownership stays with FEEDFIX; no remote executable, predicate or code is accepted.
type Catalogue struct {
	SchemaVersion int     `json:"detectorSchemaVersion"`
	Revision      int     `json:"detectorRevision"`
	Detectors     []Entry `json:"detectors"`
}
type Entry struct {
	ProviderID  string `json:"providerId"`
	DisplayName string `json:"displayName"`
	ReaderID    string `json:"readerId"`
	Preferred   string `json:"preferred"`
	CodexBar    struct {
		Audited     bool   `json:"audited"`
		AccessClass string `json:"accessClass,omitempty"`
	} `json:"codexbar"`
	MinCLI          string            `json:"minCli"`
	Beta            bool              `json:"beta"`
	DetectionStatus string            `json:"detectionStatus"`
	Signals         []json.RawMessage `json:"signals"`
}

// HelperStatus is independent per provider. A checksum/audit flag alone cannot
// opt an older client into an unknown access class.
func (e Entry) HelperStatus() string {
	if !e.CodexBar.Audited {
		return "codexbar-not-audited"
	}
	switch e.CodexBar.AccessClass {
	case "standard", "browser-session":
		return ""
	case "not-read":
		return "codexbar-not-read"
	default:
		return "codexbar-access-unknown"
	}
}

type Signal struct {
	Type  string `json:"type"`
	Value string `json:"value"`
	Name  string `json:"name"`
	Rule  string `json:"rule"`
}

var literal = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9._-]{0,95}$`)
var id = regexp.MustCompile(`^[a-z][a-z0-9-]{0,47}$`)
var semver = regexp.MustCompile(`^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$`)

// ParseData consumes only the catalogue fields of a verified client.data object.
// Missing fields mean the publication predates the catalogue. Unknown signals
// and derivation rules are inert, even when their future payload is unfamiliar.
func ParseData(data []byte) (*Catalogue, error) {
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(data, &fields); err != nil {
		return nil, err
	}
	if fields["detectors"] == nil && fields["detectorSchemaVersion"] == nil && fields["detectorRevision"] == nil {
		return nil, nil
	}
	var selected = map[string]json.RawMessage{}
	for _, key := range []string{"detectors", "detectorSchemaVersion", "detectorRevision"} {
		selected[key] = fields[key]
	}
	b, err := json.Marshal(selected)
	if err != nil || len(b) > 256<<10 {
		return nil, errors.New("catalogue too large")
	}
	var c Catalogue
	if json.Unmarshal(b, &c) != nil || c.SchemaVersion != 1 || c.Revision < 1 || c.Revision > 9007199254740991 || c.Detectors == nil || len(c.Detectors) > 512 {
		return nil, errors.New("unsupported detector catalogue")
	}
	seen := map[string]bool{}
	for _, e := range c.Detectors {
		if !id.MatchString(e.ProviderID) || seen[e.ProviderID] || len(e.DisplayName) == 0 || len(e.DisplayName) > 96 || strings.ContainsAny(e.DisplayName, "\r\n\t\x1b") || !semver.MatchString(e.MinCLI) || len(e.Signals) > 16 {
			return nil, errors.New("invalid detector entry")
		}
		seen[e.ProviderID] = true
		parts := strings.Split(e.ReaderID, ":")
		if len(parts) != 2 || (parts[0] != "native" && parts[0] != "codexbar") || !id.MatchString(parts[1]) || (e.Preferred != "native" && e.Preferred != "codexbar" && e.Preferred != "off") {
			return nil, errors.New("invalid detector routing")
		}
		if e.DetectionStatus != "signals" && e.DetectionStatus != "no-safe-signal" {
			return nil, errors.New("invalid detection status")
		}
		if e.DetectionStatus == "signals" && len(e.Signals) == 0 {
			return nil, errors.New("missing detector signals")
		}
		for _, raw := range e.Signals {
			_, known, err := decodeSignal(raw)
			if known && err != nil {
				return nil, errors.New("invalid detector signal")
			}
		}
	}
	return &c, nil
}

func decodeSignal(raw json.RawMessage) (Signal, bool, error) {
	var tag struct {
		Type string          `json:"type"`
		Rule json.RawMessage `json:"rule"`
	}
	if json.Unmarshal(raw, &tag) != nil {
		return Signal{}, false, nil
	}
	if tag.Type != "path" && tag.Type != "command" && tag.Type != "bundleId" && tag.Type != "keychainItem" {
		return Signal{}, false, nil
	}
	if tag.Type == "keychainItem" && tag.Rule != nil && string(tag.Rule) != `"claude-config-dir"` {
		return Signal{}, false, nil
	}
	var s Signal
	if err := json.Unmarshal(raw, &s); err != nil {
		return s, true, err
	}
	valid := false
	switch s.Type {
	case "path":
		valid = safeRelative(s.Value)
	case "command":
		valid = literal.MatchString(s.Name) && !strings.Contains(s.Name, "..")
	case "bundleId":
		valid = literal.MatchString(s.Value) && strings.Contains(s.Value, ".")
	case "keychainItem":
		valid = (s.Name != "" && len(s.Name) <= 96 && !strings.ContainsAny(s.Name, "\r\n\t\x00\x1b") && s.Rule == "") || (s.Name == "" && s.Rule == "claude-config-dir")
	}
	if !valid {
		return s, true, errors.New("unsafe signal")
	}
	return s, true, nil
}

// Compatible compares release components; prereleases of the minimum release
// do not satisfy it. Build metadata does not change compatibility.
func Compatible(current, minimum string) bool {
	current = strings.TrimPrefix(current, "v")
	if !semver.MatchString(current) || !semver.MatchString(minimum) {
		return false
	}
	a, b := strings.Split(strings.Split(current, "+")[0], "-"), strings.Split(strings.Split(minimum, "+")[0], "-")
	av, bv := strings.Split(a[0], "."), strings.Split(b[0], ".")
	for i := 0; i < 3; i++ {
		x, xe := strconv.ParseUint(av[i], 10, 64)
		y, ye := strconv.ParseUint(bv[i], 10, 64)
		if xe != nil || ye != nil {
			return false
		}
		if x != y {
			return x > y
		}
	}
	if len(a) > 1 {
		return len(b) > 1 && strings.Join(a[1:], "-") == strings.Join(b[1:], "-")
	}
	return true
}

// Fallback is a small bootstrap catalogue based on the clients' existing local
// tool signals. FEEDFIX owns the complete attributed catalogue port. No helper
// route is audited by this seed, and nothing is enabled by detection.
func Fallback() *Catalogue {
	c := &Catalogue{SchemaVersion: 1, Revision: 1, Detectors: []Entry{}}
	for _, tool := range []struct{ id, name, command, path string }{
		{"claude", "Claude Code", "claude", ".claude"}, {"codex", "Codex", "codex", ".codex"},
		{"zai", "ZCode / GLM", "zcode", ".zcode"}, {"cursor", "Cursor", "cursor", ".cursor"},
		{"copilot", "GitHub Copilot", "copilot", ".copilot"}, {"gemini", "Gemini CLI", "gemini", ".gemini"},
		{"kimi", "Kimi Code", "kimi", ".kimi-code"}, {"qwen", "Qwen Code", "qwen", ".qwen"},
		{"opencodego", "OpenCode", "opencode", ".config/opencode"}, {"kiro", "Kiro", "kiro-cli", ".kiro"},
	} {
		e := Entry{ProviderID: tool.id, DisplayName: tool.name, ReaderID: "native:" + tool.id, Preferred: "native", MinCLI: "0.0.0", Beta: true, DetectionStatus: "signals"}
		for _, s := range []Signal{{Type: "command", Name: tool.command}, {Type: "path", Value: tool.path}} {
			b, _ := json.Marshal(s)
			e.Signals = append(e.Signals, b)
		}
		c.Detectors = append(c.Detectors, e)
	}
	return c
}
