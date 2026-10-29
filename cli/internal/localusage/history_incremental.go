package localusage

import (
	"bufio"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

// HistoryAccess contains authorised local-only inputs from CLIJIT. Key is the
// existing installation key; ProfileRef is an opaque keyed reference. Neither
// credentials nor raw identities are needed. No access is granted by detection.
type HistoryAccess struct {
	Admission           *consent.CaptureStamp
	CaptureAllowed      func(*consent.CaptureStamp) bool
	StillValid          func() bool
	Publish             func(func() error) error
	Allowed, Denied     bool
	Privacy, ProfileRef string
	Key                 []byte
}
type HistoryRow struct {
	Day    string `json:"day,omitempty"`
	Model  string `json:"model,omitempty"`
	Reason string `json:"reason,omitempty"`
	HistoryCounts
}
type HistoryResult struct {
	ValidationBytes int64        `json:"validationBytes"`
	Confidence      string       `json:"confidence"`
	Tool            string       `json:"tool"`
	Measurement     string       `json:"measurement"`
	Timezone        string       `json:"timezone"`
	Availability    string       `json:"availability"`
	Freshness       string       `json:"freshness"`
	Beta            bool         `json:"beta"`
	NextStep        string       `json:"nextStep"`
	ObservedAt      time.Time    `json:"observedAt,omitempty"`
	NextAttemptAt   time.Time    `json:"nextAttemptAt,omitempty"`
	Rows            []HistoryRow `json:"rows"`
	Unallocated     []HistoryRow `json:"unallocated"`
	BytesRead       int64        `json:"bytesRead"`
}
type historyStored struct {
	// Safe capture-time scope is independent of live cursor retention. An
	// explicit exclusion invalidates it permanently until a fresh root capture.
	CapturedScope string    `json:"capturedScope,omitempty"`
	ScopeRef      string    `json:"scopeRef,omitempty"`
	File          string    `json:"fileRef"`
	CapturedAt    time.Time `json:"capturedAt"`
	At            time.Time `json:"at"`
	Model         string    `json:"model,omitempty"`
	Reason        string    `json:"reason,omitempty"`
	HistoryCounts
}
type historyCursor struct {
	ChangeRef    string             `json:"changeRef"`
	Status       string             `json:"status"`
	Catchup      bool               `json:"catchup"`
	Retry        bool               `json:"retry,omitempty"`
	Offset       int64              `json:"offset"`
	Size         int64              `json:"size"`
	Modified     time.Time          `json:"modified"`
	FileRef      string             `json:"fileRef"`
	PrefixLength int64              `json:"prefixLength"`
	Prefix       string             `json:"prefix"`
	Tail         string             `json:"tail"`
	Decode       historyDecodeState `json:"decode"`
	// Projection-only bootstrap markers; no transcript data is retained.
	OmittedPrefix bool `json:"omittedPrefix,omitempty"`
	Align         bool `json:"align,omitempty"`
}
type historyState struct {
	Admission       *consent.CaptureStamp    `json:"admission,omitempty"`
	ValidationBytes int64                    `json:"validationBytes"`
	SchemaVersion   int                      `json:"schemaVersion"`
	Availability    string                   `json:"availability"`
	Files           map[string]historyCursor `json:"files"`
	Entries         map[string]historyStored `json:"entries"`
	BytesRead       int64                    `json:"bytesRead"`
	Projection      *ProjectionState         `json:"projection,omitempty"`
	Complete        bool                     `json:"complete,omitempty"`
}
type historyGate struct {
	SchemaVersion int `json:"schemaVersion"`
	At, Next      time.Time
	Failures      int
}

func historyHash(key []byte, domain, value string) string {
	h := hmac.New(sha256.New, key)
	h.Write([]byte(domain))
	h.Write([]byte{0})
	h.Write([]byte(value))
	return hex.EncodeToString(h.Sum(nil))
}
func historyAdmission(tool string, a HistoryAccess) string {
	if os.Getenv("MODELPLAN_HISTORY") == "off" || (tool == "gemini" && os.Getenv("MODELPLAN_GEMINI") == "off") || (tool == "qwen" && os.Getenv("MODELPLAN_QWEN") == "off") {
		return "off"
	}
	if a.StillValid != nil && !a.StillValid() {
		return "consent_required"
	}
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
	if (a.Privacy != "" && a.Privacy != "automatic" && a.Privacy != "passive") || (mode != "" && mode != "automatic" && mode != "passive") {
		return "privacy_blocked"
	}
	ref, err := hex.DecodeString(a.ProfileRef)
	if len(a.Key) != 32 || err != nil || len(ref) != 32 {
		return "privacy_blocked"
	}
	if historyDepth(tool) < 0 {
		return "not_supported_yet"
	}
	return ""
}
func historyNext(tool, state string) string {
	switch state {
	case "ok":
		return "Refresh local usage when needed and allowed"
	case "not_detected":
		return "Open " + tool + " to record local usage"
	case "off", "privacy_blocked", "consent_required":
		return "Review " + tool + " consent and privacy settings"
	case "denied":
		return "Retry " + tool + " local usage in Settings"
	case "not_supported_yet":
		return "Report the " + tool + " version and local usage format"
	case "partial":
		return "Review local usage coverage; missing model or day stays unknown"
	default:
		return "Wait until the next eligible local usage read"
	}
}
func historyPath(cache, tool string, a HistoryAccess) string {
	return filepath.Join(cache, "observed", "history-v1-"+tool+"-"+historyHash(a.Key, "history/profile", a.ProfileRef)+".json")
}
func historyGatePaths(cache, tool string) (string, string) {
	if tool == "qwen" {
		return filepath.Join(cache, "observed", "qwen-usage-gate-v1.json"), filepath.Join(cache, "observed", "qwen-usage.lock")
	}
	return filepath.Join(cache, "observed", "history-"+tool+"-gate-v1.json"), filepath.Join(cache, "observed", "history-"+tool+".lock")
}
func historyLoad(path string, v any, limit int64) bool {
	b, err := readRegular(path, limit)
	return err == nil && json.Unmarshal(b, v) == nil
}
func historySave(path string, v any) bool {
	b, err := json.Marshal(v)
	if err != nil || len(b) > 8<<20 {
		return false
	}
	if os.MkdirAll(filepath.Dir(path), 0700) != nil {
		return false
	}
	f, err := os.CreateTemp(filepath.Dir(path), ".history-*")
	if err != nil {
		return false
	}
	defer os.Remove(f.Name())
	_, err = f.Write(append(b, '\n'))
	closeErr := f.Close()
	return err == nil && closeErr == nil && os.Rename(f.Name(), path) == nil
}
func historyReadState(cache, tool string, a HistoryAccess) historyState {
	s := historyState{}
	if !historyLoad(historyPath(cache, tool, a), &s, 8<<20) || s.SchemaVersion != 1 || len(s.Files) > 256 || len(s.Entries) > 20000 {
		s = historyState{SchemaVersion: 1}
	}
	scope := historyConsentScope(tool)
	valid := false
	if a.CaptureAllowed != nil {
		valid = a.CaptureAllowed(s.Admission)
	} else {
		state, err := consent.Load(consent.Path())
		valid = err == nil && state.CaptureAllowed(s.Admission, scope)
	}
	if !valid {
		s = historyState{SchemaVersion: 1}
	}
	if s.Files == nil {
		s.Files = map[string]historyCursor{}
	}
	if s.Entries == nil {
		s.Entries = map[string]historyStored{}
	}
	return s
}

// ReadHistoryCache opens ModelPlan's sanitised cache only. It does not discover
// tools, stat their logs, read credentials, invoke commands or make requests.
func ReadHistoryCache(cache, tool string, a HistoryAccess, now time.Time) HistoryResult {
	r := HistoryResult{Confidence: "exact", Tool: tool, Measurement: "local-usage", Timezone: "UTC", Beta: true, Freshness: "unknown", Rows: []HistoryRow{}, Unallocated: []HistoryRow{}}
	if blocked := historyAdmission(tool, a); blocked != "" {
		r.Availability = blocked
		r.NextStep = historyNext(tool, blocked)
		return r
	}
	s := historyReadState(cache, tool, a)
	r.Availability = s.Availability
	if r.Availability == "" {
		r.Availability = "stale"
	}
	r.BytesRead = s.BytesRead
	r.ValidationBytes = s.ValidationBytes
	gatePath, _ := historyGatePaths(cache, tool)
	var gate historyGate
	historyLoad(gatePath, &gate, 4096)
	r.NextAttemptAt = gate.Next
	by := map[string]*HistoryRow{}
	for _, entry := range s.Entries {
		if tool == "grok" && !historyGrokScopeEligible(s, entry) {
			continue
		}
		if (!entry.At.IsZero() && (entry.At.After(now) || entry.At.Before(now.AddDate(0, 0, -35)))) || (entry.At.IsZero() && entry.CapturedAt.Before(now.AddDate(0, 0, -35))) {
			continue
		}
		day := ""
		if !entry.At.IsZero() {
			day = entry.At.UTC().Format("2006-01-02")
			if entry.At.After(r.ObservedAt) {
				r.ObservedAt = entry.At
			}
		}
		key := day + "\x00" + entry.Model + "\x00" + entry.Reason
		if row := by[key]; row != nil {
			row.HistoryCounts.add(entry.HistoryCounts)
		} else {
			by[key] = &HistoryRow{Day: day, Model: entry.Model, Reason: entry.Reason, HistoryCounts: entry.HistoryCounts}
		}
	}
	for _, row := range by {
		if row.Day == "" || row.Reason != "" {
			r.Unallocated = append(r.Unallocated, *row)
		} else {
			r.Rows = append(r.Rows, *row)
		}
	}
	less := func(rows []HistoryRow) func(int, int) bool {
		return func(i, j int) bool {
			if rows[i].Day != rows[j].Day {
				return rows[i].Day > rows[j].Day
			}
			if rows[i].Model != rows[j].Model {
				return rows[i].Model < rows[j].Model
			}
			return rows[i].Reason < rows[j].Reason
		}
	}
	sort.Slice(r.Rows, less(r.Rows))
	sort.Slice(r.Unallocated, less(r.Unallocated))
	if !r.ObservedAt.IsZero() {
		r.Freshness = "fresh"
		if now.Sub(r.ObservedAt) > 24*time.Hour || r.Availability != "ok" {
			r.Freshness = "stale"
		}
	}
	r.NextStep = historyNext(tool, r.Availability)
	return r
}
func historyOpen(path string) (*os.File, os.FileInfo, error) {
	if err := safePath(path, false); err != nil {
		return nil, nil, err
	}
	before, err := os.Lstat(path)
	if err != nil {
		return nil, nil, err
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, nil, err
	}
	after, err := f.Stat()
	if err != nil || !os.SameFile(before, after) || !after.Mode().IsRegular() {
		f.Close()
		return nil, nil, fmt.Errorf("source changed")
	}
	return f, after, nil
}

// Enumerate bounded known record paths only. No browser/config/auth/history
// directories are searched; symlink components and subagent trees are rejected.
func historyDiscover(root, tool string) ([]string, bool, error) {
	if err := safePath(root, true); err != nil {
		return nil, false, err
	}
	budget := 4096
	limited := false
	var files []string
	var walk func(string, int) error
	walk = func(rel string, depth int) error {
		if len(files) >= 256 {
			limited = true
			return nil
		}
		dir, err := os.Open(filepath.Join(root, rel))
		if err != nil {
			return err
		}
		defer dir.Close()
		for budget > 0 {
			entries, err := dir.ReadDir(min(256, budget))
			budget -= len(entries)
			for _, entry := range entries {
				if entry.Type()&os.ModeSymlink != 0 {
					continue
				}
				name := entry.Name()
				next := filepath.Join(rel, name)
				if entry.IsDir() {
					if historyDescend(tool, next, depth) && name != "subagents" && name != "subagent" && !strings.HasPrefix(name, ".") {
						if err := walk(next, depth+1); err != nil {
							limited = true
						}
						if len(files) >= 256 {
							return nil
						}
					}
					continue
				}
				if historyAllowed(tool, next) {
					files = append(files, next)
					if len(files) >= 256 {
						limited = true
						return nil
					}
				}
			}
			if err == io.EOF {
				return nil
			}
			if err != nil {
				return err
			}
		}
		limited = true
		return nil
	}
	err := walk("", 0)
	sort.Strings(files)
	return files, limited, err
}

// Absence/unreadability cannot erase known capture provenance. Positive
// contradictory evidence still overrides a historical root classification.
func historyGrokScopeEligible(s historyState, entry historyStored) bool {
	current := s.Files[entry.ScopeRef].Decode.GrokScope
	if entry.CapturedScope == "excluded" || current == "excluded" {
		return false
	}
	return entry.CapturedScope == "root" || current == "root"
}

var historyAttempts sync.Map

type historyCountReader struct {
	io.Reader
	bytes *int64
}

func (r historyCountReader) Read(b []byte) (int, error) {
	n, err := r.Reader.Read(b)
	*r.bytes += int64(n)
	return n, err
}

// RefreshHistory incrementally reads only the selected tool's authorised store.
// Immutable files are skipped, JSONL resumes at its last complete line, and
// changed JSON snapshots replace keyed rows without rescanning other files.
func RefreshHistory(ctx context.Context, tool, root, cache string, a HistoryAccess, now time.Time) HistoryResult {
	if tool == projectionTool {
		return HistoryResult{Availability: "not_supported_yet"}
	}
	return refreshHistory(ctx, tool, root, cache, a, now, nil)
}

// The projection seam uses the same discovery, validation, complete-line cursor
// advancement and atomic state writer as count-oriented history.
func refreshHistory(ctx context.Context, tool, root, cache string, a HistoryAccess, now time.Time, projection *projectionRun) HistoryResult {
	admission := a.Admission
	if admission == nil {
		state, _ := consent.Current()
		admission = state.CaptureStamp(historyConsentScope(tool))
	}
	floor := 5 * time.Minute
	if projection != nil {
		floor = ProjectionInterval
	}
	if historyAdmission(tool, a) != "" || cache == "" {
		return ReadHistoryCache(cache, tool, a, now)
	}
	gatePath, lockPath := historyGatePaths(cache, tool)
	_ = os.MkdirAll(filepath.Dir(lockPath), 0700)
	if fi, err := os.Stat(lockPath); err == nil && time.Since(fi.ModTime()) > time.Minute {
		_ = os.Remove(lockPath)
	}
	lock, err := os.OpenFile(lockPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return ReadHistoryCache(cache, tool, a, now)
	}
	lock.Close()
	defer os.Remove(lockPath)
	gate := historyGate{SchemaVersion: 1}
	if _, err := os.Lstat(gatePath); err == nil {
		if !historyLoad(gatePath, &gate, 4096) || gate.SchemaVersion != 1 {
			r := ReadHistoryCache(cache, tool, a, now)
			r.Availability = "not_supported_yet"
			r.NextStep = historyNext(tool, r.Availability)
			return r
		}
	} else if !os.IsNotExist(err) {
		return ReadHistoryCache(cache, tool, a, now)
	}
	attemptKey := cache + "/" + tool
	if last, ok := historyAttempts.Load(attemptKey); ok && now.Sub(last.(time.Time)) < floor {
		return ReadHistoryCache(cache, tool, a, now)
	}
	if now.Before(gate.Next) || now.Before(gate.At.Add(floor)) {
		return ReadHistoryCache(cache, tool, a, now)
	}
	gate.At = now.UTC()
	gate.Next = now.Add(floor).UTC()
	if !historySave(gatePath, gate) {
		return ReadHistoryCache(cache, tool, a, now)
	}
	historyAttempts.Store(attemptKey, now)
	s := historyReadState(cache, tool, a)
	if projection != nil {
		projection.start(s.Projection)
	}
	// Migrate schema-1 readings while their original safe scope cursor still
	// exists, before discovery may prune it. No new provenance is guessed.
	if tool == "grok" {
		for id, entry := range s.Entries {
			scope := s.Files[entry.ScopeRef].Decode.GrokScope
			if scope == "excluded" || (scope == "root" && entry.CapturedScope == "") {
				entry.CapturedScope = scope
				s.Entries[id] = entry
			}
		}
	}
	s.BytesRead = 0
	s.ValidationBytes = 0
	s.Availability = "ok"
	for ref, e := range s.Entries {
		if (!e.At.IsZero() && e.At.Before(now.AddDate(0, 0, -35))) || (e.At.IsZero() && e.CapturedAt.Before(now.AddDate(0, 0, -35))) {
			delete(s.Entries, ref)
		}
	}
	files, limited, err := historyDiscover(root, tool)
	if err != nil {
		if os.IsNotExist(err) {
			s.Availability = "not_detected"
		} else {
			s.Availability = "denied"
		}
	} else if len(files) == 0 {
		s.Availability = "not_detected"
	}
	if limited {
		s.Availability = "partial"
	}
	if !limited && err == nil {
		live := map[string]bool{}
		for _, rel := range files {
			live[historyHash(a.Key, "history/path/"+a.ProfileRef+"/"+tool, rel)] = true
		}
		if tool == "grok" && s.Availability == "ok" {
			for _, entry := range s.Entries {
				if historyGrokScopeEligible(s, entry) && !live[entry.File] {
					s.Availability = "partial"
					break
				}
			}
		}
		for key := range s.Files {
			if !live[key] {
				delete(s.Files, key)
			}
		}
	}
	if projection != nil {
		projection.discovery(files, !limited && err == nil, a)
	}
	verifiedGrokScopes := map[string]bool{}
	for _, rel := range files {
		if projection != nil && projection.failed {
			break
		}
		if ctx.Err() != nil {
			return ReadHistoryCache(cache, tool, a, now)
		}
		if projection != nil && projection.records >= projectionRecordLimit {
			s.Availability = "partial"
			break
		}
		if s.BytesRead >= 32<<20 {
			s.Availability = "partial"
			break
		}
		fileKey := historyHash(a.Key, "history/path/"+a.ProfileRef+"/"+tool, rel)
		if _, exists := s.Files[fileKey]; !exists && len(s.Files) >= 256 {
			s.Availability = "partial"
			break
		}
		scopeRef := ""
		if tool == "grok" && filepath.Base(rel) == "usage.json" {
			summaryRel := filepath.Join(filepath.Dir(rel), "summary.json")
			scopeRef = historyHash(a.Key, "history/path/"+a.ProfileRef+"/"+tool, summaryRel)
			scope := s.Files[scopeRef].Decode.GrokScope
			if scope != "root" || !verifiedGrokScopes[scopeRef] {
				if scope != "excluded" {
					s.Availability = "partial"
				}
				continue
			}
		}
		cursor := s.Files[fileKey]
		if cursor.Offset < 0 || cursor.PrefixLength < 0 || cursor.PrefixLength > 1024 {
			cursor = historyCursor{}
		}
		f, info, err := historyOpenSource(filepath.Join(root, rel))
		if err != nil {
			s.Availability = "partial"
			continue
		}
		identity, change := historyMetadata(info, a.Key)
		if identity == "" || change == "" {
			f.Close()
			s.Availability = "not_supported_yet"
			continue
		}
		if identity == cursor.FileRef && change == cursor.ChangeRef && info.Size() == cursor.Size && !cursor.Catchup && !cursor.Retry {
			if tool == "grok" && filepath.Base(rel) == "summary.json" && cursor.Decode.GrokScope == "root" {
				verifiedGrokScopes[fileKey] = true
			}
			if cursor.Status != "" && cursor.Status != "ok" && s.Availability == "ok" {
				s.Availability = cursor.Status
			}
			if projection != nil {
				projection.reset("", cursor.OmittedPrefix)
				projection.file(rel, fileKey, cursor.Status == "ok", true)
			}
			f.Close()
			continue
		}
		isJSONL := strings.HasSuffix(rel, ".jsonl")
		validate := func(start, n int64) string {
			hash, count := historySegment(f, a.Key, start, n)
			s.ValidationBytes += count
			return hash
		}
		reset := ""
		switch {
		case cursor.ChangeRef == "":
			reset = "initial"
		case identity != cursor.FileRef:
			reset = "replacement"
		case info.Size() < cursor.Offset:
			reset = "truncation"
		case (change != cursor.ChangeRef && info.Size() <= cursor.Size) || validate(0, cursor.PrefixLength) != cursor.Prefix || validate(max(0, cursor.Offset-1024), min(cursor.Offset, 1024)) != cursor.Tail:
			reset = "rewrite"
		}
		if reset != "" {
			cursor = historyCursor{}
			if projection != nil && info.Size() > projectionBootstrapBytes {
				cursor.Offset = info.Size() - projectionBootstrapBytes
				cursor.OmittedPrefix, cursor.Align = true, true
			}
		}
		if projection != nil {
			projection.reset(reset, cursor.OmittedPrefix)
		}
		cursor.FileRef = identity
		fileStatus := "ok"
		sourceChanged := false
		retrySource := false
		parsedStart := s.BytesRead
		markFile := func(status string) {
			fileStatus = status
			if s.Availability == "ok" || status == "not_supported_yet" {
				s.Availability = status
			}
		}
		apply := func(data []byte, sequence int64) bool {
			if projection != nil {
				return projection.line(rel, fileKey, data, sequence)
			}
			if !isJSONL {
				cursor.Decode = historyDecodeState{}
			}
			rows, err := decodeHistory(tool, data, isJSONL, &cursor.Decode)
			if err != nil {
				markFile("partial")
				if errors.Is(err, errUnsupportedHistory) {
					markFile("not_supported_yet")
				}
				return false
			}
			if tool == "grok" && filepath.Base(rel) == "summary.json" && cursor.Decode.GrokScope == "excluded" {
				for id, entry := range s.Entries {
					if entry.ScopeRef == fileKey {
						entry.CapturedScope = "excluded"
						s.Entries[id] = entry
					}
				}
			}
			if !isJSONL {
				for id, e := range s.Entries {
					if e.File == fileKey {
						delete(s.Entries, id)
					}
				}
			}
			for _, row := range rows {
				c := row.Counts.valid()
				if !c.known() {
					continue
				}
				if row.At.After(now) || (!row.At.IsZero() && row.At.Before(now.AddDate(0, 0, -35))) {
					continue
				}
				if row.At.IsZero() && row.Unallocated == "" {
					row.Unallocated = "source_timestamp_unavailable"
				}
				if row.ID == "" {
					row.ID = fmt.Sprintf("offset:%d", sequence)
				}
				if len(row.ID) > 512 {
					continue
				}
				id := historyHash(a.Key, "history/entry/"+a.ProfileRef+"/"+tool, historySession(tool, rel)+"\x00"+row.ID)
				if _, exists := s.Entries[id]; !exists && len(s.Entries) >= 20000 {
					markFile("partial")
					return false
				}
				capturedScope := ""
				if tool == "grok" {
					capturedScope = "root"
				}
				s.Entries[id] = historyStored{CapturedScope: capturedScope, ScopeRef: scopeRef, File: fileKey, CapturedAt: now.UTC(), At: row.At, Model: row.Model, Reason: row.Unallocated, HistoryCounts: c}
			}
			return true
		}
		if isJSONL {
			if _, err := f.Seek(cursor.Offset, io.SeekStart); err != nil {
				markFile("partial")
				retrySource = true
			} else {
				reader := bufio.NewReader(historyCountReader{Reader: io.LimitReader(f, min(int64(8<<20), 32<<20-s.BytesRead)), bytes: &s.BytesRead})
				consumed := int64(0)
				for consumed < 8<<20 && s.BytesRead < 32<<20 {
					if ctx.Err() != nil {
						break
					}
					if projection != nil && projection.records >= projectionRecordLimit {
						break
					}
					line, err := reader.ReadBytes('\n')
					consumed += int64(len(line))
					if err != nil {
						retrySource = err != io.EOF
						if err != io.EOF || len(line) > 0 {
							markFile("partial")
						}
						break
					}
					if len(line) > 1<<20 {
						markFile("not_supported_yet")
						break
					}
					previous := cursor.Offset
					if cursor.Align {
						// Tail bootstrap starts at a byte boundary. Discard the first
						// fragment and expose only complete subsequent records.
						cursor.Offset += int64(len(line))
						cursor.Align = false
						continue
					}
					if !apply(line, previous) {
						break
					}
					cursor.Offset += int64(len(line))
				}
			}
			if cursor.Offset < info.Size() && fileStatus == "ok" {
				markFile("partial")
			}
		} else {
			if info.Size() > 8<<20 || info.Size() > 32<<20-s.BytesRead {
				markFile("partial")
				f.Close()
				continue
			}
			b, err := io.ReadAll(io.LimitReader(f, 8<<20+1))
			s.BytesRead += int64(len(b))
			if err != nil || len(b) > 8<<20 || !apply(b, 0) {
				if fileStatus == "ok" {
					markFile("partial")
				}
				cursor.Retry = err != nil
				cursor.Size = info.Size()
				cursor.ChangeRef = change
				cursor.Status = fileStatus
				cursor.Modified = info.ModTime()
				s.Files[fileKey] = cursor
				f.Close()
				continue
			}
			cursor.Offset = int64(len(b))
		}
		if cursor.PrefixLength == 0 {
			cursor.PrefixLength = min(cursor.Offset, 1024)
		}
		cursor.Prefix = validate(0, cursor.PrefixLength)
		cursor.Tail = validate(max(0, cursor.Offset-1024), min(cursor.Offset, 1024))
		if projection != nil {
			// A file that changed during recovery cannot establish a complete
			// projection. Keep its initial generation so the next read retries.
			after, err := f.Stat()
			afterID, afterChange := historyMetadata(after, a.Key)
			if err != nil || identity != afterID || change != afterChange {
				markFile("partial")
				sourceChanged = true
			}
		}
		f.Close()
		// Incomplete unchanged suffixes wait for source changes. Transient I/O
		// failures remain retryable independently of bounded catch-up.
		cursor.Retry = retrySource
		cursor.Catchup = sourceChanged || (isJSONL && ((s.BytesRead-parsedStart >= 8<<20) || (s.BytesRead >= 32<<20)) && cursor.Offset < info.Size())
		if projection != nil && projection.records >= projectionRecordLimit && cursor.Offset < info.Size() {
			cursor.Catchup = true
		}
		cursor.Status = fileStatus
		cursor.ChangeRef = change
		cursor.Size = info.Size()
		cursor.Modified = info.ModTime()
		s.Files[fileKey] = cursor
		if projection != nil {
			projection.file(rel, fileKey, fileStatus == "ok", false)
		}
		if tool == "grok" && filepath.Base(rel) == "summary.json" && cursor.Decode.GrokScope == "root" {
			verifiedGrokScopes[fileKey] = true
		}
	}
	if ctx.Err() != nil || historyAdmission(tool, a) != "" {
		return ReadHistoryCache(cache, tool, a, now)
	}
	if projection != nil {
		if !projection.finish(&s, now) {
			r := ReadHistoryCache(cache, tool, a, now)
			r.Availability = "partial"
			return r
		}
	}
	if projection == nil && len(s.Entries) == 0 && s.Availability == "ok" {
		s.Availability = "not_supported_yet"
	}
	for _, e := range s.Entries {
		if e.Reason != "" || e.Model == "" {
			if s.Availability == "ok" {
				s.Availability = "partial"
			}
			break
		}
	}
	if s.Availability == "ok" {
		gate.Failures = 0
		gate.Next = now.Add(floor).UTC()
	} else {
		gate.Failures = min(gate.Failures+1, 4)
		wait := time.Duration(10*(1<<(gate.Failures-1))) * time.Minute
		if gate.Failures == 4 {
			wait = time.Hour
		}
		if projection != nil {
			wait = min(time.Duration(1<<gate.Failures)*floor, time.Minute)
		}
		gate.Next = now.Add(wait).UTC()
	}
	if ctx.Err() != nil || historyAdmission(tool, a) != "" {
		return ReadHistoryCache(cache, tool, a, now)
	}
	save := func() error {
		s.Admission = admission
		if !historySave(historyPath(cache, tool, a), s) {
			return errors.New("history cache unavailable")
		}
		historySave(gatePath, gate)
		return nil
	}
	var publishErr error
	if a.Publish != nil {
		publishErr = a.Publish(save)
	} else {
		publishErr = save()
	}
	if publishErr != nil {
		r := ReadHistoryCache(cache, tool, a, now)
		r.Availability = "stale"
		r.Freshness = "stale"
		r.NextStep = historyNext(tool, "stale")
		return r
	}
	return ReadHistoryCache(cache, tool, a, now)
}

// ForgetHistoryProfile deletes this profile's derived readings/checkpoints only.
// CLIJIT cancels in-flight work before calling it. The provider attempt gate is
// retained so disconnect/reconnect cannot bypass the five-minute floor.
func ForgetHistoryProfile(cache, tool string, a HistoryAccess) error {
	ref, err := hex.DecodeString(a.ProfileRef)
	if !filepath.IsAbs(cache) || historyDepth(tool) < 0 || len(a.Key) != 32 || err != nil || len(ref) != 32 {
		return fmt.Errorf("local history profile unavailable")
	}
	_, lockPath := historyGatePaths(cache, tool)
	if info, err := os.Stat(lockPath); err == nil && time.Since(info.ModTime()) > time.Minute {
		_ = os.Remove(lockPath)
	}
	if _, err := os.Stat(filepath.Dir(lockPath)); os.IsNotExist(err) {
		return nil
	}
	lock, err := os.OpenFile(lockPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return fmt.Errorf("local history refresh must finish before cleanup")
	}
	lock.Close()
	defer os.Remove(lockPath)
	if err := os.Remove(historyPath(cache, tool, a)); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("local history cleanup unavailable")
	}
	return nil
}

func historyConsentScope(tool string) string {
	if tool == projectionTool {
		tool = "claude"
	}
	return tool + ".local_history"
}
