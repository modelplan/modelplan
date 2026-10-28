package detect

import (
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

// Env deliberately has no credential or process-launch interface. OS presence
// adapters must be silent and return unknown when checking might prompt.
type Env struct {
	Home, Path, OS, ClaudeConfigDir, CodexHome string
	BundlePresent                              func(string) string
	KeychainPresent                            func(Signal) string
}

func Local() Env {
	home, _ := os.UserHomeDir()
	return Env{Home: home, Path: os.Getenv("PATH"), OS: runtime.GOOS, ClaudeConfigDir: os.Getenv("CLAUDE_CONFIG_DIR"), CodexHome: os.Getenv("CODEX_HOME")}
}

type Tool struct {
	Entry
	Detected bool   `json:"detected"`
	Status   string `json:"status"`
	NextStep string `json:"nextStep,omitempty"`
}
type Report struct {
	SchemaVersion     int    `json:"schemaVersion"`
	CatalogueSource   string `json:"catalogueSource"`
	CatalogueRevision int    `json:"catalogueRevision"`
	Tools             []Tool `json:"tools"`
}

// Run stats known paths only. Output carries logical IDs, never matched paths,
// usernames, sign-in claims or credentials. All signal matches are OR-ed.
func Run(c *Catalogue, e Env, version, source string) Report {
	r := Report{SchemaVersion: 1, CatalogueSource: source, CatalogueRevision: c.Revision, Tools: []Tool{}}
	for _, entry := range c.Detectors {
		t := Tool{Entry: entry, Status: "not-detected"}
		// Raw signals are catalogue metadata, not machine evidence, but omit them
		// from this report so no profile paths can leak through future additions.
		t.Signals = nil
		if !Compatible(version, entry.MinCLI) {
			t.Status = "update-required"
			t.NextStep = "update to read " + entry.DisplayName
			r.Tools = append(r.Tools, t)
			continue
		}
		unknown := false
		for _, raw := range entry.Signals {
			s, known, err := decodeSignal(json.RawMessage(raw))
			if !known || err != nil {
				continue
			}
			status := e.presence(s)
			if status == "present" {
				t.Detected = true
				t.Status = "detected"
				break
			}
			unknown = unknown || status == "unknown"
		}
		if !t.Detected && unknown {
			t.Status = "unknown"
		}
		if entry.DetectionStatus == "no-safe-signal" {
			t.Status = "no-safe-signal"
		}
		if entry.Preferred == "codexbar" {
			if reason := entry.HelperStatus(); reason != "" {
				t.Preferred = "off"
				t.Status = reason
				t.NextStep = "not yet supported"
			}
		}
		r.Tools = append(r.Tools, t)
	}
	return r
}

func safeRelative(p string) bool {
	if p == "" || filepath.IsAbs(p) || strings.ContainsAny(p, `\$~*?[]{}:`) || strings.ContainsAny(p, "\x00\r\n\t") {
		return false
	}
	for _, part := range strings.Split(p, "/") {
		if part == "" || part == "." || part == ".." {
			return false
		}
	}
	// Documented tool-owned classes; never admit unrelated secret stores such as
	// .ssh or arbitrary home files just because a remote catalogue names them.
	roots := []string{".claude", ".codex", ".zcode", ".cursor", ".copilot", ".gemini", ".kimi-code", ".qwen", ".kiro", ".grok", ".factory", ".kimi", ".local/share/amp", ".config/opencode", "Library/Application Support/Cursor", "Library/Application Support/Claude", "Library/Application Support/Codex", "Library/Application Support/ZCode"}
	for _, root := range roots {
		if p == root || strings.HasPrefix(p, root+"/") {
			return true
		}
	}
	return false
}
func confinedPresence(home, p string) string {
	if !filepath.IsAbs(home) {
		return "unknown"
	}
	base, err := filepath.EvalSymlinks(home)
	if err != nil {
		return "unknown"
	}
	target, err := filepath.EvalSymlinks(p)
	if os.IsNotExist(err) {
		return "absent"
	}
	if err != nil {
		return "unknown"
	}
	rel, err := filepath.Rel(base, target)
	if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return "unknown"
	}
	_, err = os.Stat(target)
	if err == nil {
		return "present"
	}
	if os.IsNotExist(err) {
		return "absent"
	}
	return "unknown"
}
func (e Env) presence(s Signal) string {
	switch s.Type {
	case "path":
		p := filepath.Join(e.Home, filepath.FromSlash(s.Value))
		if s.Value == ".claude" && e.ClaudeConfigDir != "" {
			p = e.ClaudeConfigDir
		}
		if s.Value == ".codex" && e.CodexHome != "" {
			p = e.CodexHome
		}
		return confinedPresence(e.Home, p)
	case "command":
		dirs := append(filepath.SplitList(e.Path), filepath.Join(e.Home, ".local/bin"), filepath.Join(e.Home, "bin"), "/opt/homebrew/bin", "/usr/local/bin")
		for _, dir := range dirs {
			if !filepath.IsAbs(dir) {
				continue
			}
			fi, err := os.Stat(filepath.Join(dir, s.Name))
			if err == nil && fi.Mode().IsRegular() && fi.Mode().Perm()&0111 != 0 {
				return "present"
			}
		}
		return "absent"
	case "bundleId":
		if e.OS == "darwin" && e.BundlePresent != nil {
			return e.BundlePresent(s.Value)
		}
		return "unknown"
	case "keychainItem":
		if e.OS == "darwin" && e.KeychainPresent != nil {
			return e.KeychainPresent(s)
		}
		return "unknown"
	}
	return "unknown"
}

// LocalRoot admits only an existing literal local tool directory. Callers supply
// compiled tool roots or explicit local environment selections, never remote paths.
// This checks presence metadata only and does not open tool files.
func LocalRoot(root string) bool {
	if !filepath.IsAbs(root) {
		return false
	}
	info, err := os.Lstat(root)
	return err == nil && info.IsDir() && info.Mode()&os.ModeSymlink == 0
}
