// SPDX-License-Identifier: MIT
// Ported from ccusage (github.com/ccusage/ccusage, MIT, Copyright (c) 2025
// ryoppippi; LICENSES/ccusage-MIT.txt) at
// 58866ba681343634ab6e5add61f18f3b70aa98f7: rust/adapters/qwen/src/parser.rs
// (read_chat_file, parse_line, entry_id, the first-wins dedupe in
// load_entries) and rust/adapters/qwen/src/paths.rs (session fallback).
// Modified for Go: only type, time, session, model and usageMetadata are
// decoded; message text is skipped by the decoder and never kept.

package tokenacct

import (
	"bytes"
	"encoding/json"
	"strconv"
	"time"
)

type qwenLine struct {
	Type      json.RawMessage `json:"type"`
	Usage     *qwenUsage      `json:"usageMetadata"`
	Timestamp json.RawMessage `json:"timestamp"`
	Session   json.RawMessage `json:"sessionId"`
	Model     json.RawMessage `json:"model"`
}

type qwenUsage struct {
	Prompt     json.RawMessage `json:"promptTokenCount"`
	Candidates json.RawMessage `json:"candidatesTokenCount"`
	Thoughts   json.RawMessage `json:"thoughtsTokenCount"`
	Cached     json.RawMessage `json:"cachedContentTokenCount"`
	Total      json.RawMessage `json:"totalTokenCount"`
}

// QwenEntry is a Qwen record with ccusage's dedupe identity.
type QwenEntry struct {
	Entry
	key string
}

// Qwen reads one Qwen Code chats/*.jsonl file the way ccusage does. Only
// assistant records with usageMetadata count. Qwen's prompt count is taken as
// ccusage takes it: input as reported, cachedContentTokenCount as cache read,
// thoughtsTokenCount as reasoning, with the total fallback. project is the
// projects/<project> directory name and stem the file name without .jsonl;
// they name the session when a record has no sessionId.
func Qwen(b []byte, project, stem string, mtime time.Time) []QwenEntry {
	out := []QwenEntry{}
	for _, line := range lines(b) {
		if !bytes.Contains(line, []byte(`"usageMetadata"`)) {
			continue
		}
		var r qwenLine
		if json.Unmarshal(line, &r) != nil || r.Usage == nil || nonEmpty(r.Type) != "assistant" {
			continue
		}
		u := r.Usage
		input, output, reasoning, cacheRead, total := u64(u.Prompt), u64(u.Candidates), u64(u.Thoughts), u64(u.Cached), u64(u.Total)
		output, extra := fallback(input, output, 0, cacheRead, reasoning, total)
		if input == 0 && output == 0 && cacheRead == 0 && extra == 0 {
			continue
		}
		at, stamp := mtime, ""
		if s := nonEmpty(r.Timestamp); s != "" {
			if t, ok := parseTS(s); ok {
				at, stamp = t, s
			}
		}
		if stamp == "" {
			stamp = at.UTC().Format("2006-01-02T15:04:05.000Z")
		}
		session := nonEmpty(r.Session)
		if session == "" {
			if project == "" {
				project = "unknown"
			}
			session = project + "-" + stem
		}
		model := nonEmpty(r.Model)
		if model == "" {
			model = "unknown"
		}
		key, _ := json.Marshal([]string{session, stamp, model, strconv.FormatInt(input, 10), strconv.FormatInt(output, 10), strconv.FormatInt(cacheRead, 10), strconv.FormatInt(extra, 10)})
		out = append(out, QwenEntry{entry(at, Buckets{Input: input, CacheRead: cacheRead, Output: output, Reasoning: extra}), string(key)})
	}
	return out
}

// DedupeQwen keeps the first record of each identity across files, as
// ccusage does: session, timestamp text, model and the token buckets.
func DedupeQwen(files ...[]QwenEntry) []Entry {
	seen := map[string]bool{}
	out := []Entry{}
	for _, file := range files {
		for _, e := range file {
			if seen[e.key] {
				continue
			}
			seen[e.key] = true
			out = append(out, e.Entry)
		}
	}
	return out
}
