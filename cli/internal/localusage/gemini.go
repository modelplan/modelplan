// Package localusage reads opt-in local token accounting, never subscription allowance.
package localusage

import (
	"bufio"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
	"unicode"
)

const (
	HistoryDays  = 35
	maxEntries   = 20000
	maxFiles     = 256
	maxFileBytes = 8 << 20
	maxReadBytes = 32 << 20
	maxMessages  = 50000
)

type setting struct {
	SchemaVersion int    `json:"schemaVersion"`
	Enabled       bool   `json:"gemini"`
	Qwen          bool   `json:"qwen,omitempty"`
	Key           string `json:"identityKey"`
}

func SettingsPath(home string) string {
	return filepath.Join(home, ".config", "modelplan", "local-usage.json")
}
func GeminiHome(home string) string {
	if p := os.Getenv("MODELPLAN_GEMINI_HOME"); p != "" && filepath.IsAbs(p) {
		return filepath.Clean(p)
	}
	return filepath.Join(home, ".gemini")
}

// SetGemini records explicit consent and an independent local HMAC key. It touches no
// Gemini files; the key protects session/message references, not an account credential.
func SetGemini(home string, on bool) error { return setSource(home, "gemini", on) }

func setSource(home, source string, on bool) error {
	path := SettingsPath(home)
	s, err := loadSetting(path)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return errors.New("local usage settings unavailable or invalid")
	}
	if s.Key == "" && on {
		b := make([]byte, 32)
		if _, err = rand.Read(b); err != nil {
			return err
		}
		s.Key = hex.EncodeToString(b)
	}
	s.SchemaVersion = 1
	if source == "qwen" {
		s.Qwen = on
	} else {
		s.Enabled = on
	}
	b, _ := json.MarshalIndent(s, "", "  ")
	if err = os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return err
	}
	f, err := os.CreateTemp(filepath.Dir(path), ".local-usage-*")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	if err = f.Chmod(0600); err == nil {
		_, err = f.Write(append(b, '\n'))
	}
	closeErr := f.Close()
	if err != nil {
		return err
	}
	if closeErr != nil {
		return closeErr
	}
	return os.Rename(f.Name(), path)
}

func loadSetting(path string) (setting, error) {
	var s setting
	b, err := readRegular(path, 4096)
	if err != nil {
		return s, err
	}
	if json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 {
		return s, errors.New("invalid schema")
	}
	if s.Enabled || s.Qwen {
		key, err := hex.DecodeString(s.Key)
		if err != nil || len(key) != 32 {
			return s, errors.New("invalid identity key")
		}
	}
	return s, nil
}

// Counts retain the tool's native meanings: input includes cached prompt tokens;
// output and thoughts are separate. No list-price cost or remaining quota is inferred.
type Counts struct {
	Input    *int64 `json:"inputTokens"`
	Output   *int64 `json:"outputTokens"`
	Cached   *int64 `json:"cachedTokens"`
	Thoughts *int64 `json:"thoughtTokens"`
	Tool     *int64 `json:"toolTokens"`
	Total    *int64 `json:"totalTokens"`
}

type Row struct {
	Day      string `json:"day"`
	Model    string `json:"model"`
	Messages int    `json:"observedMessages"`
	Counts
}

type Session struct {
	Ref      string    `json:"ref"`
	FirstAt  time.Time `json:"firstAt"`
	LastAt   time.Time `json:"lastAt"`
	Messages int       `json:"observedMessages"`
	Counts
}

type Coverage struct {
	FilesSeen             int  `json:"filesSeen"`
	FilesRead             int  `json:"filesRead"`
	FilesSkipped          int  `json:"filesSkipped"`
	MessagesWithoutTokens int  `json:"messagesWithoutTokens"`
	Truncated             bool `json:"truncated"`
}

type Report struct {
	Source         string     `json:"source"`
	Enabled        bool       `json:"enabled"`
	Status         string     `json:"status"`
	Reason         string     `json:"reason,omitempty"`
	EvaluatedAt    time.Time  `json:"evaluatedAt"`
	LastObservedAt *time.Time `json:"lastObservedAt"`
	ReadPaths      []string   `json:"readPaths"`
	Hosts          []string   `json:"hosts"`
	Privacy        string     `json:"privacy"`
	Scope          string     `json:"scope"`
	HistoryDays    int        `json:"historyDays"`
	Coverage       Coverage   `json:"coverage"`
	Rows           []Row      `json:"rows"`
	Sessions       []Session  `json:"sessions"`
}

// GeminiStatus reads only modelplan's own consent setting, never Gemini data.
func GeminiStatus(home string, now time.Time) Report { return sourceStatus(home, now, geminiTool) }

func sourceStatus(home string, now time.Time, tool historyTool) Report {
	root := tool.home(home)
	r := Report{Source: tool.source, Status: "off", Reason: "not-enabled", EvaluatedAt: now.UTC(),
		ReadPaths: tool.paths(root),
		Hosts:     []string{}, Privacy: "Local token/model/timestamp metadata only; credentials are never read, printed or stored; prompts, replies and raw identifiers are never printed or stored. No network calls.",
		Scope: "available-local-history; input includes cached tokens; output excludes thoughts; no account quota", HistoryDays: HistoryDays, Rows: []Row{}, Sessions: []Session{}}
	if tool.source == "qwen" {
		r.Scope = "available-local-history; native prompt/cached and candidate/thought counters may overlap; no account quota"
	}
	s, err := loadSetting(SettingsPath(home))
	if err != nil {
		if !errors.Is(err, os.ErrNotExist) {
			r.Status, r.Reason = "invalid", "local-usage-settings-invalid"
		}
		return r
	}
	if (tool.source == "gemini" && !s.Enabled) || (tool.source == "qwen" && !s.Qwen) {
		return r
	}
	r.Enabled = true
	if os.Getenv("MODELPLAN_HISTORY") == "off" || os.Getenv(tool.stopEnv) == "off" {
		r.Reason = "disabled-by-environment"
		return r
	}
	r.Status, r.Reason = "unknown", "not-read"
	return r
}

type tokens struct {
	Input    *int64 `json:"input"`
	Output   *int64 `json:"output"`
	Cached   *int64 `json:"cached"`
	Thoughts *int64 `json:"thoughts"`
	Tool     *int64 `json:"tool"`
	Total    *int64 `json:"total"`
}
type message struct {
	ID        string  `json:"id"`
	Type      string  `json:"type"`
	Timestamp string  `json:"timestamp"`
	Model     string  `json:"model"`
	Tokens    *tokens `json:"tokens"`
}
type record struct {
	UUID          string      `json:"uuid"`
	CWD           string      `json:"cwd"`
	UsageMetadata *qwenTokens `json:"usageMetadata"`
	Session       string      `json:"sessionId"`
	Project       string      `json:"projectHash"`
	Messages      []message   `json:"messages"`
	message
	Set *struct {
		Session  string    `json:"sessionId"`
		Project  string    `json:"projectHash"`
		Messages []message `json:"messages"`
	} `json:"$set"`
}
type observation struct {
	message
	session string
	at      time.Time
}
type candidate struct {
	path string
	at   time.Time
	size int64
}

// ReadGemini recomputes bounded recent history without a token cache. JSON snapshots,
// JSONL full-message records and legacy $set.messages checkpoints are deduplicated by
// message id across files/forks/resumes. Conversation edits/rewinds do not refund usage.
func ReadGemini(home string, now time.Time) Report { return readHistory(home, now, geminiTool) }

func readHistory(home string, now time.Time, tool historyTool) Report {
	r := sourceStatus(home, now, tool)
	if r.Status != "unknown" {
		return r
	} // no Gemini path is opened before opt-in
	s, err := loadSetting(SettingsPath(home))
	if err != nil {
		r.Status, r.Reason = "invalid", "local-usage-settings-invalid"
		return r
	}
	key, _ := hex.DecodeString(s.Key)
	ref := func(kind, id string) string {
		h := hmac.New(sha256.New, key)
		if tool.source == "qwen" {
			kind = "qwen:" + kind
		}
		_, _ = h.Write([]byte(kind + "\x00" + id))
		return hex.EncodeToString(h.Sum(nil)[:16])
	}
	files, err := discover(tool.home(home), &r.Coverage, tool)
	if err != nil {
		r.Status, r.Reason = "unavailable", "history-root-unavailable-or-unsafe"
		return r
	}
	sort.Slice(files, func(i, j int) bool {
		if files[i].at.Equal(files[j].at) {
			return files[i].path < files[j].path
		}
		return files[i].at.After(files[j].at)
	})
	observations := map[string]observation{}
	readBytes := int64(0)
	localNow := now.Local()
	cutoff := time.Date(localNow.Year(), localNow.Month(), localNow.Day(), 0, 0, 0, 0, localNow.Location()).AddDate(0, 0, -HistoryDays+1)
	for i, f := range files {
		if i >= maxFiles || readBytes+f.size > maxReadBytes {
			r.Coverage.Truncated = true
			break
		}
		if f.size > maxFileBytes {
			r.Coverage.FilesSkipped++
			continue
		}
		b, err := readRegular(f.path, min(maxFileBytes, maxReadBytes-readBytes))
		readBytes += int64(len(b))
		if err != nil {
			r.Coverage.FilesSkipped++
			continue
		}
		records, err := tool.parse(b, strings.HasSuffix(f.path, ".jsonl"))
		if err != nil {
			r.Coverage.FilesSkipped++
			continue
		}
		session, project := "", ""
		// Metadata can precede or follow messages in append-only histories.
		for _, rec := range records {
			if rec.Session != "" {
				session = rec.Session
			}
			if rec.Project != "" {
				project = rec.Project
			}
			if rec.Set != nil {
				if rec.Set.Session != "" {
					session = rec.Set.Session
				}
				if rec.Set.Project != "" {
					project = rec.Set.Project
				}
			}
		}
		if session == "" || project == "" {
			r.Coverage.FilesSkipped++
			continue
		}
		r.Coverage.FilesRead++
		latest := map[string]message{}
		accept := func(m message) {
			if m.ID != "" && m.Type == tool.messageType {
				old, ok := latest[m.ID]
				if !ok || m.Tokens != nil || old.Tokens == nil {
					latest[m.ID] = m
				}
			}
		}
		for _, rec := range records {
			accept(rec.message)
			for _, m := range rec.Messages {
				accept(m)
			}
			if rec.Set != nil {
				for _, m := range rec.Set.Messages {
					accept(m)
				}
			}
		}
		for id, m := range latest {
			at, err := time.Parse(time.RFC3339Nano, m.Timestamp)
			if err != nil || at.Before(cutoff) || at.After(now.Add(5*time.Minute)) {
				continue
			}
			k := ref("message", id)
			if _, seen := observations[k]; seen {
				continue
			} // newest file wins; snapshots are never summed
			if len(observations) >= maxMessages {
				r.Coverage.Truncated = true
				break
			}
			observations[k] = observation{m, ref("session", project+"\x00"+session), at}
		}
	}
	rows := map[string]*Row{}
	sessions := map[string]*Session{}
	for _, o := range observations {
		model := cleanModel(o.Model)
		if model == "" {
			model = "unknown"
		}
		day := o.at.In(time.Local).Format("2006-01-02")
		rk := day + "\x00" + model
		row := rows[rk]
		if row == nil {
			row = &Row{Day: day, Model: model}
			rows[rk] = row
		}
		sess := sessions[o.session]
		if sess == nil {
			sess = &Session{Ref: o.session, FirstAt: o.at.UTC(), LastAt: o.at.UTC()}
			sessions[o.session] = sess
		}
		c := countsOf(o.Tokens)
		row.Counts.add(c, row.Messages == 0)
		row.Messages++
		sess.Counts.add(c, sess.Messages == 0)
		sess.Messages++
		if o.at.Before(sess.FirstAt) {
			sess.FirstAt = o.at.UTC()
		}
		if o.at.After(sess.LastAt) {
			sess.LastAt = o.at.UTC()
		}
		if r.LastObservedAt == nil || o.at.After(*r.LastObservedAt) {
			at := o.at.UTC()
			r.LastObservedAt = &at
		}
		if o.Tokens == nil {
			r.Coverage.MessagesWithoutTokens++
		}
	}
	for _, row := range rows {
		r.Rows = append(r.Rows, *row)
	}
	for _, sess := range sessions {
		r.Sessions = append(r.Sessions, *sess)
	}
	sort.Slice(r.Rows, func(i, j int) bool {
		if r.Rows[i].Day == r.Rows[j].Day {
			return r.Rows[i].Model < r.Rows[j].Model
		}
		return r.Rows[i].Day > r.Rows[j].Day
	})
	sort.Slice(r.Sessions, func(i, j int) bool {
		if r.Sessions[i].LastAt.Equal(r.Sessions[j].LastAt) {
			return r.Sessions[i].Ref < r.Sessions[j].Ref
		}
		return r.Sessions[i].LastAt.After(r.Sessions[j].LastAt)
	})
	r.Status, r.Reason = "ok", ""
	if len(r.Rows) == 0 {
		r.Status, r.Reason = "empty", "no-supported-local-usage"
	}
	if r.Coverage.Truncated || r.Coverage.FilesSkipped > 0 {
		r.Status, r.Reason = "partial", "bounded-or-unreadable-history"
	}
	return r
}

func countsOf(t *tokens) Counts {
	if t == nil {
		return Counts{}
	}
	known := func(p *int64) *int64 {
		if p == nil || *p < 0 || *p > 1e12 {
			return nil
		}
		v := *p
		return &v
	}
	return Counts{known(t.Input), known(t.Output), known(t.Cached), known(t.Thoughts), known(t.Tool), known(t.Total)}
}
func (c *Counts) add(x Counts, first bool) {
	add := func(a **int64, b *int64) {
		if first {
			if b != nil {
				n := *b
				*a = &n
			}
			return
		}
		if *a == nil || b == nil || **a > math.MaxInt64-*b {
			*a = nil
			return
		}
		n := **a + *b
		*a = &n
	}
	add(&c.Input, x.Input)
	add(&c.Output, x.Output)
	add(&c.Cached, x.Cached)
	add(&c.Thoughts, x.Thoughts)
	add(&c.Tool, x.Tool)
	add(&c.Total, x.Total)
}
func cleanModel(s string) string {
	if len(s) > 120 {
		return ""
	}
	for _, r := range s {
		if !(unicode.IsLetter(r) || unicode.IsDigit(r) || strings.ContainsRune("._:/-", r)) {
			return ""
		}
	}
	return s
}

func parseRecords(b []byte, jsonl bool) ([]record, error) {
	if !jsonl {
		var r record
		if json.Unmarshal(b, &r) != nil {
			return nil, errors.New("unsupported JSON history")
		}
		return []record{r}, nil
	}
	sc := bufio.NewScanner(strings.NewReader(string(b)))
	sc.Buffer(make([]byte, 4096), maxFileBytes)
	out := []record{}
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		var r record
		if json.Unmarshal([]byte(line), &r) != nil {
			return nil, errors.New("incomplete JSONL history")
		}
		out = append(out, r)
		if len(out) > maxMessages {
			return nil, errors.New("too many records")
		}
	}
	return out, sc.Err()
}

// Discovery traverses only known project/chats layouts, never oauth_creds.json,
// settings, telemetry, Antigravity or arbitrary descendants. Symlinks are refused.
func discover(root string, c *Coverage, tool historyTool) ([]candidate, error) {
	if err := safePath(root, true); err != nil {
		return nil, err
	}
	budget := maxEntries
	list := func(path string) ([]os.DirEntry, error) {
		if err := safePath(path, true); err != nil {
			return nil, err
		}
		d, err := os.Open(path)
		if err != nil {
			return nil, err
		}
		defer d.Close()
		entries := []os.DirEntry{}
		for budget > 0 {
			batch, e := d.ReadDir(min(256, budget))
			budget -= len(batch)
			entries = append(entries, batch...)
			if e == io.EOF {
				return entries, nil
			}
			if e != nil {
				return entries, e
			}
		}
		c.Truncated = true
		return entries, nil
	}
	out := []candidate{}
	for _, sub := range tool.bases {
		base := filepath.Join(root, sub)
		dirs, err := list(base)
		if err != nil {
			continue
		}
		for _, project := range dirs {
			if !project.IsDir() || project.Type()&os.ModeSymlink != 0 || strings.HasPrefix(project.Name(), "antigravity") {
				continue
			}
			entries, err := list(filepath.Join(base, project.Name(), "chats"))
			if err != nil {
				continue
			}
			for _, entry := range entries {
				name := entry.Name()
				if !tool.filename(name) {
					continue
				}
				c.FilesSeen++
				fi, err := entry.Info()
				if err != nil || !fi.Mode().IsRegular() || entry.Type()&os.ModeSymlink != 0 {
					c.FilesSkipped++
					continue
				}
				out = append(out, candidate{filepath.Join(base, project.Name(), "chats", name), fi.ModTime(), fi.Size()})
			}
		}
	}
	return out, nil
}

func safePath(path string, dir bool) error {
	if !filepath.IsAbs(path) {
		return errors.New("absolute path required")
	}
	cur := filepath.VolumeName(path) + string(filepath.Separator)
	for _, part := range strings.Split(strings.TrimPrefix(filepath.Clean(path), cur), string(filepath.Separator)) {
		cur = filepath.Join(cur, part)
		fi, err := os.Lstat(cur)
		if err != nil {
			return err
		}
		if fi.Mode()&os.ModeSymlink != 0 {
			return errors.New("symlink refused")
		}
	}
	fi, err := os.Lstat(path)
	if err != nil {
		return err
	}
	if dir && !fi.IsDir() {
		return errors.New("directory required")
	}
	if !dir && !fi.Mode().IsRegular() {
		return errors.New("regular file required")
	}
	return nil
}
func readRegular(path string, limit int64) ([]byte, error) {
	if err := safePath(path, false); err != nil {
		return nil, err
	}
	before, err := os.Lstat(path)
	if err != nil {
		return nil, err
	}
	if before.Size() > limit {
		return nil, errors.New("file too large")
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	after, err := f.Stat()
	if err != nil || !os.SameFile(before, after) || !after.Mode().IsRegular() {
		return nil, errors.New("file changed")
	}
	b, err := io.ReadAll(io.LimitReader(f, limit+1))
	if err != nil || int64(len(b)) > limit {
		return b, errors.New("file too large or unreadable")
	}
	return b, nil
}
