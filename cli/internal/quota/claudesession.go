package quota

// Passive Claude session state. The owner confirmed the optional fields in a
// sanitised probe on 2026-10-27: top-level effort, message.model and
// message.usage.speed. No plugin, status line, credential or provider call is used.

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	claudeSessionChunk   = 256 << 10
	claudeSessionFiles   = 128
	claudeSessionEntries = 4096
)

// ClaudeSessionAccess is supplied by shared consent orchestration. The root is
// locally admitted, never a publication path. Passive-only allows this collector;
// off and missing consent do not. JSON readers use only the sanitized cache.
type ClaudeSessionAccess struct {
	Allowed    bool
	Root       string
	StillValid func() bool
}

type claudeSessionTurn struct {
	SessionKey string    `json:"sessionKey"`
	Model      string    `json:"model,omitempty"`
	Effort     string    `json:"effort,omitempty"`
	Fast       *bool     `json:"fastMode,omitempty"`
	ObservedAt time.Time `json:"observedAt"`
}

type claudeSessionCheckpoint struct {
	SourceKey    string             `json:"sourceKey"`
	FileKey      string             `json:"fileKey"`
	Offset       int64              `json:"offset"`
	SkippingLine bool               `json:"skippingLine,omitempty"`
	Partial      bool               `json:"partial,omitempty"`
	Turn         *claudeSessionTurn `json:"turn,omitempty"`
}

type claudeSessionCache struct {
	SchemaVersion int                       `json:"schemaVersion"`
	RootKey       string                    `json:"rootKey"`
	Partial       bool                      `json:"partial,omitempty"`
	Files         []claudeSessionCheckpoint `json:"files"`
}

func claudeSessionPath(cache string) string {
	return filepath.Join(cache, "observed", "claude-sessions.json")
}

func loadClaudeSessions(cache string) (*claudeSessionCache, error) {
	if cache == "" {
		return nil, errors.New("session cache unavailable")
	}
	b, status := readBounded(claudeSessionPath(cache), 256<<10)
	if status == "missing" {
		return &claudeSessionCache{SchemaVersion: 1, Files: []claudeSessionCheckpoint{}}, nil
	}
	var s claudeSessionCache
	if status != "" || json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 || len(s.Files) > claudeSessionFiles {
		return nil, errors.New("session cache unavailable")
	}
	for _, f := range s.Files {
		if f.Offset < 0 {
			return nil, errors.New("session cache unavailable")
		}
	}
	return &s, nil
}

// Reuse the existing installation identity key. Initializing it uses a fixed
// opaque index reference, never a transcript identity or content. The cache-only
// path below reads this key without creating or updating anything.
func claudeSessionIdentityKey(cache string, create bool, now time.Time) []byte {
	if cache == "" {
		return nil
	}
	if create && assignSubscription(cache, "claude-session-index", "local", now) == "" {
		return nil
	}
	b, status := readBounded(subscriptionsPath(cache), 256<<10)
	var m subscriptionMap
	if status != "" || json.Unmarshal(b, &m) != nil || m.SchemaVersion != 1 {
		return nil
	}
	key, err := hex.DecodeString(m.Key)
	if err != nil || len(key) != 32 {
		return nil
	}
	return key
}

func claudeSessionHash(key []byte, domain, value string) string {
	h := hmac.New(sha256.New, key)
	_, _ = h.Write([]byte("claude-session:" + domain + "\x00" + value))
	return hex.EncodeToString(h.Sum(nil))
}

type claudeSessionFile struct {
	path string
	info os.FileInfo
}

// Discover names only. Transcript bytes are read incrementally below. Bounds
// make initial discovery/recovery finite; partial discovery is reported honestly.
func discoverClaudeSessions(root string) ([]claudeSessionFile, bool, error) {
	rootInfo, rootErr := os.Lstat(root)
	if rootErr != nil || !rootInfo.IsDir() {
		return nil, false, errors.New("session directory unavailable")
	}
	projects := filepath.Join(root, "projects")
	info, err := os.Lstat(projects)
	if os.IsNotExist(err) {
		return nil, false, nil
	}
	if err != nil || !info.IsDir() {
		return nil, false, errors.New("session directory unavailable")
	}
	files := []claudeSessionFile{}
	seen := 0
	partial := false
	var visit func(string, int) error
	visit = func(dir string, depth int) error {
		if depth > 5 {
			partial = true
			return nil
		}
		f, err := os.Open(dir)
		if err != nil {
			return errors.New("session directory unavailable")
		}
		defer f.Close()
		for {
			entries, readErr := f.ReadDir(64)
			for _, entry := range entries {
				seen++
				if seen > claudeSessionEntries {
					partial = true
					return nil
				}
				if entry.Type()&os.ModeSymlink != 0 {
					continue
				}
				path := filepath.Join(dir, entry.Name())
				if entry.IsDir() {
					if entry.Name() != "subagents" {
						if err := visit(path, depth+1); err != nil {
							return err
						}
					}
					if seen > claudeSessionEntries {
						return nil
					}
					continue
				}
				if !strings.HasSuffix(entry.Name(), ".jsonl") || strings.HasPrefix(entry.Name(), "agent-") {
					continue
				}
				info, err := entry.Info()
				if err != nil || !info.Mode().IsRegular() {
					continue
				}
				files = append(files, claudeSessionFile{path, info})
			}
			if readErr != nil {
				if readErr != io.EOF {
					return errors.New("session directory unavailable")
				}
				return nil
			}
		}
	}
	if err := visit(projects, 0); err != nil {
		return nil, partial, err
	}
	sort.Slice(files, func(i, j int) bool {
		if files[i].info.ModTime().Equal(files[j].info.ModTime()) {
			return files[i].path < files[j].path
		}
		return files[i].info.ModTime().After(files[j].info.ModTime())
	})
	if len(files) > claudeSessionFiles {
		files = files[:claudeSessionFiles]
		partial = true
	}
	return files, partial, nil
}

// Unix file identity detects replacement even if the replacement is larger. On
// platforms without device/inode metadata the collector refuses the file rather
// than silently reusing a cursor for an unrelated source. No OS identifiers persist.
func claudeSessionFileIdentity(info os.FileInfo) string {
	v := reflect.ValueOf(info.Sys())
	if v.Kind() != reflect.Pointer || v.IsNil() {
		return ""
	}
	v = v.Elem()
	if v.Kind() != reflect.Struct {
		return ""
	}
	d, i := v.FieldByName("Dev"), v.FieldByName("Ino")
	dev, devOK := claudeSessionFileNumber(d)
	ino, inoOK := claudeSessionFileNumber(i)
	if !devOK || !inoOK {
		return ""
	}
	return dev + ":" + ino
}

func claudeSessionFileNumber(v reflect.Value) (string, bool) {
	if !v.IsValid() {
		return "", false
	}
	if v.CanUint() {
		return strconv.FormatUint(v.Uint(), 16), true
	}
	if v.CanInt() {
		return strconv.FormatInt(v.Int(), 16), true
	}
	return "", false
}

// RefreshClaudeSessions is an explicit collector, never called by Read/--json.
// Only offsets, keyed source/session identities and model/effort/fast are stored.
func RefreshClaudeSessions(ctx context.Context, cache string, a ClaudeSessionAccess, now time.Time) error {
	if !a.Allowed || cache == "" || !filepath.IsAbs(a.Root) || strings.EqualFold(os.Getenv("MODELPLAN_READERS"), "off") || (a.StillValid != nil && !a.StillValid()) {
		return errors.New("session consent required")
	}
	unlock, ok := lockFile(claudeSessionPath(cache)+".lock", now, time.Minute)
	if !ok {
		return errors.New("another session read is running")
	}
	defer unlock()
	s, err := loadClaudeSessions(cache)
	if err != nil {
		return err
	}
	key := claudeSessionIdentityKey(cache, true, now)
	if len(key) == 0 {
		return errors.New("identity key unavailable")
	}
	rootKey := claudeSessionHash(key, "root", a.Root)
	previous := map[string]claudeSessionCheckpoint{}
	if s.RootKey == rootKey {
		for _, cp := range s.Files {
			previous[cp.SourceKey] = cp
		}
	}
	files, partial, err := discoverClaudeSessions(a.Root)
	if err != nil {
		return err
	}
	next := claudeSessionCache{SchemaVersion: 1, RootKey: rootKey, Partial: partial, Files: []claudeSessionCheckpoint{}}
	for _, file := range files {
		if ctx.Err() != nil {
			return errors.New("session read canceled")
		}
		sourceKey := claudeSessionHash(key, "source", file.path)
		cp := previous[sourceKey]
		cp.SourceKey = sourceKey
		id := claudeSessionFileIdentity(file.info)
		if id == "" {
			next.Partial = true
			continue
		}
		fileKey := claudeSessionHash(key, "file", id)
		if cp.FileKey != fileKey || file.info.Size() < cp.Offset {
			cp = claudeSessionCheckpoint{SourceKey: sourceKey, FileKey: fileKey}
			if file.info.Size() > claudeSessionChunk {
				cp.Offset = file.info.Size() - claudeSessionChunk
				cp.SkippingLine = true
				cp.Partial = true
			}
		}
		if err := readClaudeSessionAppend(file, &cp, key, now); err != nil {
			next.Partial = true
			next.Files = append(next.Files, cp)
			continue
		}
		next.Partial = next.Partial || cp.Partial
		next.Files = append(next.Files, cp)
	}
	if a.StillValid != nil && !a.StillValid() {
		return errors.New("session consent changed")
	}
	b, err := json.Marshal(next)
	if err != nil || len(b) > 256<<10 {
		return errors.New("session cache unavailable")
	}
	if err := writeAtomic(claudeSessionPath(cache), append(b, '\n')); err != nil {
		return errors.New("session cache unavailable")
	}
	return nil
}

func readClaudeSessionAppend(file claudeSessionFile, cp *claudeSessionCheckpoint, key []byte, now time.Time) error {
	if file.info.Size() == cp.Offset {
		return nil
	}
	f, err := os.Open(file.path)
	if err != nil {
		return errors.New("session unavailable")
	}
	defer f.Close()
	actual, err := f.Stat()
	if err != nil || !actual.Mode().IsRegular() || !os.SameFile(actual, file.info) {
		return errors.New("session changed")
	}
	n := actual.Size() - cp.Offset
	if n < 0 {
		return errors.New("session changed")
	}
	if n > claudeSessionChunk {
		n = claudeSessionChunk
		cp.Partial = true
	}
	b := make([]byte, int(n))
	read, readErr := f.ReadAt(b, cp.Offset)
	if readErr != nil && readErr != io.EOF {
		return errors.New("session unavailable")
	}
	b = b[:read]
	for len(b) > 0 {
		i := bytes.IndexByte(b, '\n')
		if i < 0 {
			if actual.Size()-cp.Offset > int64(len(b)) {
				cp.Offset += int64(len(b))
				cp.SkippingLine = true
				cp.Partial = true
			}
			break // an incomplete last row is retried after its newline is appended
		}
		if !cp.SkippingLine {
			fallback := strings.TrimSuffix(filepath.Base(file.path), ".jsonl")
			if turn := parseClaudeSessionTurn(b[:i], key, fallback, file.info.ModTime(), now); turn != nil && (cp.Turn == nil || !turn.ObservedAt.Before(cp.Turn.ObservedAt)) {
				cp.Turn = turn
			}
		}
		cp.Offset += int64(i + 1)
		cp.SkippingLine = false
		b = b[i+1:]
	}
	return nil
}

var claudeSessionModel = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9._:/-]{0,127}$`)

func parseClaudeSessionTurn(b, key []byte, fallback string, mtime, now time.Time) *claudeSessionTurn {
	var row struct {
		Type      string `json:"type"`
		Timestamp string `json:"timestamp"`
		SessionID string `json:"sessionId"`
		Sidechain bool   `json:"isSidechain"`
		Meta      bool   `json:"isMeta"`
		Compact   bool   `json:"isCompactSummary"`
		Effort    string `json:"effort"`
		Message   struct {
			Model string `json:"model"`
			Usage struct {
				Speed string `json:"speed"`
			} `json:"usage"`
		} `json:"message"`
	}
	if json.Unmarshal(b, &row) != nil || row.Type != "assistant" || row.Sidechain || row.Meta || row.Compact {
		return nil
	}
	at := mtime.UTC()
	if row.Timestamp != "" {
		parsed, err := time.Parse(time.RFC3339Nano, row.Timestamp)
		if err != nil {
			return nil
		}
		at = parsed.UTC()
	}
	if at.After(now.Add(5 * time.Minute)) {
		return nil
	}
	id := row.SessionID
	if id == "" {
		id = fallback
	}
	if id == "" || len(id) > 256 {
		return nil
	}
	turn := &claudeSessionTurn{SessionKey: claudeSessionHash(key, "session", id), ObservedAt: at}
	if claudeSessionModel.MatchString(row.Message.Model) {
		turn.Model = row.Message.Model
	}
	switch row.Effort {
	case "low", "medium", "high", "max":
		turn.Effort = row.Effort
	}
	switch row.Message.Usage.Speed {
	case "standard":
		v := false
		turn.Fast = &v
	case "fast":
		v := true
		turn.Fast = &v
	}
	return turn
}

func applyClaudeSessions(r *Report, cache, currentSession string) {
	s, err := loadClaudeSessions(cache)
	if err != nil || len(s.Files) == 0 {
		return
	}
	key := claudeSessionIdentityKey(cache, false, time.Time{})
	if len(key) == 0 {
		return
	}
	wanted := ""
	if currentSession != "" {
		wanted = claudeSessionHash(key, "session", currentSession)
	}
	var recent, selected *claudeSessionTurn
	for _, file := range s.Files {
		if t := file.Turn; t != nil {
			if recent == nil || t.ObservedAt.After(recent.ObservedAt) {
				recent = t
			}
			if t.SessionKey == wanted && (selected == nil || t.ObservedAt.After(selected.ObservedAt)) {
				selected = t
			}
		}
	}
	attribution := "current-thread"
	if selected == nil {
		selected = recent
		attribution = "recent-thread"
	}
	if selected == nil {
		return
	}
	h := &Harness{Model: selected.Model, Effort: selected.Effort, FastMode: selected.Fast, SessionKey: selected.SessionKey, ObservedAt: &selected.ObservedAt, Attribution: attribution}
	index := -1
	count := 0
	for i := range r.Accounts {
		if r.Accounts[i].Source == "claude-code" {
			index = i
			count++
		}
	}
	if count == 1 {
		r.Accounts[index].Harness = h
	} else {
		r.Accounts = append(r.Accounts, Account{Source: "claude-code", Via: "session-local", ObservedAt: selected.ObservedAt, Harness: h, Windows: []Window{}})
	}
	status, reason := "ok", "Passive local session state"
	if s.Partial {
		status, reason = "partial", "Bounded local session view; older records were not scanned"
	}
	r.Sources = append(r.Sources, SourceStatus{Source: "claude-session", Status: status, Reason: reason})
}
