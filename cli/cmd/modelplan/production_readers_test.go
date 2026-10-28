// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/snapshot"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func TestDesktopUsesProductionReaderAndHistoryAdmission(t *testing.T) {
	isolateHome(t)
	for _, name := range []string{"MODELPLAN_GEMINI_HOME", "MODELPLAN_QWEN_HOME", "MODELPLAN_QWEN_USAGE_EXPORT"} {
		t.Setenv(name, "")
	}
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_NATIVE", "")
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("CLAUDE_CONFIG_DIR", "")
	home, _ := os.UserHomeDir()
	cache := filepath.Join(home, "cache")
	t.Setenv("MODELPLAN_CACHE", cache)
	for _, id := range []string{"claude", "amp"} {
		if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, id, true, "native:"+id, "native", time.Now()) }); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.MkdirAll(filepath.Join(home, ".claude"), 0700); err != nil {
		t.Fatal(err)
	}
	at := time.Now().UTC()
	used := 25.0
	reset := at.Add(24 * time.Hour)
	account := quota.Account{Source: "claude-code", Via: "native", ObservedAt: at, Windows: []quota.Window{{Kind: "weekly", UsedPercent: &used, ResetsAt: &reset, WindowMinutes: 10080, ObservedAt: at}}}
	state := map[string]any{"schemaVersion": 1, "provider": "claude", "entries": []any{map[string]any{"profileKey": "synthetic", "status": "ok", "account": account}}}
	file := filepath.Join(cache, "observed", "readers", "claude.json")
	if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
		t.Fatal(err)
	}
	body, _ := json.Marshal(state)
	if err := os.WriteFile(file, body, 0600); err != nil {
		t.Fatal(err)
	}
	ampRoot := filepath.Join(os.Getenv("XDG_DATA_HOME"), "amp", "threads")
	if err := os.MkdirAll(ampRoot, 0700); err != nil {
		t.Fatal(err)
	}
	body = []byte(`{"id":"synthetic","messages":[{"role":"assistant","messageId":1,"usage":{"model":"amp-test","timestamp":"` + at.Format(time.RFC3339) + `","inputTokens":10,"outputTokens":2}}]}`)
	if err := os.WriteFile(filepath.Join(ampRoot, "T-synthetic.json"), body, 0600); err != nil {
		t.Fatal(err)
	}
	localusage.ProductionHistory(home, cache, "amp", false, at)
	if quotaPaths(&store.Store{Dir: cache}).ReaderAccess.Grants["claude"].Generation == "" {
		t.Fatal("CLI quotaPaths omitted production admission")
	}
	old := startDetached
	startDetached = func(...string) error { t.Fatal("read-only desktop started a process"); return nil }
	t.Cleanup(func() { startDetached = old })
	before := tree(t, home)
	var out, stderr bytes.Buffer
	if code := run([]string{"desktop", "--json", "--read-only", "--offline"}, nil, &out, &stderr); code != 0 {
		t.Fatal(code, stderr.String())
	}
	if err := contracttest.ValidateOutput("desktop", out.Bytes()); err != nil {
		t.Fatal(err)
	}
	var got snapshot.Snapshot
	if err := json.Unmarshal(out.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	found := false
	for _, s := range got.Sources {
		if s.Source == "native:claude" && s.Status == "ok" {
			found = true
		}
	}
	if !found || len(got.LocalHistory) != 1 || len(got.LocalHistory[0].Rows) != 1 {
		t.Fatal("desktop lost native/history production state", out.String())
	}
	if !reflect.DeepEqual(before, tree(t, home)) {
		t.Fatal("read-only feed wrote files")
	}
}

func TestConnectConfiguredGLMProfilePreviewAndConsent(t *testing.T) {
	isolateHome(t)
	for _, name := range []string{"MODELPLAN_GEMINI_HOME", "MODELPLAN_QWEN_HOME", "MODELPLAN_QWEN_USAGE_EXPORT"} {
		t.Setenv(name, "")
	}
	t.Setenv("MODELPLAN_READERS", "")
	cache := t.TempDir()
	t.Setenv("MODELPLAN_CACHE", cache)
	var out, stderr bytes.Buffer
	args := []string{"connect", "zai", "--profile", "claude-code", "--json"}
	if code := run(args, nil, &out, &stderr); code != 0 || !strings.Contains(out.String(), `"profile": "claude-code"`) {
		t.Fatal(code, out.String(), stderr.String())
	}
	if _, err := os.Stat(consent.Path()); !os.IsNotExist(err) {
		t.Fatal("JSON preview saved consent")
	}
	out.Reset()
	if code := run([]string{"connect", "zai", "--profile", "claude-code"}, strings.NewReader("y\n"), &out, &stderr); code != 0 {
		t.Fatal(code, out.String(), stderr.String())
	}
	state, err := consent.Load(consent.Path())
	if err != nil || len(state.Tools["zai"].Profiles) != 1 || state.Tools["zai"].Profiles[0] != "claude-code" {
		t.Fatal("local source selection missing", state, err)
	}
}
