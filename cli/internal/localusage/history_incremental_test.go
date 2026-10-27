package localusage

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/testenv"
)

func historyTestAccess(t *testing.T) HistoryAccess {
	t.Helper()
	testenv.IsolateHome(t)
	return HistoryAccess{Allowed: true, ProfileRef: strings.Repeat("a", 64), Key: bytes.Repeat([]byte{4}, 32)}
}
func qwenHistoryLine(id string, n int) string {
	return fmt.Sprintf(`{"uuid":%q,"sessionId":"private-session-canary","type":"assistant","timestamp":"2026-10-23T10:00:00Z","model":"qwen-test","usageMetadata":{"promptTokenCount":%d,"candidatesTokenCount":0},"content":"private-message-canary"}`+"\n", id, n)
}
func TestHistoryAdaptersPreserveNativeCounters(t *testing.T) {
	a := historyTestAccess(t)
	for _, tc := range []struct {
		tool, rel, body string
		input           int64
		undated         bool
	}{
		{"amp", "T-private-session-canary.json", `{"id":"private-session-canary","title":"private-title-canary","messages":[{"role":"assistant","messageId":1,"content":"private-message-canary","usage":{"model":"amp-test","timestamp":"2026-10-23T10:00:00Z","inputTokens":10,"outputTokens":2,"cacheReadInputTokens":5}}]}`, 10, false},
		{"droid", "project/private-session-canary.settings.json", `{"model":"private-current-model-canary","tokenUsage":{"inputTokens":10,"outputTokens":2,"cacheReadTokens":5},"inclusiveTokenUsage":{"inputTokens":999},"childInclusiveTokenUsageBySessionId":{"private-child-canary":{}}}`, 10, true},
		{"kimi", "project/private-session-canary/wire.jsonl", fmt.Sprintf(`{"timestamp":%d,"message":{"type":"StatusUpdate","payload":{"message_id":"private-event-canary","token_usage":{"input_other":3,"output":2,"input_cache_read":7,"input_cache_creation":1},"content":"private-message-canary"}}}`+"\n", testNow.Add(-time.Hour).Unix()), 3, false},
		{"qwen", "projects/project/chats/private-session-canary.jsonl", qwenHistoryLine("private-event-canary", 10), 10, false},
		{"copilot", "private-session-canary/events.jsonl", `{"type":"session.start","timestamp":"2026-10-23T09:00:00Z","data":{"private-account-canary":"ignored"}}` + "\n" + `{"type":"assistant.usage","ephemeral":true,"timestamp":"2026-10-23T10:00:00Z","data":{"model":"must-not-count","inputTokens":999}}` + "\n" + `{"type":"session.shutdown","timestamp":"2026-10-23T11:00:00Z","data":{"modelMetrics":{"copilot-test":{"usage":{"inputTokens":10,"outputTokens":2,"cacheReadTokens":5}}}}}` + "\n", 10, false},
		{"gemini", "tmp/project/chats/session-private-session-canary.json", sessionJSON(messageOne), 100, false},
		{"grok", "project/private-session-canary/usage.json", `{"sessionId":"private-session-canary","session":{"inputTokens":999},"turns":[{"turnNumber":1,"endedAt":"2026-10-23T10:00:00Z","modelUsage":{"grok-test":{"inputTokens":10,"outputTokens":2,"cachedReadTokens":5,"totalTokens":12}}}]}`, 10, false},
	} {
		t.Run(tc.tool, func(t *testing.T) {
			root, cache := t.TempDir(), t.TempDir()
			path := filepath.Join(root, tc.rel)
			fixtureFile(t, path, tc.body)
			if tc.tool == "grok" {
				fixtureFile(t, filepath.Join(filepath.Dir(path), "summary.json"), `{"info":{},"created_at":"2026-10-23T09:00:00Z","num_messages":1}`)
			}
			original, _ := os.ReadFile(path)
			r := RefreshHistory(context.Background(), tc.tool, root, cache, a, testNow)
			if !r.Beta || r.Measurement != "local-usage" {
				t.Fatal(r)
			}
			rows := r.Rows
			if tc.undated {
				rows = r.Unallocated
			}
			if len(rows) != 1 || rows[0].Input == nil || *rows[0].Input != tc.input {
				t.Fatalf("%+v", r)
			}
			if tc.tool == "kimi" && rows[0].Model != "" {
				t.Fatal("Kimi model inferred")
			}
			if tc.undated && (rows[0].Day != "" || rows[0].Model != "") {
				t.Fatal("Droid timestamp/model inferred")
			}
			if tc.tool != "grok" && tc.tool != "gemini" && rows[0].Total != nil {
				t.Fatal("total fabricated")
			}
			b, _ := os.ReadFile(historyPath(cache, tc.tool, a))
			out, _ := json.Marshal(r)
			for _, canary := range []string{"private-session-canary", "private-title-canary", "private-message-canary", "private-event-canary", "private-current-model-canary", "private-child-canary", "private-account-canary", root, "PRIVATE REPLY", "PRIVATE THOUGHT", "PRIVATE TOOL", "message-secret", "session-secret", "project-secret"} {
				if bytes.Contains(append(b, out...), []byte(canary)) {
					t.Fatalf("leaked %s", canary)
				}
			}
			after, _ := os.ReadFile(path)
			if !bytes.Equal(original, after) {
				t.Fatal("source rewritten")
			}
			r = RefreshHistory(context.Background(), tc.tool, root, cache, a, testNow.Add(time.Hour))
			if r.BytesRead != 0 {
				t.Fatal("unchanged source rescanned", r.BytesRead)
			}
		})
	}
}
func TestHistoryJSONLIncrementalTruncationAndRotation(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	rel := "projects/project/chats/session.jsonl"
	path := filepath.Join(root, rel)
	one := qwenHistoryLine("one", 10)
	fixtureFile(t, path, one)
	r := RefreshHistory(context.Background(), "qwen", root, cache, a, testNow)
	if len(r.Rows) != 1 || *r.Rows[0].Input != 10 {
		t.Fatal(r)
	}
	two := qwenHistoryLine("two", 20)
	f, _ := os.OpenFile(path, os.O_WRONLY|os.O_APPEND, 0600)
	_, _ = f.WriteString(strings.TrimSuffix(two, "\n"))
	f.Close()
	r = RefreshHistory(context.Background(), "qwen", root, cache, a, testNow.Add(5*time.Minute))
	if r.Availability != "partial" || *r.Rows[0].Input != 10 || r.BytesRead != int64(len(two)-1) {
		t.Fatal(r)
	}
	f, _ = os.OpenFile(path, os.O_WRONLY|os.O_APPEND, 0600)
	_, _ = f.WriteString("\n")
	f.Close()
	r = RefreshHistory(context.Background(), "qwen", root, cache, a, testNow.Add(15*time.Minute))
	if *r.Rows[0].Input != 30 || r.BytesRead != int64(len(two)) {
		t.Fatal(r)
	}
	_ = os.Rename(path, path+".old")
	fixtureFile(t, path, one+two)
	r = RefreshHistory(context.Background(), "qwen", root, cache, a, testNow.Add(20*time.Minute))
	if *r.Rows[0].Input != 30 {
		t.Fatal("rotation counted twice", r)
	}
	// Same keyed message is replaced, never added again after a rewrite.
	fixtureFile(t, path, qwenHistoryLine("one", 15)+two)
	_ = os.Chtimes(path, testNow.Add(25*time.Minute), testNow.Add(25*time.Minute))
	r = RefreshHistory(context.Background(), "qwen", root, cache, a, testNow.Add(25*time.Minute))
	if *r.Rows[0].Input != 35 {
		t.Fatal(r)
	}
	before, _ := os.ReadFile(historyPath(cache, "qwen", a))
	ReadHistoryCache(cache, "qwen", a, testNow.Add(time.Hour))
	after, _ := os.ReadFile(historyPath(cache, "qwen", a))
	if !bytes.Equal(before, after) {
		t.Fatal("cache-only projection mutated state")
	}
}
func TestHistoryChangedSnapshotsAndUnallocatedDay(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "project/session/usage.json")
	body := `{"turns":[{"turnNumber":1,"endedAt":"2026-10-23T10:00:00Z","modelUsage":{"old-model":{"inputTokens":10}}}]}`
	fixtureFile(t, path, body)
	fixtureFile(t, filepath.Join(filepath.Dir(path), "summary.json"), `{"info":{},"created_at":"2026-10-23T09:00:00Z","num_messages":1}`)
	RefreshHistory(context.Background(), "grok", root, cache, a, testNow)
	body = strings.ReplaceAll(body, "old-model", "new-model")
	fixtureFile(t, path, body)
	_ = os.Chtimes(path, testNow.Add(time.Minute), testNow.Add(time.Minute))
	r := RefreshHistory(context.Background(), "grok", root, cache, a, testNow.Add(5*time.Minute))
	if len(r.Rows) != 1 || r.Rows[0].Model != "new-model" || r.BytesRead != int64(len(body)) {
		t.Fatal(r)
	}
	root, cache = t.TempDir(), t.TempDir()
	body = `{"type":"session.start","timestamp":"2026-10-22T09:00:00Z"}` + "\n" + `{"type":"session.shutdown","timestamp":"2026-10-23T10:00:00Z","data":{"modelMetrics":{"model-test":{"usage":{"inputTokens":10}}}}}` + "\n"
	fixtureFile(t, filepath.Join(root, "session/events.jsonl"), body)
	r = RefreshHistory(context.Background(), "copilot", root, cache, a, testNow)
	if len(r.Rows) != 0 || len(r.Unallocated) != 1 || r.Unallocated[0].Day != "" || r.Availability != "partial" {
		t.Fatal(r)
	}
}
func TestHistoryConsentProviderGateAndUnsafePaths(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	fixtureFile(t, filepath.Join(root, "projects/project/chats/session.jsonl"), qwenHistoryLine("one", 0))
	disabled := a
	disabled.Allowed = false
	r := RefreshHistory(context.Background(), "qwen", root, cache, disabled, testNow)
	if r.Availability != "consent_required" {
		t.Fatal(r)
	}
	if _, err := os.Stat(filepath.Join(cache, "observed")); !os.IsNotExist(err) {
		t.Fatal("I/O before consent")
	}
	t.Setenv("MODELPLAN_READERS", "passive")
	r = RefreshHistory(context.Background(), "qwen", root, cache, a, testNow)
	if len(r.Rows) != 1 || *r.Rows[0].Input != 0 {
		t.Fatal(r)
	}
	other := a
	other.ProfileRef = strings.Repeat("b", 64)
	r = RefreshHistory(context.Background(), "qwen", root, cache, other, testNow.Add(time.Minute))
	if len(r.Rows) != 0 || r.BytesRead != 0 {
		t.Fatal("cross-profile gate bypass")
	}
	t.Setenv("MODELPLAN_READERS", "off")
	if r := RefreshHistory(context.Background(), "qwen", root, cache, a, testNow.Add(time.Hour)); r.Availability != "off" {
		t.Fatal(r)
	}
	t.Setenv("MODELPLAN_READERS", "")
	link := filepath.Join(t.TempDir(), "root")
	_ = os.Symlink(root, link)
	r = RefreshHistory(context.Background(), "qwen", link, t.TempDir(), a, testNow)
	if r.Availability != "denied" {
		t.Fatal(r)
	}
	for _, tool := range []string{"amp", "droid", "kimi", "copilot", "grok", "qwen", "gemini"} {
		for _, rel := range []string{"oauth_creds.json", "auth.json", "settings.json", "history.jsonl", "credentials/token.json"} {
			if historyAllowed(tool, rel) {
				t.Fatal(tool, rel)
			}
		}
	}
	a.Key = nil
	if r := RefreshHistory(context.Background(), "qwen", root, t.TempDir(), a, testNow); r.Availability != "privacy_blocked" {
		t.Fatal(r)
	}
}
func TestHistoryRollbackCorruptGateAndNoTimestampGuess(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	fixtureFile(t, filepath.Join(root, "T-session.json"), `{"created":1792756800000,"messages":[{"role":"assistant","messageId":1,"usage":{"model":"model-test","inputTokens":10}}]}`)
	r := RefreshHistory(context.Background(), "amp", root, cache, a, testNow)
	if len(r.Rows) != 0 || len(r.Unallocated) != 1 || !r.ObservedAt.IsZero() {
		t.Fatal("mtime/created inferred as usage timestamp", r)
	}
	prior, _ := os.ReadFile(historyPath(cache, "amp", a))
	RefreshHistory(context.Background(), "amp", root, cache, a, testNow.Add(-time.Hour))
	after, _ := os.ReadFile(historyPath(cache, "amp", a))
	if !bytes.Equal(prior, after) {
		t.Fatal("rollback gate bypass")
	}
	gate, _ := historyGatePaths(cache, "amp")
	fixtureFile(t, gate, `{"schemaVersion":999}`)
	r = RefreshHistory(context.Background(), "amp", root, cache, a, testNow.Add(time.Hour))
	if r.Availability != "not_supported_yet" {
		t.Fatal(r)
	}
}

type historyCountedSource struct {
	historySource
	bytes *int64
}

func (f historyCountedSource) Read(b []byte) (int, error) {
	n, err := f.historySource.Read(b)
	*f.bytes += int64(n)
	return n, err
}
func (f historyCountedSource) ReadAt(b []byte, at int64) (int, error) {
	n, err := f.historySource.ReadAt(b, at)
	*f.bytes += int64(n)
	return n, err
}

type historyDarwinInfo struct{ os.FileInfo }

func (fi historyDarwinInfo) Sys() any {
	return &struct {
		Dev       int32
		Ino       uint64
		Ctimespec struct{ Sec, Nsec int64 }
	}{Dev: -17, Ino: 123, Ctimespec: struct{ Sec, Nsec int64 }{fi.ModTime().Unix(), int64(fi.ModTime().Nanosecond())}}
}
func TestHistoryUnchangedContentIOAndDarwinMetadata(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "projects/project/chats/session.jsonl")
	fixtureFile(t, path, qwenHistoryLine("one", 10))
	old := historyOpenSource
	t.Cleanup(func() { historyOpenSource = old })
	var content int64
	historyOpenSource = func(path string) (historySource, os.FileInfo, error) {
		f, info, err := historyOpen(path)
		if err != nil {
			return nil, nil, err
		}
		return historyCountedSource{historySource: f, bytes: &content}, historyDarwinInfo{FileInfo: info}, nil
	}
	r := RefreshHistory(context.Background(), "qwen", root, cache, a, testNow)
	if len(r.Rows) != 1 || *r.Rows[0].Input != 10 {
		t.Fatal("signed Darwin metadata rejected", r)
	}
	content = 0
	r = RefreshHistory(context.Background(), "qwen", root, cache, a, testNow.Add(5*time.Minute))
	if content != 0 || r.BytesRead != 0 || r.ValidationBytes != 0 {
		t.Fatal("unchanged source content reread", content, r)
	}
	extra := qwenHistoryLine("two", 20)
	f, _ := os.OpenFile(path, os.O_WRONLY|os.O_APPEND, 0600)
	_, _ = f.WriteString(extra)
	f.Close()
	content = 0
	r = RefreshHistory(context.Background(), "qwen", root, cache, a, testNow.Add(10*time.Minute))
	if *r.Rows[0].Input != 30 || r.BytesRead != int64(len(extra)) || content != r.BytesRead+r.ValidationBytes {
		t.Fatal("append/validation I/O not accounted", content, r)
	}
}
func TestHistorySameSizeMiddleRewriteAndUnknownProtocol(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "projects/project/chats/session.jsonl")
	var lines []string
	for i := 0; i < 30; i++ {
		lines = append(lines, qwenHistoryLine(fmt.Sprintf("event-%02d", i), 10))
	}
	first := strings.Join(lines, "")
	fixtureFile(t, path, first)
	r := RefreshHistory(context.Background(), "qwen", root, cache, a, testNow)
	if *r.Rows[0].Input != 300 {
		t.Fatal(r)
	}
	lines[15] = qwenHistoryLine("event-15", 20)
	next := strings.Join(lines, "")
	if len(first) != len(next) || first[:1024] != next[:1024] || first[len(first)-1024:] != next[len(next)-1024:] {
		t.Fatal("invalid middle-rewrite fixture")
	}
	fixtureFile(t, path, next)
	_ = os.Chtimes(path, testNow.Add(time.Minute), testNow.Add(time.Minute))
	r = RefreshHistory(context.Background(), "qwen", root, cache, a, testNow.Add(5*time.Minute))
	if *r.Rows[0].Input != 310 || r.BytesRead == 0 {
		t.Fatal("middle rewrite served old totals as current", r)
	}
	root, cache = t.TempDir(), t.TempDir()
	fixtureFile(t, filepath.Join(root, "project/session/wire.jsonl"), `{"type":"metadata","protocol_version":"999"}`+"\n")
	r = RefreshHistory(context.Background(), "kimi", root, cache, a, testNow)
	if r.Availability != "not_supported_yet" || len(r.Rows) != 0 {
		t.Fatal(r)
	}
	r = RefreshHistory(context.Background(), "kimi", root, cache, a, testNow.Add(10*time.Minute))
	if r.Availability != "not_supported_yet" || r.BytesRead != 0 || r.ValidationBytes != 0 {
		t.Fatal("unchanged unsupported source reread", r)
	}
}

func TestHistoryForgetProfileRetainsProviderGate(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	fixtureFile(t, filepath.Join(root, "projects/project/chats/session.jsonl"), qwenHistoryLine("one", 10))
	RefreshHistory(context.Background(), "qwen", root, cache, a, testNow)
	gate, _ := historyGatePaths(cache, "qwen")
	before, _ := os.ReadFile(gate)
	a.Allowed = false
	t.Setenv("MODELPLAN_READERS", "off")
	if err := ForgetHistoryProfile(cache, "qwen", a); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(historyPath(cache, "qwen", a)); !os.IsNotExist(err) {
		t.Fatal("profile readings retained")
	}
	after, _ := os.ReadFile(gate)
	if !bytes.Equal(before, after) {
		t.Fatal("forget reset provider floor")
	}
}

func TestHistoryGrokExcludesInclusiveChildAndForkCopies(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	usage := `{"turns":[{"turnNumber":1,"endedAt":"2026-10-23T10:00:00Z","modelUsage":{"grok-test":{"inputTokens":10}}}]}`
	fixtureFile(t, filepath.Join(root, "project/parent/summary.json"), `{"info":{},"created_at":"2026-10-23T09:00:00Z","num_messages":1}`)
	fixtureFile(t, filepath.Join(root, "project/parent/usage.json"), usage)
	for _, name := range []string{"child", "fork"} {
		fixtureFile(t, filepath.Join(root, "project", name, "summary.json"), `{"info":{},"created_at":"2026-10-23T09:00:00Z","num_messages":1,"parent_session_id":"private-parent-canary","session_kind":"subagent_fork"}`)
		fixtureFile(t, filepath.Join(root, "project", name, "usage.json"), usage)
	}
	r := RefreshHistory(context.Background(), "grok", root, cache, a, testNow)
	if len(r.Rows) != 1 || *r.Rows[0].Input != 10 {
		t.Fatal("inclusive child/fork usage counted twice", r)
	}
	b, _ := os.ReadFile(historyPath(cache, "grok", a))
	if bytes.Contains(b, []byte("private-parent-canary")) {
		t.Fatal("raw parent ID persisted")
	}
}

func TestHistoryGrokLastGoodScopeSurvivesMissingOrUnreadableSource(t *testing.T) {
	for _, kind := range []string{"summary_missing", "usage_missing", "session_missing", "summary_unreadable", "summary_unreadable_changed_usage", "usage_unreadable", "summary_malformed", "legacy_scope_session_missing"} {
		t.Run(kind, func(t *testing.T) {
			a := historyTestAccess(t)
			root, cache := t.TempDir(), t.TempDir()
			session := filepath.Join(root, "project/session")
			summary := filepath.Join(session, "summary.json")
			usage := filepath.Join(session, "usage.json")
			fixtureFile(t, summary, `{"info":{},"created_at":"2026-10-23T09:00:00Z","num_messages":1}`)
			fixtureFile(t, usage, `{"turns":[{"turnNumber":1,"endedAt":"2026-10-23T10:00:00Z","modelUsage":{"grok-test":{"inputTokens":10}}}]}`)
			first := RefreshHistory(context.Background(), "grok", root, cache, a, testNow)
			if first.Availability != "ok" || len(first.Rows) != 1 || *first.Rows[0].Input != 10 {
				t.Fatal(first)
			}
			switch kind {
			case "summary_missing":
				if err := os.Remove(summary); err != nil {
					t.Fatal(err)
				}
			case "usage_missing":
				if err := os.Remove(usage); err != nil {
					t.Fatal(err)
				}
			case "session_missing", "legacy_scope_session_missing":
				if kind == "legacy_scope_session_missing" {
					path := historyPath(cache, "grok", a)
					b, _ := os.ReadFile(path)
					var doc map[string]any
					if err := json.Unmarshal(b, &doc); err != nil {
						t.Fatal(err)
					}
					for _, entry := range doc["entries"].(map[string]any) {
						delete(entry.(map[string]any), "capturedScope")
					}
					b, _ = json.Marshal(doc)
					if err := os.WriteFile(path, b, 0600); err != nil {
						t.Fatal(err)
					}
				}
				if err := os.RemoveAll(session); err != nil {
					t.Fatal(err)
				}
			case "summary_unreadable", "summary_unreadable_changed_usage", "usage_unreadable":
				if kind == "summary_unreadable_changed_usage" {
					fixtureFile(t, usage, `{"turns":[{"turnNumber":1,"endedAt":"2026-10-23T10:01:00Z","modelUsage":{"grok-test":{"inputTokens":20}}}]}`)
				}
				blocked := summary
				if kind == "usage_unreadable" {
					blocked = usage
				}
				old := historyOpenSource
				t.Cleanup(func() { historyOpenSource = old })
				historyOpenSource = func(path string) (historySource, os.FileInfo, error) {
					if path == blocked {
						return nil, nil, os.ErrPermission
					}
					return old(path)
				}
			case "summary_malformed":
				fixtureFile(t, summary, `{"info":`)
			}
			r := RefreshHistory(context.Background(), "grok", root, cache, a, testNow.Add(5*time.Minute))
			if r.Availability == "ok" || r.Freshness != "stale" || len(r.Rows) != 1 || *r.Rows[0].Input != 10 || !r.ObservedAt.Equal(first.ObservedAt) {
				t.Fatalf("last-good scope/age lost: %+v", r)
			}
			cached := ReadHistoryCache(cache, "grok", a, testNow.Add(6*time.Minute))
			if len(cached.Rows) != 1 || *cached.Rows[0].Input != 10 || !cached.ObservedAt.Equal(first.ObservedAt) || cached.Freshness != "stale" {
				t.Fatal(cached)
			}
		})
	}
}

func TestHistoryGrokContradictoryScopeStaysExcludedAfterDisappearance(t *testing.T) {
	for _, scope := range []string{`"parent_session_id":"private-parent-canary"`, `"session_kind":"subagent"`, `"session_kind":"subagent_fork"`, `"hidden":true`} {
		t.Run(scope, func(t *testing.T) {
			a := historyTestAccess(t)
			root, cache := t.TempDir(), t.TempDir()
			session := filepath.Join(root, "project/session")
			summary := filepath.Join(session, "summary.json")
			fixtureFile(t, summary, `{"info":{},"created_at":"2026-10-23T09:00:00Z","num_messages":1}`)
			fixtureFile(t, filepath.Join(session, "usage.json"), `{"turns":[{"turnNumber":1,"endedAt":"2026-10-23T10:00:00Z","modelUsage":{"grok-test":{"inputTokens":10}}}]}`)
			if r := RefreshHistory(context.Background(), "grok", root, cache, a, testNow); len(r.Rows) != 1 {
				t.Fatal(r)
			}
			fixtureFile(t, summary, `{"info":{},"created_at":"2026-10-23T09:00:00Z","num_messages":1,`+scope+`}`)
			r := RefreshHistory(context.Background(), "grok", root, cache, a, testNow.Add(5*time.Minute))
			if len(r.Rows) != 0 || !r.ObservedAt.IsZero() {
				t.Fatal("contradictory scope retained eligible counts", r)
			}
			if err := os.RemoveAll(session); err != nil {
				t.Fatal(err)
			}
			r = RefreshHistory(context.Background(), "grok", root, cache, a, testNow.Add(15*time.Minute))
			if len(r.Rows) != 0 || !r.ObservedAt.IsZero() {
				t.Fatal("excluded copy resurrected after cursor pruning", r)
			}
		})
	}
}
