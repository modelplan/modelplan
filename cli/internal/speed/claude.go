package speed

import (
	"bytes"
	"encoding/json"
	"time"
)

// A Claude Code transcript line, reduced to what timing needs: the line's kind and time, and for a
// reply its request id, model, effort, speed mode, output tokens and thinking time. Content is
// decoded only as far as each block's type, to tell a prompt from a tool result.
type ccLine struct {
	Type        string   `json:"type"`
	Timestamp   string   `json:"timestamp"`
	IsSidechain bool     `json:"isSidechain"`
	IsMeta      bool     `json:"isMeta"`
	IsCompact   bool     `json:"isCompactSummary"`
	RequestID   string   `json:"requestId"`
	Cwd         string   `json:"cwd"`
	Effort      string   `json:"effort"`
	ThinkingMs  *float64 `json:"thinkingDurationMs"`
	Message     struct {
		Model      string          `json:"model"`
		StopReason string          `json:"stop_reason"`
		Content    json.RawMessage `json:"content"`
		Usage      *struct {
			Output     int64  `json:"output_tokens"`
			Input      *int64 `json:"input_tokens"`
			CacheRead  *int64 `json:"cache_read_input_tokens"`
			CacheWrite *int64 `json:"cache_creation_input_tokens"`
			Speed      string `json:"speed"`
		} `json:"usage"`
	} `json:"message"`
}

// A request is the replies sharing one request id. It starts when the prompt or tool result it
// answers was written; its first token arrives when its thinking started (the thinking block's
// time minus its duration), unknown without thinking; it ends with its last block.
type ccRequest struct {
	TokenKinds
	id                string
	cfg               config
	start, first, end time.Time
	out               int64
}

type ccTurn struct {
	off      int64
	at, last time.Time
	ended    bool // the last reply ended the turn (end_turn)
	reqs     []ccRequest
	trigger  time.Time // when the prompt or latest tool result was written
	cwd      string
}

type claudeParser struct {
	now        time.Time
	cur        *ccTurn
	done       []turn
	sidechains bool
	probe      liveProbe
	// The importer's cross-file dedupe: request ids already counted from earlier files of the run
	// (a resumed session copies its messages into a new file), and the ones this file has.
	prior, mine map[string]bool
	// The observer's cross-file dedupe: keyed request ids other transcripts counted (requestKey),
	// and the ones this read counted, in finished turns, to record.
	elsewhere map[string]bool
	counted   []string
	// cleared: the tool's clear boundary. A turn from before it is never counted, so none of its
	// request ids is recorded either.
	cleared time.Time
	// The transcript's own title entries (D470 3): a user-set one wins over the generated one.
	customTitle, aiTitle string
}

// idleDone: a turn whose last reply ended it and nothing followed for this long is finished, even
// before the next prompt.
// A turn that never ended (interrupted) is dropped once idle for idleDrop.
const (
	idleDone = 30 * time.Second
	idleDrop = time.Hour
)

func newClaude(now time.Time) *claudeParser { return &claudeParser{now: now} }

var (
	ccUser      = []byte(`"type":"user"`)
	ccAssistant = []byte(`"type":"assistant"`)
)

func (p *claudeParser) line(off, end int64, b []byte) {
	p.noteTitle(b)
	p.lineDoc(off, end, b, nil)
}

var (
	ccCustomTitle = []byte(`"type":"custom-title"`)
	ccAITitle     = []byte(`"type":"ai-title"`)
)

// noteTitle reads a title entry: {"type":"custom-title","customTitle":…} or {"type":"ai-title","aiTitle":…}.
func (p *claudeParser) noteTitle(b []byte) {
	custom := bytes.Contains(b, ccCustomTitle)
	if !custom && !bytes.Contains(b, ccAITitle) || len(b) > 16<<10 {
		return
	}
	var e struct {
		Custom string `json:"customTitle"`
		AI     string `json:"aiTitle"`
	}
	if json.Unmarshal(b, &e) != nil {
		return
	}
	if t := cleanTitle(e.Custom); custom && t != "" {
		p.customTitle = t
	} else if t := cleanTitle(e.AI); !custom && t != "" {
		p.aiTitle = t
	}
}

func (p *claudeParser) title() string {
	if p.customTitle != "" {
		return p.customTitle
	}
	return p.aiTitle
}

// lineDoc is line with the line's reduced form (claudeDoc) already made, or nil to make it here.
func (p *claudeParser) lineDoc(off, end int64, b, doc []byte) {
	if !bytes.Contains(b, ccUser) && !bytes.Contains(b, ccAssistant) {
		return
	}
	if doc == nil {
		if doc = claudeDoc(b); doc == nil {
			return
		}
	}
	var l ccLine
	if json.Unmarshal(doc, &l) != nil || (l.IsSidechain && !p.sidechains) {
		return
	}
	ts, err := time.Parse(time.RFC3339Nano, l.Timestamp)
	if err != nil {
		return
	}
	switch l.Type {
	case "user":
		if l.IsMeta || l.IsCompact {
			return
		}
		if toolResult(l.Message.Content) {
			if p.cur != nil {
				p.cur.trigger = ts
			}
			return
		}
		p.close()
		p.cur = &ccTurn{off: off, at: ts, trigger: ts, cwd: l.Cwd}
	case "assistant":
		t := p.cur
		u := l.Message.Usage
		if t == nil || u == nil || l.Message.Model == "" || l.Message.Model == "<synthetic>" {
			return
		}
		if id := l.RequestID; id != "" && p.prior != nil {
			if p.prior[id] && !p.mine[id] {
				return // already counted from another file
			}
			p.mine[id] = true
		}
		if id := l.RequestID; id != "" && p.elsewhere != nil && p.elsewhere[requestKey(id)] {
			return // already counted from another transcript
		}
		n := len(t.reqs)
		if n == 0 || t.reqs[n-1].id != l.RequestID || l.RequestID == "" {
			t.reqs = append(t.reqs, ccRequest{id: l.RequestID, start: t.trigger, cfg: config{l.Message.Model, l.Effort, speedMode(u.Speed)}})
			n++
		}
		q := &t.reqs[n-1]
		if ts.After(q.end) {
			q.end = ts
		}
		q.TokenKinds.enrich(TokenKinds{InputTokens: u.Input, CacheReadTokens: u.CacheRead, CacheWriteTokens: u.CacheWrite})
		if u.Output > q.out {
			q.out = u.Output
		}
		if l.ThinkingMs != nil && *l.ThinkingMs > 0 && blockIs(l.Message.Content, "thinking") {
			first := ts.Add(-time.Duration(*l.ThinkingMs * float64(time.Millisecond)))
			if q.first.IsZero() || first.Before(q.first) {
				q.first = first
			}
		}
		t.last, t.ended = ts, l.Message.StopReason == "end_turn"
		if t.cwd == "" {
			t.cwd = l.Cwd
		}
	}
}

func (p *claudeParser) close() {
	t := p.cur
	p.cur = nil
	if t == nil || len(t.reqs) == 0 {
		return
	}
	if p.elsewhere != nil && !t.at.Before(p.cleared) {
		for _, q := range t.reqs {
			if q.id != "" {
				p.counted = append(p.counted, requestKey(q.id))
			}
		}
	}
	p.done = append(p.done, ccAsTurn(t))
}

func ccAsTurn(t *ccTurn) turn {
	if len(t.reqs) == 0 {
		return turn{at: t.at, cwd: t.cwd}
	}
	out := turn{cfg: t.reqs[len(t.reqs)-1].cfg, at: t.at, dur: t.last.Sub(t.at), cwd: t.cwd}
	for _, q := range t.reqs {
		r := request{TokenKinds: q.TokenKinds, out: q.out, cfg: q.cfg, end: q.end}
		if !q.first.IsZero() && q.end.After(q.first) {
			r.gen = q.end.Sub(q.first)
			if !q.start.IsZero() && !q.first.Before(q.start) {
				r.ttft = q.first.Sub(q.start)
			}
		}
		out.out += q.out
		out.all = append(out.all, r)
		if q.cfg == out.cfg {
			out.reqs = append(out.reqs, r)
		} else {
			out.mixed = true
		}
	}
	return out
}

func (p *claudeParser) finish() ([]turn, int64) {
	defer func() {
		if t := p.title(); t != "" {
			for i := range p.done {
				p.done[i].np.Title = t
			}
		}
	}()
	p.probe = p.liveProbe()
	if t := p.cur; t != nil {
		if !t.ended && p.now.Sub(later(t.last, t.at)) > idleDrop {
			p.cur = nil // interrupted long ago: its time says nothing
			return p.done, -1
		}
		if !t.ended || p.now.Sub(t.last) < idleDone {
			off := t.off
			p.cur = nil
			return p.done, off // read the unfinished turn again next time
		}
		p.close()
	}
	return p.done, -1
}

// toolResult: a user line carrying tool results, not a prompt.
func toolResult(c json.RawMessage) bool { return blockIs(c, "tool_result") }

func blockIs(c json.RawMessage, kind string) bool {
	if len(c) == 0 || c[0] != '[' {
		return false
	}
	var bs []struct {
		Type string `json:"type"`
	}
	if json.Unmarshal(c, &bs) != nil {
		return false
	}
	for _, b := range bs {
		if b.Type == kind {
			return true
		}
	}
	return false
}

// speedMode: "" for the standard mode, else the harness's name for it.
func speedMode(s string) string {
	switch s {
	case "", "standard", "default", "auto":
		return ""
	}
	if len(s) > 24 {
		return ""
	}
	return s
}

func later(a, b time.Time) time.Time {
	if a.After(b) {
		return a
	}
	return b
}
