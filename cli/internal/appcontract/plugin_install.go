// SPDX-License-Identifier: MIT
package appcontract

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"

	"github.com/modelplan/modelplan/cli/internal/plugininstall"
)

// Each case starts in its own fresh synthetic home. Installer outcomes are an
// independent axis from the quota/consent lifecycle in Manifest.States.
func (s *suite) capturePluginInstalls(tmp string) error {
	cases := []struct {
		name, status           string
		completed, calls, exit int
		offline                bool
	}{
		{name: "installed", status: "installed", completed: 2, calls: 2},
		{name: "instructions", status: "instructions"}, // Missing host, not an error.
		{name: "planned", status: "planned", offline: true},
		{name: "failed-first", status: "failed", calls: 1, exit: 1},
		{name: "failed-manual-step", status: "failed", completed: 1, calls: 2, exit: 1},
	}
	for _, tool := range []string{"claude-code", "codex"} {
		for _, tc := range cases {
			s.home, s.state = filepath.Join(tmp, "plugin-install", tool+"-"+tc.name), "fresh"
			if err := s.setup(); err != nil {
				return err
			}
			// Plugin commands do not need a publication or ModelPlan cache.
			if err := os.RemoveAll(filepath.Join(s.home, "cache")); err != nil {
				return err
			}
			host := "codex"
			if tool == "claude-code" {
				host = "claude"
			}
			hostPath := filepath.Join(s.home, "bin", host)
			if err := os.Remove(hostPath); err != nil {
				return err
			}
			if tc.status != "instructions" {
				if err := os.Symlink(s.helper, hostPath); err != nil {
					return err
				}
			}
			callsFile := filepath.Join(s.home, "plugin-calls.jsonl")
			s.env = append(s.env, "MODELPLAN_CONTRACT_PLUGIN_MODE="+tc.name, "MODELPLAN_CONTRACT_PLUGIN_CALLS="+callsFile)
			args := []string{"plugin", "install", tool, "--json"}
			if tc.offline {
				args = append(args, "--offline")
			}
			before, err := tree(s.home)
			if err != nil {
				return err
			}
			name := "plugin-install-" + tool + "-" + tc.name
			if err := s.capture(name, "plugin-install", args, nil, tc.calls == 0, ""); err != nil {
				return err
			}
			entry := s.entries[len(s.entries)-1]
			var result plugininstall.Result
			if err := json.Unmarshal(s.files[entry.File], &result); err != nil {
				return err
			}
			if entry.Encoding != "json" || entry.ExitCode != tc.exit || string(result.Tool) != tool || string(result.Status) != tc.status || result.Completed != tc.completed {
				return fmt.Errorf("%s: wrong binary result exit=%d encoding=%s result=%+v", name, entry.ExitCode, entry.Encoding, result)
			}
			raw, err := os.ReadFile(callsFile)
			if err != nil && !os.IsNotExist(err) {
				return err
			}
			calls := [][]string{}
			for _, line := range bytes.Split(bytes.TrimSpace(raw), []byte{'\n'}) {
				if len(line) == 0 {
					continue
				}
				var argv []string
				if err := json.Unmarshal(line, &argv); err != nil {
					return err
				}
				calls = append(calls, argv)
			}
			if len(calls) != tc.calls || !reflect.DeepEqual(calls, result.Commands[:tc.calls]) {
				return fmt.Errorf("%s: host calls do not match the fixed command prefix: %v", name, calls)
			}
			after, err := tree(s.home)
			if err != nil {
				return err
			}
			delete(after, callsFile) // Only the synthetic host's argv trace may change.
			if !reflect.DeepEqual(before, after) {
				return fmt.Errorf("%s: installer wrote outside the synthetic host trace", name)
			}
			if _, err := os.Stat(filepath.Join(s.home, "cache")); !os.IsNotExist(err) {
				return fmt.Errorf("%s: plugin command created a ModelPlan cache", name)
			}
		}
	}
	return nil
}
