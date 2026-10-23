package speed

import (
	"encoding/json"
	"regexp"
	"time"
)

// Codex rollout lines start with their time, kind and (for events and items) payload type; only
// the lines timing needs are decoded further.
var cxHeader = regexp.MustCompile(`^\{"timestamp":"([^"]+)"(?:,"ordinal":\d+)?,"type":"(\w+)","payload":\{(?:"type":"(\w+)")?`)

// A turn runs from task_started to task_complete (which carries its duration), under the model,
// effort and service tier of its turn_context. Each request starts at the turn's start, a user
// message or a tool output; its first token is the earliest reasoning or reply item that started
// after that; it ends with its token usage, the first usage record after the request started (Codex
// writes a usage record and a token_count notice for the same response).
type cxTurn struct {
	off   int64
	at    time.Time
	cfg   config
	reqs  []request
	out   int64
	skip  bool
	cwd   string
	start time.Time // the current request's
	first int64     // its first token, unix ms; 0 unknown
	used  bool      // its usage was counted
}

type codexParser struct {
	cur        *cxTurn
	cwd        string // the session's, from its session_meta
	done       []turn
	liveOnly   bool
	total      *cxUsage
	checkpoint *cxUsage
	terminal   []sessionSignal
	last       time.Time
}

func newCodex() *codexParser { return &codexParser{} }

func (p *codexParser) line(off, _ int64, b []byte) {
	head := b
	if len(head) > 512 {
		head = head[:512]
	}
	m := cxHeader.FindSubmatch(head)
	if m == nil {
		return
	}
	ts, err := time.Parse(time.RFC3339Nano, string(m[1]))
	if err != nil {
		return
	}
	kind, event := string(m[2]), string(m[3])
	if ts.After(p.last) {
		p.last = ts
	}
	t := p.cur
	switch {
	case event == "task_started" || event == "turn_started":
		p.checkpoint = p.total
		p.cur = &cxTurn{off: off, at: ts, start: ts, cwd: p.cwd}
	case kind == "session_meta":
		var c struct {
			Payload struct {
				Cwd string `json:"cwd"`
			} `json:"payload"`
		}
		if json.Unmarshal(b, &c) == nil {
			p.cwd = c.Payload.Cwd
		}
	case t == nil:
		return
	case kind == "turn_context":
		var c struct {
			Payload struct {
				Model       string `json:"model"`
				Effort      string `json:"effort"`
				ServiceTier string `json:"service_tier"`
				Cwd         string `json:"cwd"`
				Mode        struct {
					Settings struct {
						Effort string `json:"reasoning_effort"`
					} `json:"settings"`
				} `json:"collaboration_mode"`
			} `json:"payload"`
		}
		if json.Unmarshal(b, &c) == nil {
			e := c.Payload.Effort
			if e == "" {
				e = c.Payload.Mode.Settings.Effort
			}
			t.cfg = config{clip(c.Payload.Model), clip(e), speedMode(clip(c.Payload.ServiceTier))}
			t.skip = c.Payload.Model == "codex-auto-review"
			if c.Payload.Cwd != "" {
				t.cwd = c.Payload.Cwd
			}
		}
	case event == "user_message" || event == "function_call_output" || event == "custom_tool_call_output":
		t.start, t.first, t.used = ts, 0, false
	case event == "item_completed":
		var c struct {
			Payload struct {
				Item struct {
					Type string `json:"type"`
				} `json:"item"`
				StartedAtMs int64 `json:"started_at_ms"`
			} `json:"payload"`
		}
		if json.Unmarshal(b, &c) != nil || (c.Payload.Item.Type != "Reasoning" && c.Payload.Item.Type != "AgentMessage") {
			return
		}
		if s := c.Payload.StartedAtMs; s > 0 && s >= t.start.UnixMilli() && (t.first == 0 || s < t.first) && !t.used {
			t.first = s
		}
	case event == "token_count" || kind == "token_usage_record":
		var c struct {
			Payload struct {
				Info *struct {
					Last  *cxUsage `json:"last_token_usage"`
					Total *cxUsage `json:"total_token_usage"`
				} `json:"info"`
				Usage *cxUsage `json:"usage"`
			} `json:"payload"`
		}
		if json.Unmarshal(b, &c) != nil {
			return
		}
		u := c.Payload.Usage
		if c.Payload.Info != nil {
			if c.Payload.Info.Last != nil {
				u = c.Payload.Info.Last
			} else if c.Payload.Info.Total != nil && p.total != nil {
				u = usageDelta(c.Payload.Info.Total, p.total)
			}
			if c.Payload.Info.Total != nil {
				p.total = c.Payload.Info.Total
			}
		}
		if u == nil || u.Output == nil || *u.Output < 0 {
			return
		}
		if t.used {
			// A token_count can enrich the usage record of the same response without another count.
			if n := len(t.reqs); n > 0 && t.reqs[n-1].out == *u.Output {
				q := &t.reqs[n-1]
				if q.input == nil {
					q.input = uncachedInput(u.Input, u.Cached)
				}
				if q.cacheRead == nil {
					q.cacheRead = validToken(u.Cached)
				}
				if q.cacheWrite == nil {
					q.cacheWrite = validToken(u.CacheWrite)
				}
			}
			return
		}
		out := *u.Output
		// Codex input_tokens includes cached_input_tokens; publish uncached input apart.
		input := uncachedInput(u.Input, u.Cached)
		r := request{out: out, end: ts, key: itoa64(off), input: input, cacheRead: validToken(u.Cached), cacheWrite: validToken(u.CacheWrite)}

		if t.first > 0 {
			first := time.UnixMilli(t.first)
			if ts.After(first) {
				r.gen = ts.Sub(first)
			}
			if !first.Before(t.start) {
				r.ttft = first.Sub(t.start)
			}
		}
		t.reqs = append(t.reqs, r)
		t.out += out
		t.used = true
	case event == "task_complete" || event == "turn_complete":
		var c struct {
			Payload struct {
				DurationMs *int64           `json:"duration_ms"`
				Error      *json.RawMessage `json:"error"`
			} `json:"payload"`
		}
		p.cur = nil
		p.terminal = append(p.terminal, codexSignal(t, ts, false))
		if json.Unmarshal(b, &c) != nil || (c.Payload.Error != nil && string(*c.Payload.Error) != "null") || t.skip {
			return
		}
		dur := ts.Sub(t.at)
		if c.Payload.DurationMs != nil && *c.Payload.DurationMs > 0 {
			dur = time.Duration(*c.Payload.DurationMs) * time.Millisecond
		}
		all := make([]request, len(t.reqs))
		for i, r := range t.reqs {
			r.cfg = t.cfg
			all[i] = r
		}
		p.done = append(p.done, turn{cfg: t.cfg, at: t.at, dur: dur, out: t.out, reqs: t.reqs, all: all, cwd: t.cwd})
	case event == "turn_aborted":
		p.terminal = append(p.terminal, codexSignal(t, ts, false))
		p.cur = nil
	}
}

func (p *codexParser) finish() ([]turn, int64) {
	if p.cur != nil {
		return p.done, p.cur.off // read the unfinished turn again next time
	}
	return p.done, -1
}

func clip(s string) string {
	if len(s) > 96 {
		return ""
	}
	return s
}

// These names mirror token_count's synthetic rollout fixtures. Missing counts stay unknown.
type cxUsage struct {
	Input      *int64 `json:"input_tokens"`
	Cached     *int64 `json:"cached_input_tokens"`
	CacheWrite *int64 `json:"cache_write_input_tokens"`
	Output     *int64 `json:"output_tokens"`
}

func usageDelta(a, b *cxUsage) *cxUsage {
	return &cxUsage{Input: tokenDelta(a.Input, b.Input), Cached: tokenDelta(a.Cached, b.Cached), CacheWrite: tokenDelta(a.CacheWrite, b.CacheWrite), Output: tokenDelta(a.Output, b.Output)}
}
func (p *codexParser) signals() []sessionSignal {
	out := append([]sessionSignal{}, p.terminal...)
	if t := p.cur; t != nil {
		x := codexSignal(t, p.last, true)
		out = append(out, x)
	}
	return out
}

func codexSignal(t *cxTurn, last time.Time, running bool) sessionSignal {
	x := sessionSignal{start: t.at, last: last, running: running, cfg: t.cfg, cwd: t.cwd}
	for _, q := range t.reqs {
		q.cfg = t.cfg
		x.reqs = append(x.reqs, q)
	}
	return x
}
