package qwenusage

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

func qwenNativeAccess(t *testing.T) NativeAccess {
	t.Helper()
	testenv.IsolateHome(t)
	return NativeAccess{Allowed: true, ProfileRef: strings.Repeat("a", 64), Key: bytes.Repeat([]byte{7}, 32)}
}
func qwenSummary(id, model string, total int, at time.Time) string {
	return fmt.Sprintf(`{"version":1,"sessionId":%q,"timestamp":%d,"project":"private-project-canary","content":"private-message-canary","tools":{"private-tool-canary":{}},"models":{%q:{"requests":1,"inputTokens":%d,"outputTokens":0,"totalTokens":%d}}}`+"\n", id, at.UnixMilli(), model, total, total)
}
func TestQwenNativeIncrementalLastSummaryWins(t *testing.T) {
	a := qwenNativeAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "usage_record.jsonl")
	first := qwenSummary("private-session-canary", "qwen-model", 10, now)
	put(t, path, []byte(first))
	r := RefreshNative(context.Background(), root, cache, a, now)
	if r.Availability != "ok" || !r.Beta || r.Measurement != "completed-session-usage" || len(r.Rows) != 1 || *r.Rows[0].TotalTokens != 10 || r.BytesRead != int64(len(first)) {
		t.Fatal(r)
	}
	second := qwenSummary("private-session-canary", "qwen-new-model", 15, now)
	f, _ := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0600)
	_, _ = f.WriteString(second)
	f.Close()
	// Cache-only and five-minute gate do not read newly appended source bytes.
	r = ReadNativeCache(cache, a, now.Add(time.Minute))
	if r.Rows[0].Model != "qwen-model" {
		t.Fatal(r)
	}
	r = RefreshNative(context.Background(), root, cache, a, now.Add(time.Minute))
	if r.Rows[0].Model != "qwen-model" {
		t.Fatal(r)
	}
	r = RefreshNative(context.Background(), root, cache, a, now.Add(5*time.Minute))
	if len(r.Rows) != 1 || r.Rows[0].Model != "qwen-new-model" || *r.Rows[0].TotalTokens != 15 || r.BytesRead != int64(len(second)) {
		t.Fatal(r)
	}
	r = RefreshNative(context.Background(), root, cache, a, now.Add(10*time.Minute))
	if r.BytesRead != 0 || !r.ObservedAt.Equal(now) {
		t.Fatal(r)
	}
	b, _ := os.ReadFile(nativeCachePath(cache, a))
	out, _ := json.Marshal(r)
	for _, s := range []string{"private-session-canary", "private-project-canary", "private-message-canary", "private-tool-canary", root} {
		if bytes.Contains(append(b, out...), []byte(s)) {
			t.Fatal("private bytes persisted")
		}
	}
}
func TestQwenNativeTruncationRotationAndStale(t *testing.T) {
	a := qwenNativeAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "usage_record.jsonl")
	first := qwenSummary("one", "qwen-model", 10, now)
	second := qwenSummary("two", "qwen-model", 5, now)
	put(t, path, []byte(first+strings.TrimSuffix(second, "\n")))
	r := RefreshNative(context.Background(), root, cache, a, now)
	if r.Availability != "partial" || len(r.Rows) != 1 || *r.Rows[0].TotalTokens != 10 {
		t.Fatal(r)
	}
	f, _ := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0600)
	_, _ = f.WriteString("\n")
	f.Close()
	r = RefreshNative(context.Background(), root, cache, a, now.Add(10*time.Minute))
	if r.Availability != "ok" || *r.Rows[0].TotalTokens != 15 {
		t.Fatal(r)
	}
	// Replace/rotate the file. Keyed session dedup prevents double counting.
	_ = os.Rename(path, path+".old")
	put(t, path, []byte(first+second))
	r = RefreshNative(context.Background(), root, cache, a, now.Add(15*time.Minute))
	if *r.Rows[0].TotalTokens != 15 {
		t.Fatal(r)
	}
	_ = os.Remove(path)
	r = RefreshNative(context.Background(), root, cache, a, now.Add(20*time.Minute))
	if r.Availability != "not_detected" || r.Freshness != "stale" || *r.Rows[0].TotalTokens != 15 {
		t.Fatal(r)
	}
	r = ReadNativeCache(cache, a, now.AddDate(0, 0, 36))
	if len(r.Rows) != 0 {
		t.Fatal("retention exceeded")
	}
}
func TestQwenNativeAdmissionIsolationAndUnsafeSources(t *testing.T) {
	a := qwenNativeAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "usage_record.jsonl")
	put(t, path, []byte(qwenSummary("one", "qwen-model", 0, now)))
	disabled := a
	disabled.Allowed = false
	if r := RefreshNative(context.Background(), root, cache, disabled, now); r.Availability != "consent_required" {
		t.Fatal(r)
	}
	if _, err := os.Stat(filepath.Join(cache, "observed")); !os.IsNotExist(err) {
		t.Fatal("I/O before consent")
	}
	t.Setenv("MODELPLAN_READERS", "passive")
	r := RefreshNative(context.Background(), root, cache, a, now)
	if r.Availability != "ok" || *r.Rows[0].TotalTokens != 0 {
		t.Fatal(r)
	}
	other := a
	other.ProfileRef = strings.Repeat("b", 64)
	if len(ReadNativeCache(cache, other, now).Rows) != 0 {
		t.Fatal("cross-profile cache")
	}
	t.Setenv("MODELPLAN_READERS", "off")
	if r := RefreshNative(context.Background(), root, cache, a, now.Add(time.Hour)); r.Availability != "off" {
		t.Fatal(r)
	}
	t.Setenv("MODELPLAN_READERS", "")
	link := filepath.Join(t.TempDir(), "linked-root")
	_ = os.Symlink(root, link)
	r = RefreshNative(context.Background(), link, t.TempDir(), a, now)
	if r.Availability != "denied" || len(r.Rows) != 0 {
		t.Fatal(r)
	}
	a.Key = nil
	if r := RefreshNative(context.Background(), root, t.TempDir(), a, now); r.Availability != "privacy_blocked" {
		t.Fatal(r)
	}
}
func TestQwenNativeNoTranscriptFallbackAndBounds(t *testing.T) {
	a := qwenNativeAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	_ = os.MkdirAll(filepath.Join(root, "projects", "synthetic", "chats"), 0700)
	put(t, filepath.Join(root, "projects", "synthetic", "chats", "session.jsonl"), []byte(`{"private-message-canary":"must never be read"}`))
	r := RefreshNative(context.Background(), root, cache, a, now)
	if r.Availability != "not_detected" {
		t.Fatal(r)
	}
	put(t, filepath.Join(root, "usage_record.jsonl"), []byte(strings.Repeat("x", 129<<10)+"\n"))
	r = RefreshNative(context.Background(), root, cache, a, now.Add(10*time.Minute))
	if r.Availability != "not_supported_yet" || len(r.Rows) != 0 {
		t.Fatal(r)
	}
}
