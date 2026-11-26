// SPDX-License-Identifier: MIT
package speed

import (
	"bufio"
	"context"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

// genImportFixture writes a synthetic 30-day history shaped like real Claude Code transcripts and
// Codex rollouts: long tool results, thinking blocks, file-history snapshots, sidechains, resumed
// sessions that copy earlier requests, Codex reasoning items and token_count notices, plus logs
// older than the import window. scale ~1 is a few MB; scale 100 is several hundred MB.
// The output is deterministic for a given seed, scale and now.
func genImportFixture(tb testing.TB, claudeRoot, codexRoot string, now time.Time, scale int, seed int64) int64 {
	tb.Helper()
	rng := rand.New(rand.NewSource(seed))
	var total int64
	blob := func(n int) string {
		// Escaped code-like text: quotes, backslashes and newlines, as tool output carries.
		const alphabet = "abcdefghijklmnopqrstuvwxyz    \\\"{}()=;.,_0123456789"
		var b strings.Builder
		b.Grow(n + n/8)
		for i := 0; i < n; i++ {
			if i%61 == 60 {
				b.WriteString(`\n`)
				continue
			}
			c := alphabet[rng.Intn(len(alphabet))]
			switch c {
			case '\\':
				b.WriteString(`\\`)
			case '"':
				b.WriteString(`\"`)
			default:
				b.WriteByte(c)
			}
		}
		return b.String()
	}
	toolSize := func() int {
		switch r := rng.Intn(100); {
		case r < 70:
			return 300 + rng.Intn(3500)
		case r < 96:
			return 8000 + rng.Intn(32000)
		default:
			return 80000 + rng.Intn(200000)
		}
	}
	ts := func(t time.Time) string { return t.UTC().Format("2006-01-02T15:04:05.000Z") }
	write := func(p string, lines []string, mod time.Time) {
		if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
			tb.Fatal(err)
		}
		f, err := os.Create(p)
		if err != nil {
			tb.Fatal(err)
		}
		w := bufio.NewWriterSize(f, 1<<20)
		for _, l := range lines {
			w.WriteString(l)
			w.WriteByte('\n')
			total += int64(len(l) + 1)
		}
		if err := w.Flush(); err != nil {
			tb.Fatal(err)
		}
		f.Close()
		os.Chtimes(p, mod, mod)
	}
	models := []string{"claude-opus-4-1-20250805", "claude-sonnet-4-5-20250929", "claude-haiku-4-5-20251001"}
	efforts := []string{"", "high", "medium"}
	sessions := 6 * scale
	var copied []string // assistant lines a resumed session copies
	for s := 0; s < sessions; s++ {
		// Spread over 40 days: the oldest tenth lies before the 30-day window.
		start := now.Add(-time.Duration(rng.Int63n(int64(40 * 24 * time.Hour)))).Truncate(time.Second)
		proj := fmt.Sprintf("-home-u-proj%d", s%7)
		sid := fmt.Sprintf("%08x-0000-4000-8000-%012x", rng.Uint32(), rng.Int63n(1<<40))
		head := fmt.Sprintf(`"userType":"external","cwd":"/home/u/proj%d","sessionId":%q,"version":"2.0.31","gitBranch":"main"`, s%7, sid)
		var lines []string
		at := start
		if s%9 == 4 && len(copied) > 0 { // resumed: earlier replies copied in
			lines = append(lines, copied...)
		}
		turns := 3 + rng.Intn(10)
		model := models[rng.Intn(len(models))]
		for t := 0; t < turns; t++ {
			at = at.Add(time.Duration(30+rng.Intn(600)) * time.Second)
			lines = append(lines, fmt.Sprintf(`{"parentUuid":null,"isSidechain":false,%s,"type":"user","message":{"role":"user","content":"please %s"},"uuid":"u-%d-%d","timestamp":%q}`, head, blob(80+rng.Intn(400)), s, t, ts(at)))
			if rng.Intn(4) == 0 {
				lines = append(lines, fmt.Sprintf(`{"type":"file-history-snapshot","messageId":"m-%d-%d","snapshot":{"trackedFileBackups":{"a.go":{"backupFileName":"x","version":%d}},"timestamp":%q},"isSnapshotUpdate":false}`, s, t, t, ts(at)))
			}
			if rng.Intn(15) == 0 {
				lines = append(lines, fmt.Sprintf(`{"type":"user","isMeta":true,%s,"message":{"role":"user","content":"<command-name>/clear</command-name>"},"uuid":"meta-%d-%d","timestamp":%q}`, head, s, t, ts(at)))
			}
			steps := 1 + rng.Intn(14)
			sidechain := rng.Intn(12) == 0
			for k := 0; k < steps; k++ {
				req := fmt.Sprintf("req_%d_%d_%d", s, t, k)
				msg := fmt.Sprintf("msg_%d_%d_%d", s, t, k)
				usage := fmt.Sprintf(`{"input_tokens":%d,"cache_creation_input_tokens":%d,"cache_read_input_tokens":%d,"cache_creation":{"ephemeral_5m_input_tokens":%d,"ephemeral_1h_input_tokens":0},"output_tokens":%d,"service_tier":"standard"}`, rng.Intn(50), rng.Intn(5000), 10000+rng.Intn(150000), rng.Intn(5000), 1+rng.Intn(2000))
				eff := efforts[rng.Intn(len(efforts))]
				effort := ""
				if eff != "" {
					effort = fmt.Sprintf(`"effort":%q,`, eff)
				}
				at = at.Add(time.Duration(1+rng.Intn(20)) * time.Second)
				if rng.Intn(3) == 0 {
					lines = append(lines, fmt.Sprintf(`{"parentUuid":"p","isSidechain":%v,%s,%s"thinkingDurationMs":%d,"message":{"id":%q,"type":"message","role":"assistant","model":%q,"content":[{"type":"thinking","thinking":"%s","signature":"%s"}],"stop_reason":null,"stop_sequence":null,"usage":%s},"requestId":%q,"type":"assistant","uuid":"a-%d-%d-%d-t","timestamp":%q}`, sidechain, head, effort, 500+rng.Intn(9000), msg, model, blob(200+rng.Intn(2000)), blob(300), usage, req, s, t, k, ts(at)))
				}
				stop := "tool_use"
				block := fmt.Sprintf(`{"type":"tool_use","id":"toolu_%d_%d_%d","name":"Bash","input":{"command":"%s"}}`, s, t, k, blob(40+rng.Intn(300)))
				if k == steps-1 {
					stop, block = "end_turn", fmt.Sprintf(`{"type":"text","text":"%s"}`, blob(100+rng.Intn(1500)))
				}
				reply := fmt.Sprintf(`{"parentUuid":"p","isSidechain":%v,%s,%s"message":{"id":%q,"type":"message","role":"assistant","model":%q,"content":[%s],"stop_reason":%q,"stop_sequence":null,"usage":%s},"requestId":%q,"type":"assistant","uuid":"a-%d-%d-%d","timestamp":%q}`, sidechain, head, effort, msg, model, block, stop, usage, req, s, t, k, ts(at))
				lines = append(lines, reply)
				if rng.Intn(25) == 0 {
					copied = append(copied, reply)
				}
				if k < steps-1 {
					at = at.Add(time.Duration(1+rng.Intn(60)) * time.Second)
					lines = append(lines, fmt.Sprintf(`{"parentUuid":"p","isSidechain":%v,%s,"type":"user","message":{"role":"user","content":[{"tool_use_id":"toolu_%d_%d_%d","type":"tool_result","content":"%s","is_error":false}]},"uuid":"r-%d-%d-%d","timestamp":%q,"toolUseResult":{"stdout":"%s","stderr":"","interrupted":false}}`, sidechain, head, s, t, k, blob(toolSize()), s, t, k, ts(at), blob(200)))
				}
			}
			if rng.Intn(20) == 0 {
				lines = append(lines, fmt.Sprintf(`{"type":"summary","summary":"%s","leafUuid":"a-%d-%d"}`, blob(60), s, t))
			}
		}
		if len(copied) > 60 {
			copied = copied[len(copied)-60:]
		}
		write(filepath.Join(claudeRoot, "projects", proj, sid+".jsonl"), lines, at)
	}

	cxModels := []string{"gpt-5-codex", "gpt-5.1-codex-max", "gpt-5"}
	for s := 0; s < 4*scale; s++ {
		start := now.Add(-time.Duration(rng.Int63n(int64(40 * 24 * time.Hour)))).Truncate(time.Second)
		id := fmt.Sprintf("0199%04x-0000-7000-8000-%012x", s, rng.Int63n(1<<40))
		dir := filepath.Join(codexRoot, "sessions", start.Format("2006"), start.Format("01"), start.Format("02"))
		if s%11 == 3 {
			dir = filepath.Join(codexRoot, "archived_sessions")
		}
		var lines []string
		at := start
		cx := func(kind, payload string) {
			lines = append(lines, fmt.Sprintf(`{"timestamp":%q,"type":%q,"payload":%s}`, ts(at), kind, payload))
		}
		meta := fmt.Sprintf(`{"id":%q,"timestamp":%q,"cwd":"/home/u/cx%d","originator":"codex_cli_rs","cli_version":"0.58.0","instructions":null,"source":"cli","model_provider":"openai","base_instructions":{"text":"%s"}}`, id, ts(at), s%5, blob(9000))
		if s%13 == 6 {
			meta = fmt.Sprintf(`{"id":%q,"forked_from_id":"parent-%d","timestamp":%q,"cwd":"/home/u/cx","source":{"subagent":{"thread_spawn":{"parent_thread_id":"parent-%d"}}}}`, id, s, ts(at), s)
		}
		cx("session_meta", meta)
		model := cxModels[rng.Intn(len(cxModels))]
		tier := ""
		if rng.Intn(5) == 0 {
			tier = `,"service_tier":"priority"`
			cx("event_msg", `{"type":"thread_settings_applied","thread_settings":{"service_tier":"priority"}}`)
		}
		var cumIn, cumCached, cumOut, cumReason int64
		turns := 2 + rng.Intn(8)
		for t := 0; t < turns; t++ {
			at = at.Add(time.Duration(30+rng.Intn(900)) * time.Second)
			cx("event_msg", `{"type":"task_started","model_context_window":272000}`)
			cx("turn_context", fmt.Sprintf(`{"cwd":"/home/u/cx%d","approval_policy":"on-request","sandbox_policy":{"mode":"workspace-write"},"model":%q,"effort":"high","summary":"auto"%s}`, s%5, model, tier))
			cx("response_item", fmt.Sprintf(`{"type":"message","role":"user","content":[{"type":"input_text","text":"%s"}]}`, blob(100+rng.Intn(600))))
			cx("event_msg", fmt.Sprintf(`{"type":"user_message","message":"%s","images":[]}`, blob(100)))
			steps := 1 + rng.Intn(12)
			for k := 0; k < steps; k++ {
				first := at.Add(time.Duration(1+rng.Intn(5)) * time.Second)
				at = first.Add(time.Duration(1+rng.Intn(30)) * time.Second)
				cx("response_item", fmt.Sprintf(`{"type":"reasoning","summary":[{"type":"summary_text","text":"%s"}],"content":null,"encrypted_content":"%s"}`, blob(200), blob(1500+rng.Intn(4000))))
				cx("event_msg", fmt.Sprintf(`{"type":"agent_reasoning","text":"%s"}`, blob(200)))
				cx("event_msg", fmt.Sprintf(`{"type":"item_completed","item":{"type":"Reasoning","id":"i"},"started_at_ms":%d}`, first.UnixMilli()))
				in, cached, out, reason := int64(2000+rng.Intn(30000)), int64(rng.Intn(20000)), int64(50+rng.Intn(3000)), int64(rng.Intn(1500))
				cumIn, cumCached, cumOut, cumReason = cumIn+in, cumCached+cached, cumOut+out, cumReason+reason
				cx("event_msg", fmt.Sprintf(`{"type":"token_count","info":{"total_token_usage":{"input_tokens":%d,"cached_input_tokens":%d,"output_tokens":%d,"reasoning_output_tokens":%d,"total_tokens":%d},"last_token_usage":{"input_tokens":%d,"cached_input_tokens":%d,"output_tokens":%d,"reasoning_output_tokens":%d,"total_tokens":%d},"model_context_window":272000},"rate_limits":{"primary":{"used_percent":12.0,"window_minutes":300,"resets_in_seconds":1000}}}`, cumIn, cumCached, cumOut, cumReason, cumIn+cumOut, in, cached, out, reason, in+out))
				if k < steps-1 {
					cx("response_item", fmt.Sprintf(`{"type":"function_call","name":"shell","arguments":"{\"command\":[\"bash\",\"-lc\",\"%s\"]}","call_id":"call_%d_%d"}`, blob(80), t, k))
					at = at.Add(time.Duration(1+rng.Intn(40)) * time.Second)
					cx("response_item", fmt.Sprintf(`{"type":"function_call_output","call_id":"call_%d_%d","output":"%s"}`, t, k, blob(toolSize())))
				} else {
					cx("response_item", fmt.Sprintf(`{"type":"message","role":"assistant","content":[{"type":"output_text","text":"%s"}]}`, blob(300+rng.Intn(2000))))
				}
			}
			if rng.Intn(10) == 0 {
				cx("compacted", fmt.Sprintf(`{"message":"%s","compaction_response_id":"resp_%d_%d"}`, blob(500), s, t))
			}
			cx("event_msg", fmt.Sprintf(`{"type":"task_complete","last_agent_message":"done","duration_ms":%d}`, 1000*(5+rng.Intn(600))))
		}
		write(filepath.Join(dir, "rollout-"+start.Format("2006-01-02T15-04-05")+"-"+id+".jsonl"), lines, at)
	}
	return total
}

// importFixtureRun imports a generated (or, with MODELPLAN_IMPORT_FIXTURE, an existing) history
// into a fresh cache and returns the cache folder.
func importFixtureRun(tb testing.TB, claude, codex string, now time.Time) string {
	tb.Helper()
	cache := tb.TempDir()
	res, err := Import(context.Background(), cache, ImportOptions{Days: 30, Claude: &ImportRoot{Dir: claude}, Codex: &ImportRoot{Dir: codex}, Now: now, Admission: both(), Auto: true})
	if err != nil || res.Cancelled {
		tb.Fatalf("import: %+v %v", res, err)
	}
	return cache
}

var fixtureNow = time.Date(2026, 11, 20, 12, 0, 0, 0, time.UTC)

// BenchmarkImportFixture profiles the first-run import. MODELPLAN_IMPORT_FIXTURE names a folder
// holding claude/ and codex/ from a larger generation (see TestGenerateImportFixture); otherwise a
// small one is generated.
func BenchmarkImportFixture(b *testing.B) {
	old := time.Local
	time.Local = time.UTC
	defer func() { time.Local = old }()
	root := os.Getenv("MODELPLAN_IMPORT_FIXTURE")
	if root == "" {
		root = b.TempDir()
		genImportFixture(b, filepath.Join(root, "claude"), filepath.Join(root, "codex"), fixtureNow, 4, 1)
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		importFixtureRun(b, filepath.Join(root, "claude"), filepath.Join(root, "codex"), fixtureNow)
	}
}

// TestGenerateImportFixture writes a large fixture for profiling when MODELPLAN_IMPORT_FIXTURE_GEN
// names an empty folder (scale from MODELPLAN_IMPORT_FIXTURE_SCALE, default 100).
func TestGenerateImportFixture(t *testing.T) {
	root := os.Getenv("MODELPLAN_IMPORT_FIXTURE_GEN")
	if root == "" {
		t.Skip("profiling helper")
	}
	scale := 100
	if s, err := strconv.Atoi(os.Getenv("MODELPLAN_IMPORT_FIXTURE_SCALE")); err == nil && s > 0 {
		scale = s
	}
	n := genImportFixture(t, filepath.Join(root, "claude"), filepath.Join(root, "codex"), fixtureNow, scale, 1)
	t.Logf("wrote %d MB", n>>20)
}
