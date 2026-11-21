package tokenacct

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

var now = time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)

func utc(t *testing.T) {
	old := time.Local
	time.Local = time.UTC
	t.Cleanup(func() { time.Local = old })
}

func read(t *testing.T, path string) []byte {
	t.Helper()
	b, err := os.ReadFile(filepath.Join("testdata", path))
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func want(t *testing.T, name string, got, w Buckets) {
	t.Helper()
	w.Total = w.Sum()
	if got != w {
		t.Fatalf("%s = %+v, want %+v", name, got, w)
	}
}

// GeminiExpected is the hand check of the Gemini fixture against ccusage@58866ba6
// rust/adapters/gemini/src/parser.rs (direct events use normalize_session_input):
//
//	m-old 11-11  cached 0: input 3000, output 100, reasoning 3100-3100 = 0         total  3100
//	m-1   11-16  total 16276 = input+output+thoughts+tool, so cached overlaps input:
//	             input 15327-11526+7 = 3808, cache read 11526, output 23,
//	             reasoning 16276-(3808+23+11526) = 919                               total 16276
//	m-2   11-16  cached 0: input 20000, output 500, reasoning 100                  total 20600
//	m-4   11-16  JSONL id repeated: the later record wins (input 1000, output 80,
//	             cached 600, thoughts 20, total 1100 = inclusive): input 400,
//	             cache read 600, output 80, reasoning 20                            total  1100
//	user, info and metadata records carry no usage.
var geminiToday = Buckets{Input: 3808 + 20000 + 400, CacheRead: 11526 + 600, Output: 23 + 500 + 80, Reasoning: 919 + 100 + 20}
var gemini7d = Buckets{Input: 3000 + 3808 + 20000 + 400, CacheRead: 11526 + 600, Output: 100 + 23 + 500 + 80, Reasoning: 919 + 100 + 20}

func geminiEntries(t *testing.T) []Entry {
	dir := "gemini/tmp/redacted-project-hash/chats/"
	e := Gemini(read(t, dir+"session-2026-11-16T09-00-aaaa.json"), false, now)
	return append(e, Gemini(read(t, dir+"session-2026-11-16T10-00-bbbb.jsonl"), true, now)...)
}

func TestGeminiMatchesCcusage(t *testing.T) {
	utc(t)
	e := geminiEntries(t)
	if len(e) != 4 {
		t.Fatalf("entries = %+v", e)
	}
	w := Summarize(e, now)
	want(t, "today", w.Today, geminiToday)
	want(t, "7d", w.Last7d, gemini7d)
	want(t, "30d", w.Last30d, gemini7d)
	if w.Today.Total != 37976 || w.Last7d.Total != 41076 || w.Entries != 4 || w.Reference != Reference {
		t.Fatalf("windows = %+v", w)
	}
}

// QwenExpected follows ccusage@58866ba6 with the owner override: cached prompt
// tokens count once, so input excludes cachedContentTokenCount.
//
//	q-a0 11-15  only totalTokenCount 321: output 321 (total fallback), model unknown  total   321
//	q-a1 11-16  input 4000, cache read 8000, output 300, reasoning 0                total 12300
//	q-a1 again  in the resumed file: same session, time, model and buckets, dropped
//	q-a2 11-16  input 500, output 40, reasoning 10 (thoughts; total 550 adds none)   total   550
//	user and tool_result records do not count, whatever usageMetadata they carry.
var qwenToday = Buckets{Input: 4000 + 500, CacheRead: 8000, Output: 300 + 40, Reasoning: 10}
var qwen7d = Buckets{Input: 4000 + 500, CacheRead: 8000, Output: 321 + 300 + 40, Reasoning: 10}

func qwenEntries(t *testing.T) []Entry {
	dir := "qwen/projects/-redacted-repo/chats/"
	a := Qwen(read(t, dir+"redacted-session-q1.jsonl"), "-redacted-repo", "redacted-session-q1", now)
	b := Qwen(read(t, dir+"redacted-session-q1-resumed.jsonl"), "-redacted-repo", "redacted-session-q1-resumed", now)
	return DedupeQwen(a, b)
}

func TestQwenCountsCachedPromptOnce(t *testing.T) {
	utc(t)
	e := qwenEntries(t)
	if len(e) != 3 {
		t.Fatalf("entries = %+v", e)
	}
	w := Summarize(e, now)
	want(t, "today", w.Today, qwenToday)
	want(t, "7d", w.Last7d, qwen7d)
	if w.Today.Total != 12850 || w.Last7d.Total != 13171 {
		t.Fatalf("windows = %+v", w)
	}
}

func TestOpenCodeTokens(t *testing.T) {
	for _, tc := range []struct {
		name, raw string
		ok        bool
		want      Buckets
	}{
		{"parts", `{"input":100,"output":200,"reasoning":50,"cache":{"read":1000,"write":10}}`, true, Buckets{Input: 100, Output: 200, Reasoning: 50, CacheRead: 1000, CacheWrite: 10}},
		{"total only", `{"input":0,"output":0,"reasoning":0,"cache":{"read":0,"write":0},"total":500}`, true, Buckets{Output: 500}},
		{"total beyond parts", `{"input":10,"output":5,"total":20}`, true, Buckets{Input: 10, Output: 5, Reasoning: 5}},
		{"cache not an object", `{"input":10,"output":5,"cache":7}`, true, Buckets{Input: 10, Output: 5}},
		{"float is not a count", `{"input":10.5,"output":5}`, true, Buckets{Output: 5}},
		{"empty", `{"input":0,"output":0}`, false, Buckets{}},
		{"none", ``, false, Buckets{}},
	} {
		got, ok := OpenCodeTokens(tc.raw)
		if ok != tc.ok {
			t.Fatalf("%s: ok %v", tc.name, ok)
		}
		if ok {
			want(t, tc.name, got, tc.want)
		}
	}
}

func TestParseTSIsCcusageStrict(t *testing.T) {
	for in, ok := range map[string]bool{
		"2026-11-16T09:00:05Z":          true,
		"2026-11-16T09:00:05.123Z":      true,
		"2026-11-16T09:00:05+09:00":     true,
		"2026-11-16T09:00:05.123-07:00": true,
		"2026-11-16T09:00:05.123456Z":   false,
		"2026-02-30T09:00:05Z":          false,
		"2026-11-16 09:00:05Z":          false,
	} {
		if _, got := parseTS(in); got != ok {
			t.Fatalf("%s: %v", in, got)
		}
	}
	at, _ := parseTS("2026-11-16T09:00:05.123+09:00")
	if !at.Equal(time.Date(2026, 11, 16, 0, 0, 5, 123e6, time.UTC)) {
		t.Fatal(at)
	}
}

// Days are local calendar days: an entry late on the 15th in UTC is the 16th in Tokyo.
func TestSummarizeUsesLocalDays(t *testing.T) {
	old := time.Local
	tokyo, err := time.LoadLocation("Asia/Tokyo")
	if err != nil {
		t.Skip("no zoneinfo")
	}
	time.Local = tokyo
	t.Cleanup(func() { time.Local = old })
	e := []Entry{entry(time.Date(2026, 11, 15, 16, 0, 0, 0, time.UTC), Buckets{Output: 1}), entry(time.Date(2026, 11, 15, 14, 0, 0, 0, time.UTC), Buckets{Output: 2})}
	w := Summarize(e, now)
	if w.Today.Total != 1 || w.Last7d.Total != 3 {
		t.Fatalf("%+v", w)
	}
}

func TestQwenCachedPromptNormalizationBeforeFallback(t *testing.T) {
	for _, tc := range []struct {
		name, usage                 string
		input, cache, output, total int64
	}{
		{"partial cache", `{"promptTokenCount":12000,"cachedContentTokenCount":8000,"candidatesTokenCount":300,"totalTokenCount":12300}`, 4000, 8000, 300, 12300},
		{"fully cached", `{"promptTokenCount":12000,"cachedContentTokenCount":12000,"candidatesTokenCount":300,"totalTokenCount":12300}`, 0, 12000, 300, 12300},
		{"total fallback", `{"promptTokenCount":100,"cachedContentTokenCount":80,"totalTokenCount":150}`, 20, 80, 50, 150},
	} {
		t.Run(tc.name, func(t *testing.T) {
			raw := []byte(`{"type":"assistant","usageMetadata":` + tc.usage + `}`)
			entries := Qwen(raw, "redacted", "session", now)
			if len(entries) != 1 {
				t.Fatalf("entries: %+v", entries)
			}
			got := entries[0].Buckets
			if got.Input != tc.input || got.CacheRead != tc.cache || got.Output != tc.output || got.Total != tc.total {
				t.Fatalf("cached tokens overlap: %+v", got)
			}
		})
	}
}
