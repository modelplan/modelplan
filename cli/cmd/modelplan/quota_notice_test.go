package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/advise"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/render"
	"github.com/modelplan/modelplan/cli/internal/store"
)

type quotaHookTest struct {
	t       *testing.T
	st      *store.Store
	harness string
	style   render.Style
}

func newQuotaHookTest(t *testing.T, harness, lang string) quotaHookTest {
	t.Helper()
	isolateHome(t) // t.TempDir homes, with the shared Go caches from internal/testenv
	t.Setenv("MODELPLAN_TASK_BRIEF", "")
	t.Setenv("MODELPLAN_HISTORY", "off")
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	t.Setenv("MODELPLAN_CODEXBAR", "off")
	t.Setenv("ANTHROPIC_BASE_URL", "")
	t.Setenv("CODEX_THREAD_ID", "")
	t.Setenv("CLAUDE_CODE_SESSION_ID", "")
	original := startDetached
	startDetached = func(...string) error { t.Error("unexpected background refresh"); return nil }
	t.Cleanup(func() { startDetached = original })
	style := render.Style{T: render.ZH}
	if lang == "en" {
		style.T = render.EN
	}
	return quotaHookTest{t, &store.Store{Dir: t.TempDir()}, harness, style}
}

func (h quotaHookTest) reading(source string, observed time.Time, windows ...quota.Window) {
	h.t.Helper()
	for i := range windows {
		if windows[i].ObservedAt.IsZero() {
			windows[i].ObservedAt = observed
		}
	}
	var name string
	var data any
	if source == "claude-code" {
		name = "claude-code.json"
		data = map[string]any{"schemaVersion": 1, "observedAt": observed, "windows": windows}
	} else {
		name = "codex-account.json"
		data = map[string]any{"schemaVersion": 1, "status": "ok", "observedAt": observed, "windows": windows}
	}
	p := filepath.Join(h.st.Dir, "observed", name)
	if err := os.MkdirAll(filepath.Dir(p), 0700); err != nil {
		h.t.Fatal(err)
	}
	if err := os.WriteFile(p, publicationJSON(h.t, data), 0600); err != nil {
		h.t.Fatal(err)
	}
}

func (h quotaHookTest) prompt(thread string, now time.Time) string {
	h.t.Helper()
	var out bytes.Buffer
	input := publicationJSON(h.t, map[string]string{"session_id": thread, "model": "native-z"})
	if code := adviseHookAt(bytes.NewReader(input), &out, h.style, h.st, nil, common{offline: true}, h.harness, "user-only", "", now); code != 0 {
		h.t.Fatalf("hook exit %d", code)
	}
	var result struct {
		System string `json:"systemMessage"`
		Hook   struct {
			Event   string `json:"hookEventName"`
			Context string `json:"additionalContext"`
		} `json:"hookSpecificOutput"`
	}
	if err := json.Unmarshal(out.Bytes(), &result); err != nil {
		h.t.Fatalf("hook output %s: %v", out.String(), err)
	}
	if !strings.HasPrefix(result.System, "user-only") || strings.Contains(result.Hook.Context, "user-only") {
		h.t.Fatalf("user/model split lost: %s", out.String())
	}
	if result.Hook.Context != "" && result.Hook.Event != "UserPromptSubmit" {
		h.t.Fatalf("wrong hook event: %s", out.String())
	}
	return result.Hook.Context
}

func hookWindow(kind string, remaining float64, reset time.Time) quota.Window {
	used := 100 - remaining
	return quota.Window{Kind: kind, UsedPercent: &used, ResetsAt: &reset, ResetMode: "fixed"}
}

func TestHookQuotaThresholdsAndRecovery(t *testing.T) {
	for _, harness := range []string{"claude-code", "codex"} {
		for _, lang := range []string{"en", "zh"} {
			t.Run(harness+"/"+lang, func(t *testing.T) {
				h := newQuotaHookTest(t, harness, lang)
				now := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)
				reset := now.Add(time.Hour)
				read := func(left float64) {
					h.reading(harness, now, hookWindow("five_hour", left, reset), hookWindow("weekly", left, reset))
				}
				for _, left := range []float64{90, 15} {
					read(left)
					if got := h.prompt("thread", now); got != "" {
						t.Fatalf("%g%% triggered: %s", left, got)
					}
				}
				read(12)
				want := "5-hour quota: 12% left, resets in 1h.\n\nWeekly quota: 12% left, resets in 1h."
				if lang == "zh" {
					want = "5小时额度：剩余12%，1时后重置。\n\n每周额度：剩余12%，1时后重置。"
				}
				if got := h.prompt("thread", now); got != want {
					t.Fatalf("low notice:\ngot %s\nwant %s", got, want)
				}
				for _, left := range []float64{12, 0, 90, 12} {
					read(left)
					if got := h.prompt("thread", now); got != "" {
						t.Fatalf("repeat/correction at %g%%: %s", left, got)
					}
				}
				if got := h.prompt("other-thread", now); got != want {
					t.Fatalf("new thread: %s", got)
				}
				// An old reading cannot prove a reset just because the boundary passed.
				now = reset.Add(time.Minute)
				if got := h.prompt("thread", now); got != "" {
					t.Fatalf("expired reading triggered reset: %s", got)
				}
				reset = now.Add(5 * time.Hour)
				read(50)
				if got := h.prompt("thread", now); got != "" {
					t.Fatalf("50%% triggered reset: %s", got)
				}
				read(96)
				want = "5-hour window reset: 96% left, resets in 5h.\n\nWeekly window reset: 96% left, resets in 5h."
				if lang == "zh" {
					want = "5小时窗口已重置：剩余96%，5时后重置。\n\n每周窗口已重置：剩余96%，5时后重置。"
				}
				if got := h.prompt("thread", now); got != want {
					t.Fatalf("recovery:\ngot %s\nwant %s", got, want)
				}
				if got := h.prompt("thread", now); got != "" {
					t.Fatalf("repeat recovery: %s", got)
				}
				if got := h.prompt("never-low-thread", now); got != "" {
					t.Fatalf("recovery without prior low: %s", got)
				}
				// A later cycle still cannot repeat either line within the same thread.
				read(12)
				if got := h.prompt("thread", now); got != "" {
					t.Fatalf("second low cycle: %s", got)
				}
				now = reset.Add(time.Minute)
				reset = now.Add(5 * time.Hour)
				read(96)
				if got := h.prompt("thread", now); got != "" {
					t.Fatalf("second recovery cycle: %s", got)
				}
			})
		}
	}
}

func TestHookQuotaUnknownStaleOffAndOwnHarness(t *testing.T) {
	for _, harness := range []string{"claude-code", "codex"} {
		t.Run(harness, func(t *testing.T) {
			h := newQuotaHookTest(t, harness, "en")
			now := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)
			reset := now.Add(3*24*time.Hour + 4*time.Hour)
			for _, tc := range []struct {
				name   string
				age    time.Duration
				change func(*quota.Window)
			}{
				{"unknown", 0, func(w *quota.Window) { w.UsedPercent = nil }},
				{"missing reset", 0, func(w *quota.Window) { w.ResetsAt = nil }},
				{"stale account", 61 * time.Minute, func(w *quota.Window) {}},
				{"stale window", 0, func(w *quota.Window) { w.ObservedAt = now.Add(-61 * time.Minute) }},
				{"future", 0, func(w *quota.Window) { w.ObservedAt = now.Add(time.Minute) }},
				{"other kind", 0, func(w *quota.Window) { w.Kind = "monthly" }},
			} {
				w := hookWindow("weekly", 12, reset)
				tc.change(&w)
				h.reading(harness, now.Add(-tc.age), w)
				if got := h.prompt("thread", now); got != "" {
					t.Fatalf("%s: %s", tc.name, got)
				}
			}
			h.reading(harness, now) // no own windows
			other := "codex"
			if harness == other {
				other = "claude-code"
			}
			h.reading(other, now, hookWindow("weekly", 12, reset))
			if got := h.prompt("thread", now); got != "" {
				t.Fatalf("another harness's quota: %s", got)
			}
			h.reading(harness, now, hookWindow("weekly", 12, reset))
			if got := h.prompt("", now); got != "" {
				t.Fatalf("missing thread: %s", got)
			}
			t.Setenv("MODELPLAN_TASK_BRIEF", "off")
			if got := h.prompt("thread", now); got != "" {
				t.Fatalf("brief off: %s", got)
			}
			t.Setenv("MODELPLAN_TASK_BRIEF", "")
			if got := h.prompt("thread", now); got != "Weekly quota: 12% left, resets in 3d4h." {
				t.Fatalf("unknown/stale/off consumed the notice: %s", got)
			}
			// A stale high reading cannot consume recovery; a fresh one can.
			now = reset.Add(time.Minute)
			reset = now.Add(7 * 24 * time.Hour)
			h.reading(harness, now.Add(-61*time.Minute), hookWindow("weekly", 96, reset))
			if got := h.prompt("thread", now); got != "" {
				t.Fatalf("stale recovery: %s", got)
			}
			h.reading(harness, now, hookWindow("weekly", 96, reset))
			t.Setenv("MODELPLAN_TASK_BRIEF", "off")
			if got := h.prompt("thread", now); got != "" {
				t.Fatalf("recovery with brief off: %s", got)
			}
			t.Setenv("MODELPLAN_TASK_BRIEF", "")
			if got := h.prompt("thread", now); got != "Weekly window reset: 96% left, resets in 7d." {
				t.Fatalf("fresh recovery: %s", got)
			}
		})
	}
}

func TestHookQuotaDoesNotConsumeMissingBrief(t *testing.T) {
	h := newQuotaHookTest(t, "codex", "en")
	now := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)
	h.reading("codex", now, hookWindow("weekly", 12, now.Add(3*24*time.Hour)))
	if got := h.prompt("thread", now); got != "Weekly quota: 12% left, resets in 3d." {
		t.Fatal(got)
	}
	// Supply a synthetic verified publication later, without a network request.
	f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
		data := strings.ReplaceAll(string(doc["data"]), "z-dev", "openai")
		data = strings.ReplaceAll(data, `"status":"incomplete"`, `"status":""`)
		doc["data"] = json.RawMessage(data)
	})
	if err := os.MkdirAll(filepath.Join(h.st.Dir, "objects"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := h.st.PutObject(f.objectHash, f.object); err != nil {
		t.Fatal(err)
	}
	p := h.st.ManifestPath(f.id)
	if err := os.MkdirAll(filepath.Dir(p), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, f.manifest, 0600); err != nil {
		t.Fatal(err)
	}
	if err := h.st.SaveState(store.State{PublicationID: f.id, ManifestHash: publicationHash(f.manifest), Component: "client", ComponentHash: f.objectHash}); err != nil {
		t.Fatal(err)
	}
	if got := h.prompt("thread", now); !strings.HasPrefix(got, "Model Plan task-start brief") || strings.Contains(got, "12%") {
		t.Fatalf("late brief: %s", got)
	}
	if got := h.prompt("thread", now); got != "" {
		t.Fatalf("repeated brief: %s", got)
	}
	// With a publication already cached, the factual line appends to the first brief.
	t.Setenv("MODELPLAN_TASK_BRIEF", "off")
	if got := h.prompt("cached-thread", now); got != "" {
		t.Fatalf("cached brief off: %s", got)
	}
	t.Setenv("MODELPLAN_TASK_BRIEF", "")
	if got := h.prompt("cached-thread", now); !strings.HasPrefix(got, "Model Plan task-start brief") || !strings.HasSuffix(got, "\n\nWeekly quota: 12% left, resets in 3d.") {
		t.Fatalf("brief plus factual line: %s", got)
	}
	if got := h.prompt("cached-thread", now); got != "" {
		t.Fatalf("repeated brief/line: %s", got)
	}
	// Notices and briefs remain separate state, with the same expiry.
	s := advise.Load(h.st.Dir)
	if len(s.Briefs) != 2 || len(s.Quotas) != 2 {
		t.Fatalf("state = %+v", s)
	}
}
