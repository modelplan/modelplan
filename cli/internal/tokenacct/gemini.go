// SPDX-License-Identifier: MIT
// Ported from ccusage (github.com/ccusage/ccusage, MIT, Copyright (c) 2025
// ryoppippi; LICENSES/ccusage-MIT.txt) at
// 58866ba681343634ab6e5add61f18f3b70aa98f7: rust/adapters/gemini/src/parser.rs
// (parse_json_file, parse_jsonl_file, build_event, parse_tokens,
// normalize_session_input, subtract_cached_overlap_tokens, event_to_loaded).
// Modified for Go: only token, model, id, type and time fields are decoded;
// message text and tool payloads are skipped by the decoder and never kept.

package tokenacct

import (
	"encoding/json"
	"time"
)

type geminiRecord struct {
	Type      json.RawMessage `json:"type"`
	Model     json.RawMessage `json:"model"`
	ID        json.RawMessage `json:"id"`
	Timestamp json.RawMessage `json:"timestamp"`
	CreatedAt json.RawMessage `json:"created_at"`
	StartTime json.RawMessage `json:"startTime"`
	Updated   json.RawMessage `json:"lastUpdated"`
	Messages  json.RawMessage `json:"messages"`
	Tokens    json.RawMessage `json:"tokens"`
	Stats     json.RawMessage `json:"stats"`
	Result    json.RawMessage `json:"result"`
}

func (r geminiRecord) stats() json.RawMessage {
	if present(r.Stats) {
		return r.Stats
	}
	var result map[string]json.RawMessage
	if present(r.Result) && json.Unmarshal(r.Result, &result) == nil && present(result["stats"]) {
		return result["stats"]
	}
	return nil
}

func (r geminiRecord) isGemini() bool {
	s, ok := str(r.Type)
	return ok && s == "gemini"
}

func tsOr(raw json.RawMessage, fallback time.Time) (time.Time, bool) {
	if s, ok := str(raw); ok {
		if t, ok := parseTS(s); ok {
			return t, true
		}
	}
	return fallback, false
}

type geminiTokens struct {
	input, output, cached, thoughts, tool int64
	total                                 int64
	hasTotal                              bool
}

// parseGeminiTokens accepts ccusage's key aliases; a non-object is no usage.
func parseGeminiTokens(raw json.RawMessage) (geminiTokens, bool) {
	var m map[string]json.RawMessage
	if len(raw) == 0 || json.Unmarshal(raw, &m) != nil || m == nil {
		return geminiTokens{}, false
	}
	pick := func(keys ...string) int64 {
		for _, k := range keys {
			if v, ok := m[k]; ok {
				if n, ok := f64u(v); ok {
					return n
				}
			}
		}
		return 0
	}
	t := geminiTokens{
		input:    pick("input", "prompt", "input_tokens", "prompt_tokens"),
		output:   pick("output", "candidates", "output_tokens", "candidates_tokens"),
		cached:   pick("cached", "cached_tokens"),
		thoughts: pick("thoughts", "reasoning", "thoughts_tokens", "reasoning_tokens"),
		tool:     pick("tool", "tool_tokens"),
	}
	total, ok := m["total"]
	if !ok {
		total, ok = m["total_tokens"]
	}
	if ok {
		t.total, t.hasTotal = f64u(total)
	}
	return t, true
}

func subtractCachedOverlap(t geminiTokens) (int64, int64) {
	return t.input - min(t.input, t.cached), t.cached
}

// normalizeSessionInput subtracts the cached overlap only when the reported
// total proves the prompt count included the cached tokens.
func normalizeSessionInput(t geminiTokens) (int64, int64) {
	inclusive := sat(sat(sat(t.input, t.output), t.thoughts), t.tool)
	exclusive := sat(inclusive, t.cached)
	if t.cached > 0 && t.hasTotal && t.total == inclusive && t.total != exclusive {
		return subtractCachedOverlap(t)
	}
	return t.input, t.cached
}

// geminiEvent is build_event followed by event_to_loaded: the entry's
// reasoning is total - (input + output + cache read), saturating at zero.
func geminiEvent(model string, at time.Time, t geminiTokens, normalize func(geminiTokens) (int64, int64)) (Entry, bool) {
	if model == "" {
		return Entry{}, false
	}
	noCache, cacheRead := normalize(t)
	input := sat(noCache, t.tool)
	total := t.total
	if !t.hasTotal {
		total = sat(sat(sat(input, t.output), cacheRead), t.thoughts)
	}
	output, extra := fallback(input, t.output, 0, cacheRead, t.thoughts, total)
	if input == 0 && output == 0 && cacheRead == 0 && extra == 0 {
		return Entry{}, false
	}
	reasoning := total - sat(sat(input, output), cacheRead)
	if reasoning < 0 {
		reasoning = 0
	}
	return entry(at, Buckets{Input: input, CacheRead: cacheRead, Output: output, Reasoning: reasoning}), true
}

func geminiDirect(r geminiRecord, hint string, fallbackAt time.Time) (Entry, bool) {
	t, ok := parseGeminiTokens(r.Tokens)
	if !ok {
		return Entry{}, false
	}
	model := nonEmpty(r.Model)
	if model == "" {
		model = hint
	}
	at, ok := tsOr(r.Timestamp, fallbackAt)
	if !ok {
		at, _ = tsOr(r.CreatedAt, fallbackAt)
	}
	return geminiEvent(model, at, t, normalizeSessionInput)
}

func geminiStats(stats json.RawMessage, hint string, at time.Time) []Entry {
	var obj map[string]json.RawMessage
	if len(stats) == 0 || json.Unmarshal(stats, &obj) != nil || obj == nil {
		return nil
	}
	out := []Entry{}
	var models map[string]json.RawMessage
	if raw, ok := obj["models"]; ok && json.Unmarshal(raw, &models) == nil {
		for model, data := range models {
			var d map[string]json.RawMessage
			if json.Unmarshal(data, &d) != nil || d == nil {
				continue
			}
			if t, ok := parseGeminiTokens(d["tokens"]); ok {
				if e, ok := geminiEvent(model, at, t, subtractCachedOverlap); ok {
					out = append(out, e)
				}
			}
		}
		if len(out) > 0 {
			return out
		}
	}
	t, _ := parseGeminiTokens(stats)
	if hint == "" {
		hint = "unknown"
	}
	if e, ok := geminiEvent(hint, at, t, subtractCachedOverlap); ok {
		out = append(out, e)
	}
	return out
}

// Gemini reads one Gemini CLI chat file the way ccusage does: a JSON session
// snapshot (messages of type "gemini"), a single record, or stats; or JSONL
// records, where a repeated message id replaces the earlier record. mtime is
// the fallback time. ccusage does not deduplicate across files.
func Gemini(b []byte, jsonl bool, mtime time.Time) []Entry {
	if !jsonl {
		var r geminiRecord
		if json.Unmarshal(b, &r) != nil {
			return nil
		}
		sessionAt, ok := tsOr(r.StartTime, mtime)
		if !ok {
			sessionAt, _ = tsOr(r.Updated, mtime)
		}
		var messages []json.RawMessage
		if len(r.Messages) > 0 && json.Unmarshal(r.Messages, &messages) == nil && messages != nil {
			out := []Entry{}
			for _, raw := range messages {
				var m geminiRecord
				if json.Unmarshal(raw, &m) != nil || !m.isGemini() {
					continue
				}
				// A snapshot message names its own model; there is no hint.
				if e, ok := geminiDirect(m, "", sessionAt); ok {
					out = append(out, e)
				}
			}
			return out
		}
		if r.isGemini() {
			if e, ok := geminiDirect(r, "", mtime); ok {
				return []Entry{e}
			}
			return nil
		}
		at, _ := tsOr(r.Timestamp, mtime)
		return geminiStats(r.stats(), nonEmpty(r.Model), at)
	}
	out := []Entry{}
	index := map[string]int{}
	model := ""
	for _, line := range lines(b) {
		var r geminiRecord
		if json.Unmarshal(line, &r) != nil {
			continue
		}
		if m := nonEmpty(r.Model); m != "" {
			model = m
		}
		if r.isGemini() {
			e, ok := geminiDirect(r, model, mtime)
			if !ok {
				continue
			}
			if id := nonEmpty(r.ID); id != "" {
				if i, seen := index[id]; seen {
					out[i] = e
					continue
				}
				index[id] = len(out)
			}
			out = append(out, e)
			continue
		}
		if stats := r.stats(); stats != nil {
			at, _ := tsOr(r.Timestamp, mtime)
			out = append(out, geminiStats(stats, model, at)...)
		}
	}
	return out
}
