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

type qwenCountedSource struct {
	nativeSource
	content *int64
	darwin  bool
}

func (f qwenCountedSource) Read(b []byte) (int, error) {
	n, err := f.nativeSource.Read(b)
	*f.content += int64(n)
	return n, err
}
func (f qwenCountedSource) ReadAt(b []byte, at int64) (int, error) {
	n, err := f.nativeSource.ReadAt(b, at)
	*f.content += int64(n)
	return n, err
}
func (f qwenCountedSource) Stat() (os.FileInfo, error) {
	fi, err := f.nativeSource.Stat()
	if err != nil || !f.darwin {
		return fi, err
	}
	return qwenDarwinInfo{FileInfo: fi}, nil
}

type qwenDarwinInfo struct{ os.FileInfo }

func (fi qwenDarwinInfo) Sys() any {
	return &struct {
		Dev       int32
		Ino       uint64
		Ctimespec struct{ Sec, Nsec int64 }
	}{Dev: -17, Ino: 123, Ctimespec: struct{ Sec, Nsec int64 }{fi.ModTime().Unix(), int64(fi.ModTime().Nanosecond())}}
}
func TestQwenDarwinSignedDeviceAndSyntheticSource(t *testing.T) {
	a := qwenNativeAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "usage_record.jsonl")
	put(t, path, []byte(qwenSummary("session", "qwen-model", 10, now)))
	fi, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	darwin := qwenDarwinInfo{FileInfo: fi}
	ref := nativeFileRef(darwin, a.Key)
	if ref == "" || ref != nativeFileRef(darwin, a.Key) || strings.Contains(ref, "-17") {
		t.Fatal("signed Darwin device rejected or disclosed", ref)
	}
	old := nativeOpenSource
	t.Cleanup(func() { nativeOpenSource = old })
	var content int64
	nativeOpenSource = func(path string) (nativeSource, error) {
		f, err := nativeOpen(path)
		if err != nil {
			return nil, err
		}
		return qwenCountedSource{nativeSource: f, content: &content, darwin: true}, nil
	}
	r := RefreshNative(context.Background(), root, cache, a, now)
	if r.Availability != "ok" || len(r.Rows) != 1 || *r.Rows[0].TotalTokens != 10 {
		t.Fatal(r)
	}
}
func TestQwenUnchangedSourceHasZeroContentIO(t *testing.T) {
	a := qwenNativeAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "usage_record.jsonl")
	first := qwenSummary("one", "qwen-model", 10, now)
	put(t, path, []byte(first))
	old := nativeOpenSource
	t.Cleanup(func() { nativeOpenSource = old })
	var content int64
	nativeOpenSource = func(path string) (nativeSource, error) {
		f, err := nativeOpen(path)
		if err != nil {
			return nil, err
		}
		return qwenCountedSource{nativeSource: f, content: &content}, nil
	}
	RefreshNative(context.Background(), root, cache, a, now)
	content = 0
	r := RefreshNative(context.Background(), root, cache, a, now.Add(5*time.Minute))
	if content != 0 || r.BytesRead != 0 || r.ValidationBytes != 0 {
		t.Fatal("unchanged source content reread", content, r)
	}
	second := qwenSummary("two", "qwen-model", 5, now)
	f, _ := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0600)
	_, _ = f.WriteString(second)
	f.Close()
	content = 0
	r = RefreshNative(context.Background(), root, cache, a, now.Add(10*time.Minute))
	if *r.Rows[0].TotalTokens != 15 || r.BytesRead != int64(len(second)) || r.ValidationBytes == 0 || content != r.BytesRead+r.ValidationBytes {
		t.Fatal("append/validation I/O unaccounted", content, r)
	}
}
func TestQwenSameSizeMiddleRewriteCannotStayCurrent(t *testing.T) {
	a := qwenNativeAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "usage_record.jsonl")
	var lines []string
	for i := 0; i < 30; i++ {
		lines = append(lines, qwenSummary(fmt.Sprintf("session-%02d", i), "qwen-model", 10, now))
	}
	original := strings.Join(lines, "")
	put(t, path, []byte(original))
	r := RefreshNative(context.Background(), root, cache, a, now)
	if *r.Rows[0].TotalTokens != 300 {
		t.Fatal(r)
	}
	info, _ := os.Stat(path)
	lines[15] = qwenSummary("session-15", "qwen-model", 20, now)
	changed := strings.Join(lines, "")
	if len(original) != len(changed) || original[:1024] != changed[:1024] || original[len(original)-1024:] != changed[len(changed)-1024:] {
		t.Fatal("fixture must preserve size and endpoints")
	}
	// Separate filesystem timestamp quanta while preserving mtime below;
	// this exercises the ctime signal independently of size/prefix/tail/mtime.
	time.Sleep(2 * time.Millisecond)
	put(t, path, []byte(changed))
	_ = os.Chtimes(path, info.ModTime(), info.ModTime())
	r = RefreshNative(context.Background(), root, cache, a, now.Add(5*time.Minute))
	if r.Availability != "ok" || len(r.Rows) != 1 || *r.Rows[0].TotalTokens != 310 || r.BytesRead == 0 {
		t.Fatal("middle rewrite served stale totals as current", r)
	}
}
