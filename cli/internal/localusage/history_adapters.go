package localusage

import (
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// HistoryCounts retain each emitter's native buckets; input/cache/reasoning may
// overlap. No total, bill, model, timestamp or quota is inferred from another field.
type HistoryCounts struct {
	Input      *int64 `json:"inputTokens,omitempty"`
	Output     *int64 `json:"outputTokens,omitempty"`
	CacheRead  *int64 `json:"cacheReadTokens,omitempty"`
	CacheWrite *int64 `json:"cacheWriteTokens,omitempty"`
	Reasoning  *int64 `json:"reasoningTokens,omitempty"`
	Total      *int64 `json:"totalTokens,omitempty"`
}
type historyDatum struct {
	ID, Model   string
	At          time.Time
	Counts      HistoryCounts
	Unallocated string
}

var errUnsupportedHistory = errors.New("unsupported history mapping")

type historyDecodeState struct {
	GrokScope string `json:"grokScope,omitempty"`
	Protocol  string `json:"protocol,omitempty"`
	StartDay  string `json:"startDay,omitempty"`
}

func historyCount(p *int64) *int64 {
	if p == nil || *p < 0 || *p > 1e15 {
		return nil
	}
	v := *p
	return &v
}
func (c HistoryCounts) valid() HistoryCounts {
	return HistoryCounts{historyCount(c.Input), historyCount(c.Output), historyCount(c.CacheRead), historyCount(c.CacheWrite), historyCount(c.Reasoning), historyCount(c.Total)}
}
func (c HistoryCounts) known() bool {
	return c.Input != nil || c.Output != nil || c.CacheRead != nil || c.CacheWrite != nil || c.Reasoning != nil || c.Total != nil
}
func (c *HistoryCounts) add(x HistoryCounts) {
	sum := func(a **int64, b *int64) {
		if *a == nil || b == nil || **a > 1<<62-*b {
			*a = nil
			return
		}
		n := **a + *b
		*a = &n
	}
	sum(&c.Input, x.Input)
	sum(&c.Output, x.Output)
	sum(&c.CacheRead, x.CacheRead)
	sum(&c.CacheWrite, x.CacheWrite)
	sum(&c.Reasoning, x.Reasoning)
	sum(&c.Total, x.Total)
}
func historyStamp(raw json.RawMessage) time.Time {
	var s string
	if json.Unmarshal(raw, &s) == nil {
		t, _ := time.Parse(time.RFC3339Nano, s)
		return t.UTC()
	}
	// Numeric timestamps are only decoded in adapters whose emitter specifies the unit.
	return time.Time{}
}
func historyModel(s string) string {
	if len(s) > 96 || strings.ContainsAny(s, "/@\\") {
		return ""
	}
	s = cleanModel(s)
	return s
}
func historyAllowed(tool, rel string) bool {
	p := strings.Split(filepath.ToSlash(rel), "/")
	name := p[len(p)-1]
	switch tool {
	case projectionTool:
		return len(p) == 3 && p[0] == "projects" && projectionSessionName(name)
	case "amp":
		return len(p) == 1 && strings.HasPrefix(name, "T-") && strings.HasSuffix(name, ".json")
	case "droid":
		return len(p) == 2 && strings.HasSuffix(name, ".settings.json")
	case "kimi":
		return len(p) == 3 && name == "wire.jsonl"
	case "copilot":
		return len(p) == 2 && name == "events.jsonl"
	case "grok":
		return (len(p) == 2 || len(p) == 3) && (name == "usage.json" || name == "summary.json")
	case "qwen":
		return ((len(p) == 4 && (p[0] == "projects" || p[0] == "tmp") && p[2] == "chats") || (len(p) == 3 && p[1] == "chats")) && (strings.HasSuffix(name, ".jsonl") || (strings.HasPrefix(name, "session-") && strings.HasSuffix(name, ".json")))
	case "gemini":
		return ((len(p) == 4 && p[0] == "tmp" && p[2] == "chats") || (len(p) == 3 && p[1] == "chats")) && strings.HasPrefix(name, "session-") && strings.HasSuffix(name, ".json")
	}
	return false
}

var historyDepths = map[string]int{"amp": 0, "droid": 1, "copilot": 1, "kimi": 2, "grok": 2, "qwen": 3, "gemini": 3}

func historyDepth(tool string) int {
	if tool == projectionTool {
		return 2
	}
	if depth, ok := historyDepths[tool]; ok {
		return depth
	}
	return -1
}

func historySession(tool, rel string) string {
	p := strings.Split(filepath.ToSlash(rel), "/")
	name := p[len(p)-1]
	if tool == "copilot" || tool == "kimi" || tool == "grok" {
		return p[len(p)-2]
	}
	return strings.TrimSuffix(strings.TrimSuffix(name, ".settings.json"), filepath.Ext(name))
}

func decodeHistory(tool string, b []byte, jsonl bool, state *historyDecodeState) ([]historyDatum, error) {
	switch tool {
	case "qwen", "gemini":
		var records []record
		var err error
		if tool == "qwen" {
			records, err = parseQwenRecords(b, jsonl)
		} else {
			records, err = parseRecords(b, jsonl)
		}
		if err != nil {
			return nil, err
		}
		var out []historyDatum
		for _, r := range records {
			messages := r.Messages
			if r.Set != nil {
				messages = append(messages, r.Set.Messages...)
			}
			if r.ID != "" {
				messages = append(messages, r.message)
			}
			for _, m := range messages {
				if (tool == "qwen" && m.Type != "assistant") || (tool == "gemini" && m.Type != "gemini") || m.ID == "" || m.Tokens == nil {
					continue
				}
				c := countsOf(m.Tokens)
				at, _ := time.Parse(time.RFC3339Nano, m.Timestamp)
				out = append(out, historyDatum{ID: m.ID, Model: historyModel(m.Model), At: at, Counts: HistoryCounts{Input: c.Input, Output: c.Output, CacheRead: c.Cached, Reasoning: c.Thoughts, Total: c.Total}})
			}
		}
		return out, nil
	case "amp":
		var r struct {
			Messages []struct {
				Role  string          `json:"role"`
				ID    json.RawMessage `json:"messageId"`
				Usage *struct {
					Model      string `json:"model"`
					At         string `json:"timestamp"`
					Input      *int64 `json:"inputTokens"`
					Output     *int64 `json:"outputTokens"`
					CacheRead  *int64 `json:"cacheReadInputTokens"`
					CacheWrite *int64 `json:"cacheCreationInputTokens"`
				} `json:"usage"`
			} `json:"messages"`
		}
		if json.Unmarshal(b, &r) != nil || len(r.Messages) > 50000 {
			return nil, fmt.Errorf("unsupported history")
		}
		var out []historyDatum
		for _, m := range r.Messages {
			if m.Role != "assistant" || m.Usage == nil || len(m.ID) == 0 {
				continue
			}
			u := m.Usage
			at, _ := time.Parse(time.RFC3339Nano, u.At)
			out = append(out, historyDatum{ID: string(m.ID), Model: historyModel(u.Model), At: at, Counts: HistoryCounts{Input: u.Input, Output: u.Output, CacheRead: u.CacheRead, CacheWrite: u.CacheWrite}})
		}
		return out, nil
	case "droid":
		// Factory settings provide cumulative own-session tokens. Current model and
		// file mtime cannot allocate them historically: retain them explicitly undated.
		var r struct {
			Usage *struct {
				Input    *int64 `json:"inputTokens"`
				Output   *int64 `json:"outputTokens"`
				Read     *int64 `json:"cacheReadTokens"`
				Write    *int64 `json:"cacheCreationTokens"`
				Thinking *int64 `json:"thinkingTokens"`
			} `json:"tokenUsage"`
		}
		if json.Unmarshal(b, &r) != nil {
			return nil, fmt.Errorf("unsupported history")
		}
		if r.Usage == nil {
			return nil, nil
		}
		u := r.Usage
		return []historyDatum{{ID: "own-session-total", Counts: HistoryCounts{Input: u.Input, Output: u.Output, CacheRead: u.Read, CacheWrite: u.Write, Reasoning: u.Thinking}, Unallocated: "historical_model_and_day_unavailable"}}, nil
	case "kimi":
		var header struct {
			Type     string `json:"type"`
			Protocol string `json:"protocol_version"`
		}
		if json.Unmarshal(b, &header) != nil {
			return nil, fmt.Errorf("malformed history")
		}
		if header.Type == "metadata" {
			switch header.Protocol {
			case "1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "1.7", "1.8", "1.9", "1.10":
				state.Protocol = header.Protocol
				return nil, nil
			default:
				return nil, errUnsupportedHistory
			}
		}
		var r struct {
			At      float64 `json:"timestamp"`
			Message struct {
				Type    string `json:"type"`
				Payload struct {
					ID    string `json:"message_id"`
					Usage *struct {
						Input  *int64 `json:"input_other"`
						Output *int64 `json:"output"`
						Read   *int64 `json:"input_cache_read"`
						Write  *int64 `json:"input_cache_creation"`
					} `json:"token_usage"`
				} `json:"payload"`
			} `json:"message"`
		}
		if json.Unmarshal(b, &r) != nil {
			return nil, fmt.Errorf("unsupported history")
		}
		if r.Message.Type != "StatusUpdate" || r.Message.Payload.Usage == nil {
			return nil, nil
		}
		p := r.Message.Payload
		u := p.Usage
		at := time.Time{}
		if r.At > 0 && r.At < 1e11 {
			at = time.UnixMilli(int64(r.At * 1000)).UTC()
		}
		// StatusUpdate has no model: do not splice session settings into old steps.
		return []historyDatum{{ID: p.ID, At: at, Counts: HistoryCounts{Input: u.Input, Output: u.Output, CacheRead: u.Read, CacheWrite: u.Write}}}, nil
	case "copilot":
		var r struct {
			Type string          `json:"type"`
			At   json.RawMessage `json:"timestamp"`
			Data struct {
				Models map[string]struct {
					Usage struct {
						Input     *int64 `json:"inputTokens"`
						Output    *int64 `json:"outputTokens"`
						Read      *int64 `json:"cacheReadTokens"`
						Write     *int64 `json:"cacheWriteTokens"`
						Reasoning *int64 `json:"reasoningTokens"`
					} `json:"usage"`
				} `json:"modelMetrics"`
			} `json:"data"`
		}
		if json.Unmarshal(b, &r) != nil {
			return nil, fmt.Errorf("unsupported history")
		}
		at := historyStamp(r.At)
		if r.Type == "session.start" {
			if !at.IsZero() {
				state.StartDay = at.Format("2006-01-02")
			}
			return nil, nil
		}
		// assistant.usage is ephemeral in the pinned first-party schema. Only durable
		// shutdown totals are admitted; cumulative checkpoints aren't added to them.
		if r.Type != "session.shutdown" {
			return nil, nil
		}
		if len(r.Data.Models) > 256 {
			return nil, fmt.Errorf("unsupported history")
		}
		var out []historyDatum
		for id, m := range r.Data.Models {
			d := historyDatum{ID: "shutdown/" + id, Model: historyModel(id), At: at, Counts: HistoryCounts{Input: m.Usage.Input, Output: m.Usage.Output, CacheRead: m.Usage.Read, CacheWrite: m.Usage.Write, Reasoning: m.Usage.Reasoning}}
			if at.IsZero() || state.StartDay == "" || state.StartDay != at.Format("2006-01-02") {
				d.At = time.Time{}
				d.Unallocated = "session_spans_unknown_or_multiple_days"
			}
			out = append(out, d)
		}
		return out, nil
	case "grok":
		var summary struct {
			Info     json.RawMessage `json:"info"`
			Created  time.Time       `json:"created_at"`
			Messages *int            `json:"num_messages"`
			Parent   string          `json:"parent_session_id"`
			Kind     string          `json:"session_kind"`
			Forked   json.RawMessage `json:"forked_at"`
			Hidden   bool            `json:"hidden"`
		}
		if json.Unmarshal(b, &summary) != nil {
			return nil, fmt.Errorf("unsupported history")
		}
		if len(summary.Info) > 0 && !summary.Created.IsZero() && summary.Messages != nil {
			state.GrokScope = "root"
			if summary.Parent != "" || summary.Hidden || strings.HasPrefix(summary.Kind, "subagent") || strings.Contains(summary.Kind, "fork") || (len(summary.Forked) > 0 && string(summary.Forked) != "null") {
				state.GrokScope = "excluded"
			}
			return nil, nil
		}
		type usage struct {
			Input      *int64 `json:"inputTokens"`
			Output     *int64 `json:"outputTokens"`
			Read       *int64 `json:"cachedReadTokens"`
			Write      *int64 `json:"cacheCreationTokens"`
			Reasoning  *int64 `json:"reasoningTokens"`
			Total      *int64 `json:"totalTokens"`
			Incomplete bool   `json:"usageIsIncomplete"`
		}
		var r struct {
			Turns []struct {
				Number int              `json:"turnNumber"`
				At     string           `json:"endedAt"`
				Models map[string]usage `json:"modelUsage"`
			} `json:"turns"`
		}
		if json.Unmarshal(b, &r) != nil || len(r.Turns) > 20000 {
			return nil, fmt.Errorf("unsupported history")
		}
		var out []historyDatum
		for _, turn := range r.Turns {
			if len(turn.Models) > 256 {
				return nil, fmt.Errorf("unsupported history")
			}
			at, _ := time.Parse(time.RFC3339Nano, turn.At)
			for id, u := range turn.Models {
				d := historyDatum{ID: strconv.Itoa(turn.Number) + "/" + id, Model: historyModel(id), At: at, Counts: HistoryCounts{Input: u.Input, Output: u.Output, CacheRead: u.Read, CacheWrite: u.Write, Reasoning: u.Reasoning, Total: u.Total}}
				if u.Incomplete {
					d.Unallocated = "provider_reports_incomplete_usage"
				}
				out = append(out, d)
			}
		}
		return out, nil
	}
	return nil, fmt.Errorf("unsupported history")
}

// Projection discovery visits only projects/<encoded-project>, never other
// Claude stores. Existing count-reader path rules retain their own bounds.
func historyDescend(tool, rel string, depth int) bool {
	if tool == projectionTool && depth == 0 {
		return rel == "projects"
	}
	return depth < historyDepth(tool)
}
