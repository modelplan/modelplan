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
				reset5, resetW := now.Add(3*time.Hour), now.Add(72*time.Hour)
				read := func(left float64) {
					h.reading(harness, now, hookWindow("five_hour", left, reset5), hookWindow("weekly", left, resetW))
				}
				line := func(en, zh string) string {
					if lang == "zh" {
						return zh
					}
					return en
				}
				for _, left := range []float64{90, 25} {
					read(left)
					if got := h.prompt("thread", now); got != "" {
						t.Fatalf("%g%% triggered: %s", left, got)
					}
				}
				read(18)
				want := line("5-hour quota: 18% left, resets in 3h.\n\nWeekly quota: 18% left, resets in 3d.",
					"5小时额度：剩余18%，3时后重置。\n\n每周额度：剩余18%，3天后重置。")
				if got := h.prompt("thread", now); got != want {
					t.Fatalf("20%% notice:\ngot %s\nwant %s", got, want)
				}
				for _, left := range []float64{18, 12, 90, 15} {
					read(left)
					if got := h.prompt("thread", now); got != "" {
						t.Fatalf("repeat/correction at %g%%: %s", left, got)
					}
				}
				read(8)
				want = line("5-hour quota: 8% left, resets in 3h.\n\nWeekly quota: 8% left, resets in 3d.",
					"5小时额度：剩余8%，3时后重置。\n\n每周额度：剩余8%，3天后重置。")
				if got := h.prompt("thread", now); got != want {
					t.Fatalf("10%% notice:\ngot %s\nwant %s", got, want)
				}
				if got := h.prompt("other-thread", now); got != want {
					t.Fatalf("new thread: %s", got)
				}
				// An old reading cannot prove a reset just because the boundary passed.
				now = reset5.Add(time.Minute)
				if got := h.prompt("thread", now); got != "" {
					t.Fatalf("expired reading triggered reset: %s", got)
				}
				reset5 = now.Add(5 * time.Hour)
				read(50)
				if got := h.prompt("thread", now); got != "" {
					t.Fatalf("50%% triggered reset: %s", got)
				}
				read(96)
				want = line("5-hour window reset: 96% left, resets in 5h.", "5小时窗口已重置：剩余96%，5时后重置。")
				if got := h.prompt("thread", now); got != want {
					t.Fatalf("recovery:\ngot %s\nwant %s", got, want)
				}
				if got := h.prompt("thread", now); got != "" {
					t.Fatalf("repeat recovery: %s", got)
				}
				if got := h.prompt("never-low-thread", now); got != "" {
					t.Fatalf("recovery without prior low: %s", got)
				}
				// A new cycle starts the thresholds over; the weekly cycle has had its 20% line.
				read(12)
				want = line("5-hour quota: 12% left, resets in 5h.", "5小时额度：剩余12%，5时后重置。")
				if got := h.prompt("thread", now); got != want {
					t.Fatalf("second cycle:\ngot %s\nwant %s", got, want)
				}
			})
		}
	}
}

func (h quotaHookTest) sessionStart(thread, source string, now time.Time) string {
	h.t.Helper()
	var out bytes.Buffer
	input := publicationJSON(h.t, map[string]string{"session_id": thread, "hook_event_name": "SessionStart", "source": source})
	if code := adviseHookAt(bytes.NewReader(input), &out, h.style, h.st, nil, common{offline: true}, h.harness, "user-only", "", now); code != 0 {
		h.t.Fatalf("hook exit %d", code)
	}
	if out.Len() == 0 {
		return ""
	}
	var result map[string]any
	if err := json.Unmarshal(out.Bytes(), &result); err != nil {
		h.t.Fatalf("hook output %s: %v", out.String(), err)
	}
	hook, _ := result["hookSpecificOutput"].(map[string]any)
	if len(result) != 1 || hook["hookEventName"] != "SessionStart" {
		h.t.Fatalf("session-start output: %s", out.String())
	}
	return hook["additionalContext"].(string)
}

func TestHookResendsTheLowNoticeAfterCompaction(t *testing.T) {
	for _, harness := range []string{"claude-code", "codex"} {
		t.Run(harness, func(t *testing.T) {
			h := newQuotaHookTest(t, harness, "en")
			now := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)
			reset5, resetW := now.Add(3*time.Hour), now.Add(72*time.Hour)
			h.reading(harness, now, hookWindow("five_hour", 70, reset5), hookWindow("weekly", 9, resetW))
			if got := h.sessionStart("thread", "compact", now); got != "" {
				t.Fatalf("nothing was sent yet: %s", got)
			}
			if got := h.prompt("thread", now); got != "Weekly quota: 9% left, resets in 3d." {
				t.Fatalf("low notice: %s", got)
			}
			later := now.Add(10 * time.Minute)
			h.reading(harness, later, hookWindow("five_hour", 70, reset5), hookWindow("weekly", 7, resetW))
			for _, source := range []string{"compact", "resume"} {
				if got := h.sessionStart("thread", source, later); got != "Weekly quota: 7% left, resets in 2d23h." {
					t.Fatalf("%s resend: %q", source, got)
				}
			}
			for _, source := range []string{"startup", "clear", ""} {
				if got := h.sessionStart("thread", source, later); got != "" {
					t.Fatalf("%s resent: %s", source, got)
				}
			}
			if got := h.sessionStart("other-thread", "compact", later); got != "" {
				t.Fatalf("another thread: %s", got)
			}
			// The resend marks nothing: the next 5% line still comes on a prompt.
			h.reading(harness, later, hookWindow("five_hour", 70, reset5), hookWindow("weekly", 4, resetW))
			if got := h.prompt("thread", later); got != "Weekly quota: 4% left, resets in 2d23h." {
				t.Fatalf("5%% after resend: %s", got)
			}
			// A corrected reading no longer holds the notice.
			h.reading(harness, later, hookWindow("five_hour", 70, reset5), hookWindow("weekly", 40, resetW))
			if got := h.sessionStart("thread", "compact", later); got != "" {
				t.Fatalf("stale notice resent: %s", got)
			}
			t.Setenv("MODELPLAN_TASK_BRIEF", "off")
			h.reading(harness, later, hookWindow("five_hour", 70, reset5), hookWindow("weekly", 4, resetW))
			if got := h.sessionStart("thread", "compact", later); got != "" {
				t.Fatalf("brief off: %s", got)
			}
		})
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
	h.publish()
	if got := h.prompt("thread", now); !strings.HasPrefix(got, "ModelPlan task-start brief") || strings.Contains(got, "12%") {
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
	if got := h.prompt("cached-thread", now); !strings.HasPrefix(got, "ModelPlan task-start brief") || !strings.HasSuffix(got, "\n\nWeekly quota: 12% left, resets in 3d.") {
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

// publish installs a synthetic verified publication, without a network request.
func (h quotaHookTest) publish(edits ...string) {
	t := h.t
	t.Helper()
	f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
		data := strings.ReplaceAll(string(doc["data"]), "z-dev", "openai")
		for i := 0; i+1 < len(edits); i += 2 {
			data = strings.ReplaceAll(data, edits[i], edits[i+1])
		}
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
}

func TestHookLowNoticeNamesTheStepToStarOnlyAboveIt(t *testing.T) {
	h := newQuotaHookTest(t, "claude-code", "en")
	// The fixture's two-effort model, in Claude Code and with High published.
	h.publish(`"codex":["native-z"]`, `"codex":["native-z"],"claude-code":["native-z"]`,
		`{"effort":"high","label":"High","ability":null,"cost":null`, `{"effort":"high","label":"High","ability":55,"cost":3`)
	now := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)
	read := func(effort string, left float64) {
		reset := now.Add(72 * time.Hour)
		used := 100 - left
		data := map[string]any{"schemaVersion": 1, "observedAt": now, "sessionKey": quota.SessionKey("thread-" + effort),
			"harness": map[string]any{"model": "native-z", "effort": effort},
			"windows": []quota.Window{{Kind: "weekly", UsedPercent: &used, ResetsAt: &reset, ResetMode: "fixed", ObservedAt: now}}}
		p := filepath.Join(h.st.Dir, "observed", "claude-code.json")
		if err := os.MkdirAll(filepath.Dir(p), 0700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, publicationJSON(t, data), 0600); err != nil {
			t.Fatal(err)
		}
	}
	notice := func(effort string) string {
		got := h.prompt("thread-"+effort, now)
		return got[strings.LastIndex(got, "\n")+1:]
	}
	read("high", 9)
	if got := notice("high"); !strings.HasPrefix(got, "Weekly quota: 9% left, resets in 3d. The effort is above ★: ★") || !strings.HasSuffix(got, "suggest it to the user once.") {
		t.Fatalf("above ★: %s", got)
	}
	read("medium", 9)
	if got := notice("medium"); got != "Weekly quota: 9% left, resets in 3d." {
		t.Fatalf("at ★: %s", got)
	}
}
