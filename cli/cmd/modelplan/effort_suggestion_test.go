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

	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/history"
	"github.com/modelplan/modelplan/cli/internal/render"
	"github.com/modelplan/modelplan/cli/internal/snapshot"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func effortTestCache(t *testing.T, at time.Time) *store.Store {
	t.Helper()
	isolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("MODELPLAN_EFFORT_SUGGESTION", "")
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	t.Setenv("MODELPLAN_CODEXBAR", "off")
	st := &store.Store{Dir: t.TempDir()}
	t.Setenv("MODELPLAN_CACHE", st.Dir)
	f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
		var v map[string]json.RawMessage
		_ = json.Unmarshal([]byte(contracttest.Client), &v)
		doc["data"] = v["data"]
	})
	if err := os.MkdirAll(filepath.Join(st.Dir, "objects"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(st.ManifestPath(f.id)), 0700); err != nil {
		t.Fatal(err)
	}
	if err := st.PutObject(f.objectHash, f.object); err != nil {
		t.Fatal(err)
	}
	if err := st.PutManifest(f.id, f.manifest); err != nil {
		t.Fatal(err)
	}
	if err := st.SaveState(store.State{PublicationID: f.id, ManifestHash: publicationHash(f.manifest), Component: "client", ComponentHash: f.objectHash}); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(history.Path(st.Dir)), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(history.Path(st.Dir), publicationJSON(t, contracttest.EffortLedger(at, "medium", false, 40, 45, 50)), 0600); err != nil {
		t.Fatal(err)
	}
	original := startDetached
	startDetached = func(...string) error { t.Fatal("unexpected subprocess"); return nil }
	t.Cleanup(func() { startDetached = original })
	return st
}

func TestEffortSuggestionHookIsUserOnly(t *testing.T) {
	for _, harness := range []string{"codex", "claude-code"} {
		for _, brief := range []string{"", "off"} {
			for _, lang := range []string{"en", "zh"} {
				t.Run(harness+"/"+brief+"/"+lang, func(t *testing.T) {
					at := contracttest.Now
					st := effortTestCache(t, at)
					t.Setenv("MODELPLAN_TASK_BRIEF", brief)
					style := render.Style{T: render.EN}
					needle := "past 3 weeks averaged 45%"
					if lang == "zh" {
						style.T = render.ZH
						needle = "过去 3 周平均用了 45%"
					}
					for i := 0; i < 2; i++ {
						var out bytes.Buffer
						adviseHookAt(strings.NewReader(`{"session_id":"synthetic-thread","model":"native-z"}`), &out, style, st, nil, common{offline: true}, harness, "existing user notice", "Synthetic public agent context.", at)
						var result struct {
							System string `json:"systemMessage"`
							Hook   struct {
								Context string `json:"additionalContext"`
							} `json:"hookSpecificOutput"`
						}
						if err := json.Unmarshal(out.Bytes(), &result); err != nil {
							t.Fatal(err, out.String())
						}
						if strings.Contains(result.Hook.Context, needle) || strings.Contains(result.Hook.Context, "effortSuggestion") || strings.Contains(result.Hook.Context, "past 3 weeks") || strings.Contains(result.Hook.Context, "过去 3 周") {
							t.Fatalf("personal suggestion leaked to model: %s", out.String())
						}
						if strings.Contains(result.System, needle) != (i == 0) {
							t.Fatalf("wrong user notification/throttle: %s", out.String())
						}
						if !strings.Contains(result.Hook.Context, "Synthetic public agent context.") {
							t.Fatal("test must cover real agent context too")
						}
					}
				})
			}
		}
	}
}

func TestEffortSuggestionDesktopReadOnlyAndHistory(t *testing.T) {
	st := effortTestCache(t, time.Now())
	before := tree(t, st.Dir)
	var out, stderr bytes.Buffer
	if code := run([]string{"desktop", "--json", "--read-only", "--offline", "--lang", "en"}, nil, &out, &stderr); code != 0 {
		t.Fatal(code, stderr.String())
	}
	if err := contracttest.ValidateOutput("desktop", out.Bytes()); err != nil {
		t.Fatal(err)
	}
	var got snapshot.Snapshot
	if err := json.Unmarshal(out.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if got.ContractVersion != 1 || got.EffortSuggestion == nil || !strings.Contains(got.EffortSuggestion.Message, "past 3 weeks averaged 45%") {
		t.Fatalf("desktop suggestion missing: %s", out.String())
	}
	if !reflect.DeepEqual(before, tree(t, st.Dir)) {
		t.Fatal("read-only desktop wrote local state")
	}
	out.Reset()
	if code := run([]string{"history", "--offline", "--lang", "en"}, nil, &out, &stderr); code != 0 || !strings.Contains(out.String(), "Default effort suggestion (local only)") {
		t.Fatal(code, out.String(), stderr.String())
	}
	out.Reset()
	if code := run([]string{"history", "--json", "--offline"}, nil, &out, &stderr); code != 0 || strings.Contains(out.String(), "effortSuggestion") || strings.Contains(out.String(), "past 3 weeks") {
		t.Fatal("plugin measurement feed gained private derived advice", code, out.String())
	}
	out.Reset()
	if code := run([]string{"history", "--effort-suggestion", "off", "--json"}, nil, &out, &stderr); code != 0 {
		t.Fatal(code, stderr.String())
	}
	if history.ReadEffortSuggestion(st.Dir, mustEffortDigest(t), time.Now()).Suggestion != nil {
		t.Fatal("CLI off did not persist")
	}
}

func mustEffortDigest(t *testing.T) *digest.Digest {
	t.Helper()
	d, err := contracttest.Public()
	if err != nil {
		t.Fatal(err)
	}
	return d
}
