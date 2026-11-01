// SPDX-License-Identifier: MIT
package speed

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/url"
	"os"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"
)

// TurnActivity is independent of token/rate eligibility. RecordAt is the original
// event time; only the explicitly marked fallback uses the file's write time.
type TurnActivity struct {
	Phase     string    `json:"phase"`
	RecordAt  time.Time `json:"recordAt"`
	ExpiresAt time.Time `json:"expiresAt"`
}

// ActivityBinding is an existing per-session ledger association, never a source
// default. Key is private correlation material and is not emitted on the wire.
type ActivityBinding struct {
	Source, Key, SubscriptionRef string
	Verified                     bool
}
type SessionActivity struct {
	TurnActivity
	Source, SessionKey, SessionRef, SubscriptionRef string
}
type activityCache struct {
	modified time.Time
	size     int64
	verdicts []SessionActivity
}
type ActivityObserver struct {
	mu    sync.Mutex
	cache map[string]activityCache
	refs  map[string]string
}

func NewActivityObserver() *ActivityObserver {
	return &ActivityObserver{cache: map[string]activityCache{}, refs: map[string]string{}}
}

// Observe never overlaps a previous scan. Its cache retains verdicts, not tails,
// content, configuration, turn IDs or credentials. Expiry is recomputed on hits.
func (o *ActivityObserver) Observe(ctx context.Context, logs []LiveLog, bindings []ActivityBinding, now time.Time) []SessionActivity {
	if !o.mu.TryLock() {
		return nil
	}
	defer o.mu.Unlock()
	owned := map[string]string{}
	ambiguous := map[string]bool{}
	for _, b := range bindings {
		if !b.Verified || b.SubscriptionRef == "" {
			continue
		}
		key := b.Source + "\x00" + b.Key
		if old := owned[key]; old != "" && old != b.SubscriptionRef {
			ambiguous[key] = true
		}
		owned[key] = b.SubscriptionRef
	}
	seen := map[string]bool{}
	out := []SessionActivity{}
	for i, log := range logs {
		if i >= maxLive || ctx.Err() != nil {
			break
		}
		fi, err := os.Lstat(log.Path)
		if err != nil || !fi.Mode().IsRegular() || fi.ModTime().Before(now.Add(-LiveWithin)) || fi.ModTime().After(now) {
			continue
		}
		seen[log.Path] = true
		cached, ok := o.cache[log.Path]
		if !ok || !cached.modified.Equal(fi.ModTime()) || cached.size != fi.Size() {
			verdicts, err := readActivityTail(log, fi, now)
			if err != nil {
				delete(o.cache, log.Path)
				continue
			}
			cached = activityCache{fi.ModTime(), fi.Size(), verdicts}
			o.cache[log.Path] = cached
		}
		for _, v := range cached.verdicts {
			key := v.Source + "\x00" + v.SessionKey
			if o.refs[key] == "" {
				if len(o.refs) >= maxSessions {
					continue
				}
				o.refs[key] = newRef()
			}
			v.SessionRef = o.refs[key]
			if !ambiguous[key] {
				v.SubscriptionRef = owned[key]
			}
			if !now.Before(v.ExpiresAt) {
				v.Phase = "finished"
			}
			out = append(out, v)
		}
	}
	for path := range o.cache {
		if !seen[path] {
			delete(o.cache, path)
		}
	}
	active := map[string]bool{}
	for _, v := range out {
		active[v.Source+"\x00"+v.SessionKey] = true
	}
	for key := range o.refs {
		if !active[key] {
			delete(o.refs, key)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Source+out[i].SessionKey < out[j].Source+out[j].SessionKey })
	return out
}

// Only this exceptional boolean inspects content. It neither decodes nor retains
// arbitrary text. Other JSON content/arguments/output fields are skipped by the
// typed decoder. JSON-escaped interrupt prefixes are accepted too.
type interrupted bool

func (v *interrupted) UnmarshalJSON(b []byte) error {
	const marker = "[Request interrupted by user"
	var prefix strings.Builder
	if len(b) > 0 && b[0] == '"' {
		// Decode only enough JSON string units to compare the fixed marker.
		for i := 1; i < len(b) && prefix.Len() < len(marker); {
			if b[i] == '"' {
				break
			}
			if b[i] != '\\' {
				prefix.WriteByte(b[i])
				i++
				continue
			}
			n := 2
			if i+1 < len(b) && b[i+1] == 'u' {
				n = 6
			}
			if i+n > len(b) {
				break
			}
			var unit string
			if json.Unmarshal(append(append([]byte{'"'}, b[i:i+n]...), '"'), &unit) != nil {
				break
			}
			prefix.WriteString(unit)
			i += n
		}
		*v = interrupted(strings.HasPrefix(prefix.String(), marker))
	} else if len(b) > 0 && b[0] == '[' {
		var blocks []struct {
			Text interrupted `json:"text"`
		}
		if json.Unmarshal(b, &blocks) == nil {
			for _, block := range blocks {
				if block.Text {
					*v = true
				}
			}
		}
	}
	return nil
}

type activityLine struct {
	Interrupted bool `json:"-"`
	Type      string `json:"type"`
	Timestamp string `json:"timestamp"`
	Event     string `json:"event"`
	Session   string `json:"sessionId"`
	Turn      string `json:"turnId"`
	Context   struct {
		Session string `json:"sessionId"`
		Turn    string `json:"turnId"`
	} `json:"context"`
	Message struct {
		Stop *string `json:"stop_reason"`
	} `json:"message"`
	Payload struct {
		Type string `json:"type"`
	} `json:"payload"`
}

func activityPhase(l activityLine, source string) string {
	switch source {
	case "claude-code":
		if l.Type == "user" {
			if l.Interrupted {
				return "finished"
			}
			return "model"
		}
		if l.Type == "assistant" {
			if l.Message.Stop == nil {
				return "model"
			}
			if *l.Message.Stop == "tool_use" {
				return "tool"
			}
			return "finished"
		}
	case "codex":
		switch l.Payload.Type {
		case "task_complete", "turn_aborted":
			return "finished"
		case "task_started":
			return "model"
		case "function_call", "custom_tool_call", "local_shell_call", "web_search_call":
			return "tool"
		}
		if strings.HasSuffix(l.Payload.Type, "_call_output") {
			return "model"
		}
	case "zcode":
		switch l.Event {
		case "turn.started", "model.started", "model.request.started":
			return "model"
		case "tool.call.started":
			return "tool"
		case "tool.call.completed", "tool.call.failed":
			return "model"
		case "turn.completed", "turn.failed", "turn.aborted", "turn.cancelled":
			return "finished"
		}
	}
	return ""
}
func turnActivity(phase string, at time.Time) TurnActivity {
	grace := 90 * time.Second
	if phase == "tool" {
		grace = LiveWithin
	}
	if phase == "fallback" {
		grace = 30 * time.Second
	}
	if phase == "finished" {
		grace = LiveWithin
	}
	return TurnActivity{phase, at, at.Add(grace)}
}
func readActivityTail(log LiveLog, fi os.FileInfo, now time.Time) ([]SessionActivity, error) {
	f, err := os.Open(log.Path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	opened, err := f.Stat()
	if err != nil || !os.SameFile(fi, opened) {
		return nil, os.ErrInvalid
	}
	offset := max(int64(0), fi.Size()-liveTail)
	if _, err = f.Seek(offset, io.SeekStart); err != nil {
		return nil, err
	}
	b, err := io.ReadAll(io.LimitReader(f, liveTail))
	if err != nil {
		return nil, err
	}
	defer clear(b)
	after, err := f.Stat()
	if err != nil || after.Size() != fi.Size() || !after.ModTime().Equal(fi.ModTime()) {
		return nil, os.ErrInvalid
	}
	if offset > 0 {
		if n := bytes.IndexByte(b, '\n'); n >= 0 {
			b = b[n+1:]
		} else {
			return nil, nil
		}
	}
	lines := bytes.Split(b, []byte{'\n'})
	seen := map[string]bool{}
	sessions := map[string]SessionActivity{}
	recognized := false
	for i := len(lines) - 1; i >= 0; i-- {
		var l activityLine
		if json.Unmarshal(lines[i], &l) != nil {
			continue
		}
		if log.Source == "claude-code" && l.Type == "user" {
			var user struct {
				Message struct {
					Content interrupted `json:"content"`
				} `json:"message"`
			}
			if json.Unmarshal(lines[i], &user) != nil {
				continue
			}
			l.Interrupted = bool(user.Message.Content)
		}
		if l.Session == "" {
			l.Session = l.Context.Session
		}
		if l.Turn == "" {
			l.Turn = l.Context.Turn
		}
		phase := activityPhase(l, log.Source)
		if phase == "" {
			continue
		}
		recognized = true
		at, err := time.Parse(time.RFC3339Nano, l.Timestamp)
		if err != nil || at.After(now) {
			if log.Source != "zcode" {
				break
			}
			continue
		}
		key := fileKey(log.Path)
		if log.Source == "zcode" {
			if l.Session == "" || l.Turn == "" {
				continue
			}
			turn := l.Session + "\x00" + l.Turn
			if seen[turn] {
				continue
			}
			seen[turn] = true
			// Match the existing DB ledger's session correlation, not the shared log file.
			key = fileKey("zcode:" + l.Session)
		}
		v := SessionActivity{TurnActivity: turnActivity(phase, at), Source: log.Source, SessionKey: key}
		if !now.Before(v.ExpiresAt) {
			v.Phase = "finished"
		}
		old, exists := sessions[key]
		if !exists || old.Phase == "finished" && v.Phase != "finished" {
			sessions[key] = v
		}
		if log.Source != "zcode" {
			break
		}
		if len(seen) >= maxSessions {
			break
		}
	}
	if !recognized {
		key := fileKey(log.Path)
		sessions[key] = SessionActivity{TurnActivity: turnActivity("fallback", fi.ModTime()), Source: log.Source, SessionKey: key}
	}
	out := []SessionActivity{}
	for _, v := range sessions {
		out = append(out, v)
	}
	return out, nil
}

var baseURLField = regexp.MustCompile(`"(?:baseURL|base_url)"\s*:\s*"([^"\\]*)"`)

// ZCodeActivityHost extracts base-URL values only; keys, headers and other
// configuration values are never deserialized, retained, logged or exported.
func ZCodeActivityHost(path string) bool {
	fi, err := os.Lstat(path)
	if err != nil || !fi.Mode().IsRegular() || fi.Size() > 256<<10 {
		return false
	}
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	b, err := io.ReadAll(io.LimitReader(f, 256<<10))
	if err != nil {
		return false
	}
	defer clear(b)
	if !json.Valid(b) {
		return false
	}
	matches := baseURLField.FindAllSubmatch(b, -1)
	if len(matches) == 0 {
		return false
	}
	for _, m := range matches {
		u, err := url.Parse(string(m[1]))
		if err != nil || u.Scheme != "https" || u.User != nil {
			return false
		}
		host := strings.ToLower(u.Hostname())
		if host != "z.ai" && !strings.HasSuffix(host, ".z.ai") && host != "bigmodel.cn" && !strings.HasSuffix(host, ".bigmodel.cn") {
			return false
		}
	}
	return true
}

// ExistingActivityBindings deliberately excludes Live's historical source-level
// fallback. Only the per-session observation ledger supplies provenance.
func ExistingActivityBindings(cache string) []ActivityBinding {
	l, ok := LoadPerf(cache)
	if !ok {
		return nil
	}
	out := []ActivityBinding{}
	for _, s := range l.Sessions {
		if s.SubscriptionRef != "" {
			out = append(out, ActivityBinding{s.Source, s.Key, s.SubscriptionRef, true})
		}
	}
	return out
}
