// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/render"
	"github.com/modelplan/modelplan/cli/internal/store"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

func paceWarningFixture(t *testing.T, at time.Time, source string) (*store.Store, quota.Report) {
	t.Helper()
	st := effortTestCache(t, at)
	t.Setenv("MODELPLAN_EFFORT_SUGGESTION", "off")
	t.Setenv("MODELPLAN_READERS", "passive")
	t.Setenv("MODELPLAN_TASK_BRIEF", "")
	t.Setenv("ANTHROPIC_BASE_URL", "")
	dev := "anthropic"
	if source == "codex" {
		dev = "openai"
	}
	f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
		var synthetic map[string]json.RawMessage
		if err := json.Unmarshal([]byte(strings.ReplaceAll(strings.ReplaceAll(contracttest.Client, "synthetic-dev", dev), `"status":"frontier"`, `"status":""`)), &synthetic); err != nil {
			t.Fatal(err)
		}
		doc["data"] = synthetic["data"]
	})
	if err := st.PutObject(f.objectHash, f.object); err != nil {
		t.Fatal(err)
	}
	if err := st.PutManifest(f.id, f.manifest); err != nil {
		t.Fatal(err)
	}
	if err := st.SaveState(store.State{PublicationID: f.id, ManifestHash: publicationHash(f.manifest), Component: "client", ComponentHash: f.objectHash}); err != nil {
		t.Fatal(err)
	}
	reset := at.Add(time.Duration(float64(7*24*time.Hour) * .6)).Unix()
	var lines []string
	var latest quota.StatuslineInput
	for _, reading := range []struct {
		at   time.Time
		used float64
	}{{at.Add(-24*time.Hour - 10*time.Minute), 39.8}, {at.Add(-24 * time.Hour), 40}, {at.Add(-24*time.Hour + 10*time.Minute), 40.2}, {at, 60}} {
		if source == "claude-code" {
			var in quota.StatuslineInput
			raw := fmt.Sprintf(`{"session_id":"pace-thread","model":{"id":"native-z"},"effort":{"level":"medium"},"rate_limits":{"seven_day":{"used_percentage":%g,"resets_at":%d}}}`, reading.used, reset)
			if err := json.Unmarshal([]byte(raw), &in); err != nil {
				t.Fatal(err)
			}
			if err := quota.RecordClaudeCode(st.Dir, in, reading.at); err != nil {
				t.Fatal(err)
			}
			latest = in
		} else {
			raw := map[string]any{"timestamp": reading.at, "type": "event_msg", "payload": map[string]any{"type": "token_count", "rate_limits": map[string]any{"plan_type": "synthetic-plan", "secondary": map[string]any{"used_percent": reading.used, "window_minutes": 10080, "resets_at": reset}}}}
			lines = append(lines, string(publicationJSON(t, raw)))
		}
	}
	if source == "codex" {
		root := filepath.Join(os.Getenv("HOME"), ".codex")
		t.Setenv("CODEX_HOME", root)
		dir := filepath.Join(root, "sessions", at.Format("2006/01/02"))
		if err := os.MkdirAll(dir, 0700); err != nil {
			t.Fatal(err)
		}
		path := filepath.Join(dir, "rollout-pace-thread.jsonl")
		if err := os.WriteFile(path, []byte(strings.Join(lines, "\n")+"\n"), 0600); err != nil {
			t.Fatal(err)
		}
		if err := os.Chtimes(path, at, at); err != nil {
			t.Fatal(err)
		}
	} else {
		a := latest.Account(at)
		quota.AttachRecent(st.Dir, &a)
		quota.Evaluate(&a, at)
		return st, quota.Report{Accounts: []quota.Account{a}}
	}
	return st, quota.ReadPermitted(quotaPaths(st), at)
}

func TestPaceWarningHookIsUserOnlyAndOncePerWindow(t *testing.T) {
	for _, source := range []string{"claude-code", "codex"} {
		for _, lang := range []string{"en", "zh"} {
			t.Run(source+"/"+lang, func(t *testing.T) {
				at := time.Now().UTC().Truncate(time.Second)
				st, _ := paceWarningFixture(t, at, source)
				style, marker := render.Style{T: render.EN}, "last-24h rate"
				if lang == "zh" {
					style.T = render.ZH
					marker = "按最近 24 小时的速度"
				}
				for attempt := 0; attempt < 2; attempt++ {
					var out bytes.Buffer
					input := `{"session_id":"pace-thread","model":"native-z"}`
					if code := adviseHookAt(strings.NewReader(input), &out, style, st, nil, common{offline: true}, source, "", "", at); code != 0 {
						t.Fatal(code)
					}
					var got struct {
						System string `json:"systemMessage"`
						Hook   struct {
							Context string `json:"additionalContext"`
						} `json:"hookSpecificOutput"`
					}
					if out.Len() > 0 {
						if err := json.Unmarshal(out.Bytes(), &got); err != nil {
							t.Fatal(err, out.String())
						}
					}
					if strings.Contains(got.System, marker) != (attempt == 0) {
						t.Fatal("wrong user warning", out.String())
					}
					if strings.Contains(got.Hook.Context, marker) || strings.Contains(got.Hook.Context, "window_pace_warning") || strings.Contains(got.Hook.Context, "last-24h") {
						t.Fatal("pace warning leaked to model", out.String())
					}
					if attempt == 0 && !strings.Contains(got.Hook.Context, "ModelPlan task-start brief") {
						t.Fatal("must exercise a real model brief", out.String())
					}
				}
			})
		}
	}
}

func TestPaceWarningStatuslineSharesHookClaim(t *testing.T) {
	for _, first := range []string{"statusline", "hook"} {
		t.Run(first, func(t *testing.T) {
			at := time.Now().UTC().Truncate(time.Second)
			st, report := paceWarningFixture(t, at, "claude-code")
			style := render.Style{T: render.EN}
			if first == "hook" {
				var out bytes.Buffer
				adviseHookAt(strings.NewReader(`{"session_id":"pace-thread"}`), &out, style, st, nil, common{offline: true}, "claude-code", "", "", at)
				if !strings.Contains(out.String(), "last-24h rate") {
					t.Fatal(out.String())
				}
			}
			hint := statuslineHint(style, st, mustEffortDigest(t), report, at, true)
			if strings.Contains(hint, "last-24h rate") != (first == "statusline") {
				t.Fatal(hint)
			}
			if strings.Contains(statuslineHint(style, st, mustEffortDigest(t), report, at, true), "last-24h rate") {
				t.Fatal("repeated status-line pace warning")
			}
			var out bytes.Buffer
			adviseHookAt(strings.NewReader(`{"session_id":"another-thread"}`), &out, style, st, nil, common{offline: true}, "claude-code", "", "", at)
			if strings.Contains(out.String(), "last-24h rate") {
				t.Fatal("hook repeated status-line warning", out.String())
			}
		})
	}
}

func TestPaceWarningNormalTextClaimsOnce(t *testing.T) {
	at := time.Now().UTC().Truncate(time.Second)
	paceWarningFixture(t, at, "claude-code")
	for attempt := 0; attempt < 2; attempt++ {
		code, out, err := commandRun("advise", "--offline", "--lang", "en")
		if code != 0 || strings.Contains(out, "last-24h rate") != (attempt == 0) {
			t.Fatal(code, out, err)
		}
	}
}

func TestPaceWarningFullStatusline(t *testing.T) {
	for _, lang := range []string{"en", "zh"} {
		t.Run(lang, func(t *testing.T) {
			at := time.Now().UTC().Truncate(time.Second)
			paceWarningFixture(t, at, "claude-code")
			reset := at.Add(time.Duration(float64(7*24*time.Hour) * .6)).Unix()
			input := fmt.Sprintf(`{"model":{"id":"native-z"},"effort":{"level":"medium"},"rate_limits":{"seven_day":{"used_percentage":60,"resets_at":%d}}}`, reset)
			marker := "last-24h rate"
			if lang == "zh" {
				marker = "按最近 24 小时的速度"
			}
			for attempt := 0; attempt < 2; attempt++ {
				var out, stderr bytes.Buffer
				code := run([]string{"statusline", "--offline", "--lang", lang}, strings.NewReader(input), &out, &stderr)
				if code != 0 || strings.Contains(out.String(), marker) != (attempt == 0) {
					t.Fatal(code, out.String(), stderr.String())
				}
			}
		})
	}
}

func TestPaceWarningConcurrentHookStatuslineClaim(t *testing.T) {
	at := time.Now().UTC().Truncate(time.Second)
	st, report := paceWarningFixture(t, at, "claude-code")
	style := render.Style{T: render.EN}
	d := mustEffortDigest(t)
	lock := filepath.Join(st.Dir, "observed", "pace-warning.lock")
	if err := os.WriteFile(lock, nil, 0600); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Remove(lock) })
	for _, busy := range []bool{true, false} {
		if !busy {
			if err := os.Remove(lock); err != nil {
				t.Fatal(err)
			}
		}
		var hook bytes.Buffer
		var hint string
		var code int
		var wg sync.WaitGroup
		start := make(chan struct{})
		wg.Add(2)
		go func() {
			defer wg.Done()
			<-start
			code = adviseHookAt(strings.NewReader(`{"session_id":"pace-thread"}`), &hook, style, st, nil, common{offline: true}, "claude-code", "", "", at)
		}()
		go func() {
			defer wg.Done()
			<-start
			hint = statuslineHint(style, st, d, report, at, true)
		}()
		close(start)
		wg.Wait()
		count := strings.Count(hook.String(), "last-24h rate") + strings.Count(hint, "last-24h rate")
		want := 1
		if busy {
			want = 0
		}
		if code != 0 || count != want {
			t.Fatalf("busy=%v notices=%d want=%d code=%d hook=%s hint=%s", busy, count, want, code, hook.String(), hint)
		}
	}
}
