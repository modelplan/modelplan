package qwenusage

import (
	"bufio"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"sync"
	"time"
)

// NativeAccess is CLIJIT's fail-closed local-reader seam. The installation key is
// transient; ProfileRef is a keyed opaque profile reference, never a path/account.
type NativeAccess struct {
	Allowed, Denied     bool
	Privacy, ProfileRef string
	Key                 []byte
}
type DailyUsage struct {
	Day   string `json:"day"`
	Model string `json:"model"`
	Totals
}
type NativeReport struct {
	Source        string       `json:"source"`
	Measurement   string       `json:"measurement"`
	Timezone      string       `json:"timezone"`
	Availability  string       `json:"availability"`
	Freshness     string       `json:"freshness"`
	Beta          bool         `json:"beta"`
	NextStep      string       `json:"nextStep"`
	ObservedAt    time.Time    `json:"observedAt,omitempty"`
	NextAttemptAt time.Time    `json:"nextAttemptAt,omitempty"`
	Rows          []DailyUsage `json:"rows"`
	BytesRead     int64        `json:"bytesRead"`
}
type nativeSummary struct {
	At     time.Time         `json:"at"`
	Models map[string]Totals `json:"models"`
}
type nativeState struct {
	SchemaVersion int                      `json:"schemaVersion"`
	Offset        int64                    `json:"offset"`
	FileRef       string                   `json:"fileRef"`
	PrefixLength  int64                    `json:"prefixLength"`
	Prefix        string                   `json:"prefix"`
	Tail          string                   `json:"tail"`
	Availability  string                   `json:"availability"`
	Summaries     map[string]nativeSummary `json:"summaries"`
	BytesRead     int64                    `json:"bytesRead"`
}
type nativeGate struct {
	SchemaVersion int `json:"schemaVersion"`
	At, Next      time.Time
	Failures      int
}

func nativeHash(key []byte, domain, value string) string {
	h := hmac.New(sha256.New, key)
	h.Write([]byte(domain))
	h.Write([]byte{0})
	h.Write([]byte(value))
	return hex.EncodeToString(h.Sum(nil))
}
func nativeAdmission(a NativeAccess) string {
	mode := strings.ToLower(strings.TrimSpace(os.Getenv("MODELPLAN_READERS")))
	if mode == "off" || a.Privacy == "off" {
		return "off"
	}
	if a.Denied {
		return "denied"
	}
	if !a.Allowed {
		return "consent_required"
	}
	if mode != "" && mode != "automatic" && mode != "passive" {
		return "privacy_blocked"
	}
	ref, err := hex.DecodeString(a.ProfileRef)
	if len(a.Key) != 32 || err != nil || len(ref) != 32 {
		return "privacy_blocked"
	}
	return ""
}
func nativeNext(state string) string {
	switch state {
	case "ok":
		return "Refresh local usage when needed and allowed"
	case "not_detected":
		return "Open Qwen Code to record local usage"
	case "off", "consent_required", "privacy_blocked":
		return "Review Qwen Code consent and privacy settings"
	case "denied":
		return "Retry Qwen Code local usage in Settings"
	case "not_supported_yet":
		return "Report the Qwen Code version and usage-record format"
	case "partial":
		return "Wait for Qwen Code to complete its local usage record"
	default:
		return "Wait until the next eligible local usage read"
	}
}
func nativeCachePath(cache string, a NativeAccess) string {
	return filepath.Join(cache, "observed", "qwen-usage-v1-"+nativeHash(a.Key, "qwen/profile", a.ProfileRef)+".json")
}
func nativeJSON(path string, v any, limit int64) bool {
	b, err := nativeReadRegular(path, limit)
	return err == nil && json.Unmarshal(b, v) == nil
}
func nativeSave(path string, v any) bool {
	if os.MkdirAll(filepath.Dir(path), 0700) != nil {
		return false
	}
	b, err := json.Marshal(v)
	if err != nil || len(b) > 8<<20 {
		return false
	}
	f, err := os.CreateTemp(filepath.Dir(path), ".qwen-usage-*")
	if err != nil {
		return false
	}
	defer os.Remove(f.Name())
	_, err = f.Write(append(b, '\n'))
	closeErr := f.Close()
	return err == nil && closeErr == nil && os.Rename(f.Name(), path) == nil
}
func nativeOpen(path string) (*os.File, error) {
	if !filepath.IsAbs(path) {
		return nil, errors.New("unsafe path")
	}
	for p := filepath.Clean(path); ; p = filepath.Dir(p) {
		fi, err := os.Lstat(p)
		if err != nil {
			return nil, err
		}
		if fi.Mode()&os.ModeSymlink != 0 {
			return nil, errors.New("unsafe path")
		}
		if p == filepath.Dir(p) {
			break
		}
	}
	before, err := os.Lstat(path)
	if err != nil || !before.Mode().IsRegular() {
		return nil, errors.New("unavailable regular file")
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	after, err := f.Stat()
	if err != nil || !os.SameFile(before, after) {
		f.Close()
		return nil, errors.New("changed file")
	}
	return f, nil
}
func nativeReadRegular(path string, limit int64) ([]byte, error) {
	f, err := nativeOpen(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	b, err := io.ReadAll(io.LimitReader(f, limit+1))
	if int64(len(b)) > limit {
		return nil, errors.New("too large")
	}
	return b, err
}

// Stable inode/device values are transient; only their keyed reference persists.
func nativeFileRef(fi os.FileInfo, key []byte) string {
	v := reflect.ValueOf(fi.Sys())
	if v.Kind() == reflect.Pointer {
		v = v.Elem()
	}
	if v.Kind() != reflect.Struct {
		return ""
	}
	dev, ino := v.FieldByName("Dev"), v.FieldByName("Ino")
	if !dev.IsValid() || !ino.IsValid() || !dev.CanUint() || !ino.CanUint() {
		return ""
	}
	return nativeHash(key, "qwen/file", fmt.Sprintf("%d:%d", dev.Uint(), ino.Uint()))
}
func nativeSegment(f *os.File, key []byte, start, length int64) string {
	if length == 0 {
		return ""
	}
	b := make([]byte, length)
	if _, err := f.ReadAt(b, start); err != nil {
		return ""
	}
	return nativeHash(key, "qwen/checkpoint", string(b))
}
func nativeLoad(cache string, a NativeAccess) nativeState {
	s := nativeState{}
	if !nativeJSON(nativeCachePath(cache, a), &s, 8<<20) || s.SchemaVersion != 1 || s.Offset < 0 || s.PrefixLength < 0 || s.PrefixLength > 1024 || len(s.Summaries) > 20000 {
		s = nativeState{SchemaVersion: 1}
	}
	if s.Summaries == nil {
		s.Summaries = map[string]nativeSummary{}
	}
	return s
}

// ReadNativeCache never opens Qwen files. It exposes only completed-session
// aggregate tokens/model/UTC day, with source timestamps, never remaining quota.
func ReadNativeCache(cache string, a NativeAccess, now time.Time) NativeReport {
	r := NativeReport{Source: "qwen-code-local-aggregate", Measurement: "completed-session-usage", Timezone: "UTC", Beta: true, Freshness: "unknown", Rows: []DailyUsage{}}
	if blocked := nativeAdmission(a); blocked != "" {
		r.Availability = blocked
		r.NextStep = nativeNext(blocked)
		return r
	}
	s := nativeLoad(cache, a)
	r.Availability = s.Availability
	if r.Availability == "" {
		r.Availability = "stale"
	}
	r.BytesRead = s.BytesRead
	gate := nativeGate{}
	nativeJSON(filepath.Join(cache, "observed", "qwen-usage-gate-v1.json"), &gate, 4096)
	r.NextAttemptAt = gate.Next
	by := map[string]*DailyUsage{}
	for _, summary := range s.Summaries {
		if summary.At.Before(now.AddDate(0, 0, -35)) || summary.At.After(now) {
			continue
		}
		if summary.At.After(r.ObservedAt) {
			r.ObservedAt = summary.At
		}
		day := summary.At.UTC().Format("2006-01-02")
		for id, t := range summary.Models {
			k := day + ":" + id
			if row := by[k]; row != nil {
				nativeAdd(&row.Totals, t)
			} else {
				by[k] = &DailyUsage{Day: day, Model: id, Totals: t}
			}
		}
	}
	for _, row := range by {
		r.Rows = append(r.Rows, *row)
	}
	sort.Slice(r.Rows, func(i, j int) bool {
		if r.Rows[i].Day == r.Rows[j].Day {
			return r.Rows[i].Model < r.Rows[j].Model
		}
		return r.Rows[i].Day > r.Rows[j].Day
	})
	if !r.ObservedAt.IsZero() {
		r.Freshness = "fresh"
		if now.Sub(r.ObservedAt) > 24*time.Hour || r.Availability != "ok" {
			r.Freshness = "stale"
		}
	}
	r.NextStep = nativeNext(r.Availability)
	return r
}
func nativeAdd(a *Totals, b Totals) {
	sum := func(dst **int64, src *int64) {
		if *dst == nil || src == nil || **dst > 1<<62-*src {
			*dst = nil
			return
		}
		v := **dst + *src
		*dst = &v
	}
	sum(&a.Requests, b.Requests)
	sum(&a.InputTokens, b.InputTokens)
	sum(&a.OutputTokens, b.OutputTokens)
	sum(&a.CachedTokens, b.CachedTokens)
	sum(&a.ThoughtsTokens, b.ThoughtsTokens)
	sum(&a.TotalTokens, b.TotalTokens)
}
func nativeParse(line []byte, a NativeAccess, now time.Time) (string, nativeSummary, bool) {
	var raw struct {
		Version int               `json:"version"`
		Session string            `json:"sessionId"`
		At      int64             `json:"timestamp"`
		Models  map[string]Totals `json:"models"`
	}
	if json.Unmarshal(line, &raw) != nil || raw.Version != 1 || len(raw.Session) == 0 || len(raw.Session) > 256 || len(raw.Models) == 0 || len(raw.Models) > 256 {
		return "", nativeSummary{}, false
	}
	at := time.UnixMilli(raw.At).UTC()
	if at.After(now) {
		return "", nativeSummary{}, false
	}
	if at.Before(now.AddDate(0, 0, -35)) {
		return "", nativeSummary{}, true
	}
	summary := nativeSummary{At: at, Models: map[string]Totals{}}
	for id, counts := range raw.Models {
		// Local identifier grammar excludes URLs, resource/account selectors and paths.
		if len(id) > 96 || strings.ContainsAny(id, "/:@") || !modelID.MatchString(id) {
			return "", nativeSummary{}, false
		}
		summary.Models[id] = clean(counts)
	}
	return nativeHash(a.Key, "qwen/session/"+a.ProfileRef, raw.Session), summary, true
}

var nativeAttempts sync.Map

// RefreshNative reads only <authorised-root>/usage_record.jsonl. It never scans
// transcripts, runs Qwen, opens OAuth/settings or requires a manual export.
func RefreshNative(ctx context.Context, root, cache string, a NativeAccess, now time.Time) NativeReport {
	if nativeAdmission(a) != "" || cache == "" {
		return ReadNativeCache(cache, a, now)
	}
	lockPath := filepath.Join(cache, "observed", "qwen-usage.lock")
	_ = os.MkdirAll(filepath.Dir(lockPath), 0700)
	if fi, err := os.Stat(lockPath); err == nil && time.Since(fi.ModTime()) > time.Minute {
		_ = os.Remove(lockPath)
	}
	lock, err := os.OpenFile(lockPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return ReadNativeCache(cache, a, now)
	}
	lock.Close()
	defer os.Remove(lockPath)
	gatePath := filepath.Join(cache, "observed", "qwen-usage-gate-v1.json")
	gate := nativeGate{SchemaVersion: 1}
	if _, err := os.Lstat(gatePath); err == nil {
		if !nativeJSON(gatePath, &gate, 4096) || gate.SchemaVersion != 1 {
			r := ReadNativeCache(cache, a, now)
			r.Availability = "not_supported_yet"
			r.NextStep = nativeNext(r.Availability)
			return r
		}
	} else if !os.IsNotExist(err) {
		return ReadNativeCache(cache, a, now)
	}
	if last, ok := nativeAttempts.Load(cache); ok && now.Sub(last.(time.Time)) < 5*time.Minute {
		return ReadNativeCache(cache, a, now)
	}
	if now.Before(gate.Next) || now.Before(gate.At.Add(5*time.Minute)) {
		return ReadNativeCache(cache, a, now)
	}
	gate.At = now.UTC()
	gate.Next = now.Add(5 * time.Minute).UTC()
	if !nativeSave(gatePath, gate) {
		return ReadNativeCache(cache, a, now)
	}
	nativeAttempts.Store(cache, now)
	s := nativeLoad(cache, a)
	s.BytesRead = 0
	for ref, summary := range s.Summaries {
		if summary.At.Before(now.AddDate(0, 0, -35)) {
			delete(s.Summaries, ref)
		}
	}
	s.Availability = "not_detected"
	f, err := nativeOpen(filepath.Join(root, "usage_record.jsonl"))
	if err == nil {
		defer f.Close()
		fi, _ := f.Stat()
		ref := nativeFileRef(fi, a.Key)
		if ref == "" {
			s.Availability = "not_supported_yet"
		} else {
			if s.FileRef != ref || fi.Size() < s.Offset || nativeSegment(f, a.Key, 0, s.PrefixLength) != s.Prefix || nativeSegment(f, a.Key, max(0, s.Offset-1024), min(s.Offset, 1024)) != s.Tail {
				s.Offset = 0
				s.PrefixLength = 0
				s.Prefix = ""
				s.Tail = ""
			}
			s.FileRef = ref
			_, _ = f.Seek(s.Offset, io.SeekStart)
			reader := bufio.NewReader(io.LimitReader(f, 4<<20))
			s.Availability = "ok"
			for s.BytesRead < 4<<20 {
				if ctx.Err() != nil {
					return ReadNativeCache(cache, a, now)
				}
				line, err := reader.ReadBytes('\n')
				s.BytesRead += int64(len(line))
				if err != nil {
					if len(line) > 0 {
						s.Availability = "partial"
					}
					break
				}
				if len(line) > 128<<10 {
					s.Availability = "not_supported_yet"
					break
				}
				s.Offset += int64(len(line))
				if ref, summary, valid := nativeParse(line, a, now); valid {
					if ref != "" {
						if _, exists := s.Summaries[ref]; !exists && len(s.Summaries) >= 20000 {
							s.Offset -= int64(len(line))
							s.Availability = "not_supported_yet"
							break
						}
						s.Summaries[ref] = summary
					}
				} else {
					s.Availability = "partial"
				}
				if len(s.Summaries) > 20000 {
					s.Availability = "partial"
					break
				}
			}
			if s.Offset < fi.Size() && s.Availability == "ok" {
				s.Availability = "partial"
			}
			if s.PrefixLength == 0 {
				s.PrefixLength = min(s.Offset, 1024)
			}
			s.Prefix = nativeSegment(f, a.Key, 0, s.PrefixLength)
			s.Tail = nativeSegment(f, a.Key, max(0, s.Offset-1024), min(s.Offset, 1024))
		}
	} else if !os.IsNotExist(err) {
		s.Availability = "denied"
	}
	for ref, summary := range s.Summaries {
		if summary.At.Before(now.AddDate(0, 0, -35)) {
			delete(s.Summaries, ref)
		}
	}
	if ctx.Err() != nil || nativeAdmission(a) != "" {
		return ReadNativeCache(cache, a, now)
	}
	if s.Availability == "ok" {
		gate.Failures = 0
		gate.Next = now.Add(5 * time.Minute).UTC()
	} else {
		gate.Failures = min(gate.Failures+1, 4)
		wait := time.Duration(10*(1<<(gate.Failures-1))) * time.Minute
		if gate.Failures == 4 {
			wait = time.Hour
		}
		gate.Next = now.Add(wait).UTC()
	}
	if !nativeSave(nativeCachePath(cache, a), s) {
		r := ReadNativeCache(cache, a, now)
		r.Availability = "stale"
		r.Freshness = "stale"
		r.NextStep = nativeNext("stale")
		return r
	}
	nativeSave(gatePath, gate)
	return ReadNativeCache(cache, a, now)
}
