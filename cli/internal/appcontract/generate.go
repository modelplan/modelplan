// SPDX-License-Identifier: MIT
package appcontract

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"regexp"
	"sort"
	"strings"
	"time"
)

type Entry struct {
	File      string   `json:"file"`
	State     string   `json:"state"`
	Schema    string   `json:"schema"`
	Arguments []string `json:"arguments"`
	Encoding  string   `json:"encoding"`
	ExitCode  int      `json:"exitCode"`
	Stderr    string   `json:"stderr"`
	Request   string   `json:"request,omitempty"`
}
type Manifest struct {
	Version   int      `json:"version"`
	Generator string   `json:"generator"`
	States    []string `json:"states"`
	Entries   []Entry  `json:"entries"`
}
type suite struct {
	cli, helper, home, state string
	env                      []string
	v                        *Validator
	files                    map[string][]byte
	entries                  []Entry
}

func Build(root, output, pkg string) error {
	cmd := exec.Command("go", "build", "-trimpath", "-ldflags", "-X main.version=1.0.0", "-o", output, pkg)
	cmd.Dir = filepath.Join(root, "cli")
	b, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("build %s: %w\n%s", pkg, err, b)
	}
	return nil
}

// Generate executes a real CLI built from this checkout. The helper is this
// tool's own executable, used only for synthetic Copilot protocol replies.
func Generate(root, helper string) (map[string][]byte, error) {
	v, err := NewValidator(root)
	if err != nil {
		return nil, err
	}
	tmp, err := os.MkdirTemp("", "modelplan-app-contract-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(tmp)
	cli := filepath.Join(tmp, "modelplan")
	if err := Build(root, cli, "./cmd/modelplan"); err != nil {
		return nil, err
	}
	s := &suite{cli: cli, helper: helper, v: v, files: map[string][]byte{}}
	states := []string{"fresh", "consented", "refreshed", "unreadable", "revoked", "cleanup-pending"}
	for _, state := range states {
		s.home, s.state = filepath.Join(tmp, state), state
		if err := s.setup(); err != nil {
			return nil, err
		}
		if state != "fresh" {
			for _, dir := range []string{".copilot", ".codex", ".claude"} {
				if err := os.MkdirAll(filepath.Join(s.home, dir), 0700); err != nil {
					return nil, err
				}
			}
			if _, err := s.grant("grant", 0, []string{"copilot", "codex"}, []string{}); err != nil {
				return nil, err
			}
		}
		if state == "refreshed" || state == "revoked" || state == "cleanup-pending" {
			// This is the real binary's normal desktop path, not a hand-built
			// cache. The first poll is racy by design, so validate it and wait for
			// its real detached worker before recording the stable next poll.
			raw, code, _, err := s.run([]string{"desktop", "--json"}, nil)
			if err != nil || code != 0 {
				return nil, fmt.Errorf("initial desktop: %w (exit %d)", err, code)
			}
			if err := s.v.Validate("desktop", raw); err != nil {
				return nil, err
			}
			deadline := time.Now().Add(10 * time.Second)
			for {
				raw, _, _, err := s.run([]string{"desktop", "--json", "--read-only"}, nil)
				if err != nil {
					return nil, err
				}
				var snap struct {
					Accounts []any `json:"accounts"`
				}
				_ = json.Unmarshal(raw, &snap)
				_, lockErr := os.Stat(filepath.Join(s.home, "cache", "observed", "native.lock"))
				if len(snap.Accounts) > 0 && os.IsNotExist(lockErr) {
					break
				}
				if time.Now().After(deadline) {
					return nil, fmt.Errorf("%s: real desktop worker never filled native cache", state)
				}
				time.Sleep(20 * time.Millisecond)
			}
		}
		if state == "unreadable" {
			s.env = append(s.env, "MODELPLAN_CONTRACT_UNREADABLE=1")
			if _, code, _, err := s.run([]string{"connections", "refresh", "--quiet", "--scheduled"}, nil); err != nil || code != 0 {
				return nil, fmt.Errorf("unreadable refresh: %w (%d)", err, code)
			}
		}
		if state == "revoked" || state == "cleanup-pending" {
			if state == "cleanup-pending" {
				if err := os.WriteFile(filepath.Join(s.home, "cache", "observed", "native.lock"), nil, 0600); err != nil {
					return nil, err
				}
			}
			if _, err := s.grant("revoke", 1, []string{}, []string{"copilot", "codex"}); err != nil {
				return nil, err
			}
		}
		callsBefore, _ := os.ReadFile(filepath.Join(s.home, "calls"))
		commands := []struct {
			name, schema string
			args         []string
			readonly     bool
		}{
			{"consent", "consent", []string{"consent", "--json"}, true},
			{"desktop-read-only", "desktop", []string{"desktop", "--json", "--read-only"}, true},
			{"detect", "detect", []string{"detect", "--json"}, true},
			{"connections", "connections", []string{"connections", "--json"}, true},
			{"connections-text", "connections-text", []string{"connections"}, true},
			{"doctor-readers", "doctor-readers", []string{"doctor", "readers", "--json"}, true},
			{"publication-offline", "publication", []string{"publication", "--json", "--offline"}, true},
			{"publication", "publication", []string{"publication", "--json"}, false},
			{"refresh-account", "refresh-account", []string{"quota", "--refresh-account", "--quiet"}, false},
		}
		if state != "consented" {
			commands = append(commands, struct {
				name, schema string
				args         []string
				readonly     bool
			}{"desktop", "desktop", []string{"desktop", "--json"}, false})
		}
		if state == "fresh" {
			commands = append(commands, struct {
				name, schema string
				args         []string
				readonly     bool
			}{"help", "help", []string{"--help"}, true})
		}
		for _, c := range commands {
			if err := s.capture(c.name, c.schema, c.args, nil, c.readonly, ""); err != nil {
				return nil, err
			}
		}
		callsAfter, _ := os.ReadFile(filepath.Join(s.home, "calls"))
		if !bytes.Equal(callsBefore, callsAfter) {
			return nil, fmt.Errorf("%s: cached/read-only/not-due commands started a provider request", state)
		}
		if state == "consented" {
			// Dynamic state failures are valid request shapes; exact error codes
			// are generated by the CLI, not supplied as expected reply JSON.
			if _, err := s.grant("stale-generation", 999, []string{"copilot"}, []string{}); err != nil {
				return nil, err
			}
			if _, err := s.grant("unknown-tool", 1, []string{"missing"}, []string{}); err != nil {
				return nil, err
			}
		}
	}
	// Offline publication failure has no JSON envelope: preserve the actual
	// empty stdout and exit 3 rather than inventing a successful empty graph.
	s.home, s.state = filepath.Join(tmp, "no-publication"), "fresh"
	if err := s.setup(); err != nil {
		return nil, err
	}
	if err := os.RemoveAll(filepath.Join(s.home, "cache")); err != nil {
		return nil, err
	}
	if err := s.capture("publication-unavailable", "publication", []string{"publication", "--json", "--offline"}, nil, true, ""); err != nil {
		return nil, err
	}
	m := Manifest{Version: 1, Generator: "same-checkout CLI; make app-cli-fixtures", States: states, Entries: s.entries}
	b, _ := json.MarshalIndent(m, "", "  ")
	s.files["manifest.json"] = append(b, '\n')
	return s.files, nil
}

func (s *suite) setup() error {
	bin := filepath.Join(s.home, "bin")
	if err := os.MkdirAll(bin, 0700); err != nil {
		return err
	}
	// Connections probes known absolute install locations as well as PATH.
	// Supply inert presence markers for every probed CLI so developer/runner
	// installations cannot affect synthetic output. They never run a provider.
	for _, name := range []string{"codex", "claude", "opencode", "zcode", "kiro-cli", "cursor", "gemini", "qwen"} {
		if err := os.WriteFile(filepath.Join(bin, name), []byte("#!/bin/sh\nexit 99\n"), 0700); err != nil {
			return err
		}
	}
	if err := os.Symlink(s.helper, filepath.Join(bin, "copilot")); err != nil {
		return err
	}
	s.env = []string{"HOME=" + s.home, "PATH=" + bin, "TZ=UTC", "LANG=C", "MODELPLAN_LANG=en", "NO_COLOR=1", "MODELPLAN_CACHE=" + filepath.Join(s.home, "cache"), "CODEX_HOME=" + filepath.Join(s.home, ".codex"), "MODELPLAN_COPILOT=" + filepath.Join(bin, "copilot"), "MODELPLAN_CODEX=" + filepath.Join(bin, "codex"), "MODELPLAN_HISTORY=off", "MODELPLAN_CODEXBAR=off", "MODELPLAN_CODEX_ACCOUNT=off", "MODELPLAN_TASK_BRIEF=off", "MODELPLAN_BASE=http://127.0.0.1:1", "MODELPLAN_CONTRACT_CALLS=" + filepath.Join(s.home, "calls")}
	// Retain runtime proxy/trust selectors without inheriting credential/key
	// variables into synthetic CLI homes. No environment values are printed.
	for _, k := range []string{"HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "SSL_CERT_FILE", "SSL_CERT_DIR"} {
		if v := os.Getenv(k); v != "" {
			s.env = append(s.env, k+"="+v)
		}
	}
	return seedPublication(s.home)
}

func (s *suite) run(args []string, input []byte) ([]byte, int, string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, s.cli, args...)
	cmd.Env = s.env
	cmd.Stdin = bytes.NewReader(input)
	var out, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &stderr
	err := cmd.Run()
	code := 0
	if e, ok := err.(*exec.ExitError); ok {
		code = e.ExitCode()
		err = nil
	}
	if ctx.Err() != nil {
		return nil, code, "", ctx.Err()
	}
	return out.Bytes(), code, stderr.String(), err
}

func (s *suite) grant(name string, generation uint64, allow, deny []string) ([]byte, error) {
	read, _, _, err := s.run([]string{"consent", "--json"}, nil)
	if err != nil {
		return nil, err
	}
	var current struct {
		ConsentTextVersion int `json:"consentTextVersion"`
	}
	if err := json.Unmarshal(read, &current); err != nil {
		return nil, err
	}
	id := "00000000-0000-4000-8000-000000000001"
	if name != "grant" {
		id = fmt.Sprintf("00000000-0000-4000-8000-%012d", len(s.entries)+2)
	}
	request, _ := json.Marshal(map[string]any{"requestId": id, "expectGeneration": generation, "consentTextVersion": current.ConsentTextVersion, "allow": allow, "deny": deny, "keychain": map[string]string{}})
	requestFile := s.state + "-" + name + ".request.json"
	if err := s.v.Validate("consent-grant-request", request); err != nil {
		return nil, err
	}
	s.files[requestFile], _ = canonical(request, s.home)
	s.entries = append(s.entries, Entry{File: requestFile, State: s.state, Schema: "consent-grant-request", Arguments: []string{"consent", "grant", "--json"}, Encoding: "stdin-json"})
	return request, s.capture(name, "consent-grant-response", []string{"consent", "grant", "--json"}, request, false, requestFile)
}

func (s *suite) capture(name, schema string, args []string, input []byte, readonly bool, request string) error {
	before, err := tree(s.home)
	if err != nil {
		return err
	}
	raw, code, stderr, err := s.run(args, input)
	if err != nil {
		return err
	}
	if readonly {
		after, err := tree(s.home)
		if err != nil {
			return err
		}
		if !reflect.DeepEqual(before, after) {
			return fmt.Errorf("%s %v wrote to a read-only synthetic home", s.state, args)
		}
	}
	encoding := "json"
	if schema == "connections-text" || schema == "refresh-account" || schema == "help" || len(bytes.TrimSpace(raw)) == 0 {
		raw, _ = json.Marshal(string(raw))
		encoding = "text"
	}
	if err := s.v.Validate(schema, raw); err != nil {
		return fmt.Errorf("%s %v schema: %w\n%s", s.state, args, err, raw)
	}
	expectedExit := 0
	if name == "publication-unavailable" {
		expectedExit = 3
	}
	if code != expectedExit && schema != "consent-grant-response" {
		return fmt.Errorf("unexpected %s exit %d: %s", name, code, stderr)
	}
	if schema == "desktop" {
		var snap struct {
			Accounts []any                                     `json:"accounts"`
			Sources  []struct{ Source, Status, Reason string } `json:"sources"`
		}
		if err := json.Unmarshal(raw, &snap); err != nil {
			return err
		}
		if s.state == "refreshed" && len(snap.Accounts) == 0 {
			return fmt.Errorf("refreshed binary snapshot lost native values")
		}
		if s.state != "refreshed" && len(snap.Accounts) != 0 {
			return fmt.Errorf("%s unexpectedly exposed account values", s.state)
		}
		if s.state == "unreadable" {
			found := false
			for _, source := range snap.Sources {
				if source.Source == "native:copilot" && source.Status != "ok" && source.Reason != "" {
					found = true
				}
			}
			if !found {
				return fmt.Errorf("unreadable reader lost its cause/next step")
			}
		}
	}
	if schema == "consent-grant-response" {
		var reply struct {
			OK    bool   `json:"ok"`
			Error string `json:"error"`
		}
		_ = json.Unmarshal(raw, &reply)
		want := ""
		switch name {
		case "stale-generation":
			want = "stale_generation"
		case "unknown-tool":
			want = "unknown_tool"
		case "revoke":
			if s.state == "cleanup-pending" {
				want = "cleanup_pending"
			}
		}
		if reply.Error != want || reply.OK != (want == "") || (code == 0) != (want == "") {
			return fmt.Errorf("%s: wrong grant outcome exit=%d error=%s", name, code, reply.Error)
		}
	}
	b, err := canonical(raw, s.home)
	if err != nil {
		return err
	}
	file := s.state + "-" + name + ".json"
	s.files[file] = b
	s.entries = append(s.entries, Entry{File: file, State: s.state, Schema: schema, Arguments: args, Encoding: encoding, ExitCode: code, Stderr: strings.ReplaceAll(stderr, s.home, "$HOME"), Request: request})
	return nil
}

func tree(root string) (map[string]string, error) {
	result := map[string]string{}
	err := filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		var b []byte
		if d.Type()&os.ModeSymlink != 0 {
			var link string
			link, err = os.Readlink(path)
			b = []byte(link)
		} else {
			b, err = os.ReadFile(path)
		}
		if err != nil {
			return err
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		result[path] = fmt.Sprintf("%x/%s/%d", sha256.Sum256(b), info.Mode(), info.ModTime().UnixNano())
		return nil
	})
	return result, err
}

var day = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}$`)
var age = regexp.MustCompile(`^\d+s$`)

func canonical(raw []byte, home string) ([]byte, error) {
	var v any
	if err := json.Unmarshal(raw, &v); err != nil {
		return nil, err
	}
	fixed := time.Date(2030, 1, 2, 3, 4, 5, 0, time.UTC)
	anchor := time.Now().UTC()
	if root, ok := v.(map[string]any); ok {
		if s, ok := root["generatedAt"].(string); ok {
			if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
				anchor = t
			}
		}
	}
	var walk func(any, string) any
	walk = func(v any, key string) any {
		switch x := v.(type) {
		case map[string]any:
			// Preserve the relation between fixed resets and the report clock;
			// otherwise a new generation day changes this integer every minute.
			if value, ok := x["resetsInMinutes"].(float64); ok {
				if stamp, ok := x["resetsAt"].(string); ok {
					if reset, err := time.Parse(time.RFC3339Nano, stamp); err == nil && reset.Year() >= 2090 {
						x["resetsInMinutes"] = value - math.Ceil(reset.Sub(anchor).Minutes()) + math.Ceil(reset.Sub(fixed).Minutes())
					}
				}
			}
			for k, y := range x {
				x[k] = walk(y, k)
			}
			return x
		case []any:
			for i, y := range x {
				x[i] = walk(y, key)
			}
			return x
		case string:
			x = strings.ReplaceAll(x, home, "$HOME")
			if key == "dataRevision" {
				return ""
			}
			if key == "last" && age.MatchString(x) {
				return "0s"
			}
			if t, err := time.Parse(time.RFC3339Nano, x); err == nil && t.Year() > 1 && t.Year() < 2090 && key != "publishedAt" {
				return fixed.Add(t.Sub(anchor).Round(time.Minute)).Format(time.RFC3339)
			}
			if day.MatchString(x) {
				t, _ := time.Parse("2006-01-02", x)
				return fixed.Truncate(24 * time.Hour).Add(t.Sub(anchor.Truncate(24 * time.Hour))).Format("2006-01-02")
			}
			return x
		case float64:
			if key == "ageMinutes" {
				return float64(0)
			}
			return x
		default:
			return v
		}
	}
	normalized := walk(v, "")
	if root, ok := normalized.(map[string]any); ok {
		if _, exists := root["dataRevision"]; exists {
			b, _ := json.Marshal(root)
			root["dataRevision"] = fmt.Sprintf("%x", sha256.Sum256(b))
		}
	}
	b, err := json.MarshalIndent(normalized, "", "  ")
	return append(b, '\n'), err
}

func Check(root string, files map[string][]byte, write bool) error {
	dir := filepath.Join(root, "schema", "app-cli", "fixtures")
	if write {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return err
		}
	}
	names := make([]string, 0, len(files))
	for n := range files {
		names = append(names, n)
	}
	sort.Strings(names)
	for _, n := range names {
		path := filepath.Join(dir, n)
		if write {
			if err := os.WriteFile(path, files[n], 0644); err != nil {
				return err
			}
			continue
		}
		old, err := os.ReadFile(path)
		if err != nil || !bytes.Equal(old, files[n]) {
			detail := ""
			before, after := strings.Split(string(old), "\n"), strings.Split(string(files[n]), "\n")
			for i := 0; i < len(before) && i < len(after); i++ {
				if before[i] != after[i] {
					detail = fmt.Sprintf("; first difference line %d: committed %q, generated %q", i+1, before[i], after[i])
					break
				}
			}
			return fmt.Errorf("app–CLI fixture drift: %s%s; review schema/consumer changes and run make app-cli-fixtures", n, detail)
		}
	}
	entries, _ := os.ReadDir(dir)
	for _, e := range entries {
		if strings.HasSuffix(e.Name(), ".json") {
			if _, ok := files[e.Name()]; !ok {
				return fmt.Errorf("obsolete app fixture: %s", e.Name())
			}
		}
	}
	return nil
}
