// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/store"
)

func TestRuntimeErrorsStayOutOfCLIJSONAndLogs(t *testing.T) {
	canaries := []string{"sk-SYNTHETIC-CLI-ERROR-f91d", "Authorization: Bearer SYNTHETIC-CLI-BEARER-c5ab", "/Users/SYNTHETIC-CLI-PATH/private.json", "SYNTHETIC-CLI-EMAIL@example.invalid"}
	for _, provider := range []string{"codex", "kiro"} {
		for _, stage := range []int{1, 2, 3, 0} {
			if provider == "kiro" && stage == 3 || provider == "codex" && stage == 0 {
				continue
			}
			t.Run(provider+"/"+strconv.Itoa(stage), func(t *testing.T) {
				home := nativeRefreshHome(t)
				t.Setenv("MODELPLAN_IDENTITY", "")
				message := strings.Join(canaries, " | ")
				quote := func(s string) string { return "'" + strings.ReplaceAll(s, "'", "'\"'\"'") + "'" }
				script := "#!/bin/sh\nprintf '%s\\n' " + quote(message) + " >&2\nwhile IFS= read -r line; do\ncase \"$line\" in\n"
				for id := 1; id <= 3; id++ {
					result := json.RawMessage(`{}`)
					if provider == "codex" && id == 2 {
						result = json.RawMessage(`{"rateLimits":{"primary":{"usedPercent":12,"windowDurationMins":300}}}`)
					}
					reply := map[string]any{"id": id, "result": result}
					if stage == id {
						delete(reply, "result")
						reply["error"] = map[string]any{"code": -32000, "message": message}
					}
					if stage == 0 && id == 2 {
						reply["result"] = map[string]any{"success": false, "message": message}
					}
					b, err := json.Marshal(reply)
					if err != nil {
						t.Fatal(err)
					}
					script += "*'\"id\":" + strconv.Itoa(id) + ",'*) printf '%s\\n' " + quote(string(b)) + " ;;\n"
				}
				script += "esac\ndone\n"
				bin := filepath.Join(home, "bin", provider)
				if provider == "kiro" {
					bin += "-cli"
				}
				if err := os.MkdirAll(filepath.Dir(bin), 0700); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(bin, []byte(script), 0700); err != nil {
					t.Fatal(err)
				}
				t.Setenv("MODELPLAN_"+strings.ToUpper(provider), bin)
				grantConsentAPI(t, apiRequest(t, 1, 0, []string{provider}, nil, nil))
				st, err := store.Locate()
				if err != nil {
					t.Fatal(err)
				}
				assertSafe := func(writer, value string) {
					t.Helper()
					for _, canary := range canaries {
						if strings.Contains(value, canary) {
							t.Errorf("runtime canary reached %s", writer)
						}
					}
				}
				// The real CLI stderr writer also serves callers that retain a process log.
				logPath := filepath.Join(st.Dir, "runtime-error-test.log")
				logFile, err := os.Create(logPath)
				if err != nil {
					t.Fatal(err)
				}
				var out bytes.Buffer
				args := []string{"quota", "--refresh-account", "--json", "--offline"}
				if provider == "kiro" {
					args = []string{"connections", "refresh", "--json"}
				}
				code := run(args, strings.NewReader(""), &out, logFile)
				if err := logFile.Close(); err != nil {
					t.Fatal(err)
				}
				if code != 0 || !json.Valid(out.Bytes()) {
					t.Fatal("refresh did not produce JSON")
				}
				assertSafe("refresh JSON", out.String())
				logged, err := os.ReadFile(logPath)
				if err != nil {
					t.Fatal(err)
				}
				assertSafe("CLI stderr/process log", string(logged))
				if provider == "codex" && stage != 3 && !strings.Contains(string(logged), "codex account: other") {
					t.Error("CLI did not report the fixed failure")
				}
				capture := "codex-account.json"
				if provider == "kiro" {
					capture = "native.json"
				}
				retained, err := os.ReadFile(filepath.Join(st.Dir, "observed", capture))
				if err != nil {
					t.Fatal(err)
				}
				if stage != 3 && !bytes.Contains(retained, []byte(`"error": "other"`)) {
					t.Error("expected retained safe failure missing")
				}
				for _, args := range [][]string{
					{"quota", "--json", "--offline"},
					{"desktop", "--json", "--offline"},
					{"doctor", "readers", "--json", "--offline"},
					{"connections", "--json", "--offline"},
					{"doctor", "--share", "--json", "--offline"},
				} {
					code, out, stderr := consentRun(args, "")
					if code != 0 || !json.Valid([]byte(out)) {
						t.Fatal("JSON view failed: " + strings.Join(args, " "))
					}
					assertSafe(strings.Join(args, " ")+" stdout", out)
					assertSafe(strings.Join(args, " ")+" stderr", stderr)
				}
				if err := filepath.WalkDir(st.Dir, func(path string, d fs.DirEntry, err error) error {
					if err != nil || d.IsDir() {
						return err
					}
					b, err := os.ReadFile(path)
					if err == nil {
						assertSafe("retained file "+filepath.Base(path), string(b))
					}
					return err
				}); err != nil {
					t.Fatal(err)
				}
			})
		}
	}
}
