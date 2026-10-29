// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

var runtimeErrorCanaries = []string{
	"sk-SYNTHETIC-RUNTIME-ERROR-5b7d",
	"Authorization: Bearer SYNTHETIC-RUNTIME-BEARER-a19f",
	"/Users/SYNTHETIC-RUNTIME-PATH/.credentials.json",
	"SYNTHETIC-RUNTIME-EMAIL@example.invalid",
}

func assertNoRuntimeCanary(t *testing.T, writer, value string) {
	t.Helper()
	for _, c := range runtimeErrorCanaries {
		if strings.Contains(value, c) {
			t.Errorf("runtime canary reached %s", writer)
		}
	}
}
func assertRuntimeCacheSafe(t *testing.T, cache string) {
	t.Helper()
	if err := filepath.WalkDir(cache, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		b, err := os.ReadFile(path)
		if err == nil {
			assertNoRuntimeCanary(t, "cache file "+filepath.Base(path), string(b))
		}
		return err
	}); err != nil {
		t.Fatal(err)
	}
}

// Only the child is faked. The parent collectors, error returns, cache writers
// and projections stay real. Child stderr is hostile too.
func runtimeErrorChild(t *testing.T, slot int, resultMessage bool, message, success string) string {
	t.Helper()
	quote := func(s string) string { return "'" + strings.ReplaceAll(s, "'", "'\"'\"'") + "'" }
	script := "#!/bin/sh\nprintf '%s\\n' " + quote(message) + " >&2\nwhile IFS= read -r line; do\ncase \"$line\" in\n"
	for id := 1; id <= 3; id++ {
		result := json.RawMessage(`{}`)
		if id == 2 {
			result = json.RawMessage(success)
		}
		reply := map[string]any{"id": id, "result": result}
		if id == slot {
			if resultMessage {
				reply["result"] = map[string]any{"success": false, "message": message}
			} else {
				delete(reply, "result")
				reply["error"] = map[string]any{"code": -32000, "message": message}
			}
		}
		b, err := json.Marshal(reply)
		if err != nil {
			t.Fatal(err)
		}
		script += "*'\"id\":" + strconv.Itoa(id) + ",'*) printf '%s\\n' " + quote(string(b)) + " ;;\n"
	}
	script += "esac\ndone\n"
	bin := filepath.Join(t.TempDir(), "runtime")
	if err := os.WriteFile(bin, []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	return bin
}
func TestCodexRuntimeErrorOutput(t *testing.T) {
	for _, slot := range []int{1, 2, 3} {
		for index, canary := range runtimeErrorCanaries {
			t.Run(strconv.Itoa(slot)+"/"+strconv.Itoa(index), func(t *testing.T) {
				isolateHome(t)
				t.Setenv("MODELPLAN_IDENTITY", "")
				bin := runtimeErrorChild(t, slot, false, canary, acctResponse)
				_, err := askCodex(context.Background(), bin)
				if slot != 3 && err == nil {
					t.Fatal("RPC failure ignored")
				}
				if err != nil {
					assertNoRuntimeCanary(t, "collector error", err.Error())
				}
				cache := t.TempDir()
				err = RefreshCodexAccount(context.Background(), cache, bin, acctNow)
				s := loadAccount(cache)
				if slot == 3 {
					if err != nil || s == nil || s.Status != "ok" || len(s.Windows) != 2 || s.SubscriptionRef != "" {
						t.Fatal("optional identity failure changed quota success")
					}
				} else {
					if err == nil || s == nil || s.Status != "error" || s.Error != "other" {
						t.Error("fixed failure reason not retained")
					}
					if err != nil {
						assertNoRuntimeCanary(t, "returned refresh error", err.Error())
					}
					if AccountDue(cache, acctNow.Add(29*time.Minute)) || !AccountDue(cache, acctNow.Add(30*time.Minute)) {
						t.Error("retry floor changed")
					}
				}
				if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow.Add(time.Minute)); err != nil {
					t.Fatal("not-due refresh failed")
				}
				assertRuntimeCacheSafe(t, cache)
				r := Report{}
				applyAccount(&r, cache, acctNow.Add(time.Minute))
				b, err := json.Marshal(r)
				if err != nil {
					t.Fatal(err)
				}
				assertNoRuntimeCanary(t, "report JSON", string(b))
			})
		}
	}
}
func TestKiroRuntimeErrorOutput(t *testing.T) {
	for name, prefix := range map[string]string{"unknown": "", "signed_out": "not authenticated: ", "old_runtime": "method not found: "} {
		for _, stage := range []int{1, 2, 0} {
			for index, canary := range runtimeErrorCanaries {
				t.Run(name+"/"+strconv.Itoa(stage)+"/"+strconv.Itoa(index), func(t *testing.T) {
					isolateHome(t)
					t.Setenv("MODELPLAN_HISTORY", "off")
					slot := stage
					if slot == 0 {
						slot = 2
					}
					bin := runtimeErrorChild(t, slot, stage == 0, prefix+canary, kiroUsage)
					t.Setenv("MODELPLAN_KIRO", bin)
					e := fetchKiro(context.Background(), nil, "local", "", acctNow)
					want, reason := "other", "other"
					if name == "signed_out" {
						want, reason = "unsupported_login", "Kiro CLI is signed out (kiro-cli login)"
					}
					if name == "old_runtime" {
						want, reason = "schema_changed", "Kiro CLI is too old for its usage call; update it"
					}
					if e.Status != "error" || e.ErrorCode != want || e.Error != reason {
						t.Error("collector lost fixed reason")
					}
					b, err := json.Marshal(e)
					if err != nil {
						t.Fatal(err)
					}
					assertNoRuntimeCanary(t, "native entry JSON", string(b))
					productionConsent(t, "kiro", true)
					cache := t.TempDir()
					p := ProductionPaths(cache, "1.0.0")
					if err := RefreshNative(context.Background(), p, acctNow); err != nil {
						t.Fatal(err)
					}
					s := loadNative(cache)
					if s == nil || len(s.Providers) != 1 || s.Providers[0].Error != want || s.Providers[0].ErrorCode != want {
						t.Fatal("native writer lost fixed failure")
					}
					if err := RefreshNative(context.Background(), p, acctNow.Add(time.Minute)); err != nil {
						t.Fatal(err)
					}
					assertRuntimeCacheSafe(t, cache)
					for label, v := range map[string]any{"retained report JSON": ReadPermitted(p, acctNow.Add(time.Minute)), "diagnostics JSON": ReaderDiagnostics(p, acctNow.Add(time.Minute))} {
						b, err := json.Marshal(v)
						if err != nil {
							t.Fatal(err)
						}
						assertNoRuntimeCanary(t, label, string(b))
					}
				})
			}
		}
	}
}

func TestCodexProcessErrorOutput(t *testing.T) {
	for index, canary := range runtimeErrorCanaries {
		t.Run(strconv.Itoa(index), func(t *testing.T) {
			isolateHome(t)
			cache := t.TempDir()
			// Startup errors can include the whole executable path as well as RPC text.
			bin := filepath.Join(t.TempDir(), canary, "missing-runtime")
			err := RefreshCodexAccount(context.Background(), cache, bin, acctNow)
			if err == nil {
				t.Fatal("missing runtime did not fail")
			}
			assertNoRuntimeCanary(t, "process error return", err.Error())
			s := loadAccount(cache)
			if s == nil || s.Error != "other" {
				t.Fatal("process failure did not retain safe reason")
			}
			assertRuntimeCacheSafe(t, cache)
		})
	}
}

func TestCodexTimeoutKeepsSafeReason(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	bin := filepath.Join(t.TempDir(), "runtime")
	if err := os.WriteFile(bin, []byte("#!/bin/sh\nwhile IFS= read -r line; do :; done\n"), 0700); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	err := RefreshCodexAccount(ctx, cache, bin, acctNow)
	s := loadAccount(cache)
	if err == nil || errorCode(err) != "timeout" || s == nil || s.Status != "error" || s.Error != "timeout" {
		t.Fatal("deadline lost safe timeout reason")
	}
}
