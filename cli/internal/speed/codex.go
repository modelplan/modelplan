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
	start time.Time // the current request's
	first int64     // its first token, unix ms; 0 unknown
	used  bool      // its usage was counted
}

type codexParser struct {
	cur  *cxTurn
	done []turn
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
	t := p.cur
	switch {
	case event == "task_started" || event == "turn_started":
		p.cur = &cxTurn{off: off, at: ts, start: ts}
	case t == nil:
		return
	case kind == "turn_context":
		var c struct {
			Payload struct {
				Model       string `json:"model"`
				Effort      string `json:"effort"`
				ServiceTier string `json:"service_tier"`
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
					Last *struct {
						Output int64 `json:"output_tokens"`
					} `json:"last_token_usage"`
				} `json:"info"`
				Usage *struct {
					Output int64 `json:"output_tokens"`
				} `json:"usage"`
			} `json:"payload"`
		}
		if t.used || json.Unmarshal(b, &c) != nil {
			return
		}
		var out int64 = -1
		if c.Payload.Info != nil && c.Payload.Info.Last != nil {
			out = c.Payload.Info.Last.Output
		} else if c.Payload.Usage != nil {
			out = c.Payload.Usage.Output
		}
		if out < 0 {
			return // a rate-limit notice without usage
		}
		r := request{out: out}
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
		if json.Unmarshal(b, &c) != nil || (c.Payload.Error != nil && string(*c.Payload.Error) != "null") || t.skip {
			return
		}
		dur := ts.Sub(t.at)
		if c.Payload.DurationMs != nil && *c.Payload.DurationMs > 0 {
			dur = time.Duration(*c.Payload.DurationMs) * time.Millisecond
		}
		p.done = append(p.done, turn{cfg: t.cfg, at: t.at, dur: dur, out: t.out, reqs: t.reqs})
	case event == "turn_aborted":
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
