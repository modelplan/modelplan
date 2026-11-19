// SPDX-License-Identifier: MIT
// Ported from ccusage (github.com/ccusage/ccusage, MIT, Copyright (c) 2025
// ryoppippi; LICENSES/ccusage-MIT.txt) at
// 58866ba681343634ab6e5add61f18f3b70aa98f7: rust/adapters/opencode/src/parser.rs
// (OpenCodeTokens, message_value_to_entry_inner) and
// rust/adapters/opencode/src/loader.rs (fork_copy_cutoffs, fork_copy_cutoff,
// last_parent_seq_before, is_fork_copy). Modified for Go: the caller selects
// only the tokens object with json_extract, never message content.

package tokenacct

import (
	"database/sql"
	"encoding/json"
)

type openCodeTokens struct {
	Input     json.RawMessage `json:"input"`
	Output    json.RawMessage `json:"output"`
	Reasoning json.RawMessage `json:"reasoning"`
	Total     json.RawMessage `json:"total"`
	Cache     json.RawMessage `json:"cache"`
}

// OpenCodeTokens converts an OpenCode message's tokens object to buckets:
// input, output, cache.read and cache.write as stored, reasoning as extra,
// and the total fallback. ok is false for no tokens object or no usage.
func OpenCodeTokens(raw string) (Buckets, bool) {
	var t openCodeTokens
	if !present(json.RawMessage(raw)) || json.Unmarshal([]byte(raw), &t) != nil {
		return Buckets{}, false
	}
	var cache struct {
		Read  json.RawMessage `json:"read"`
		Write json.RawMessage `json:"write"`
	}
	// A cache field of another shape reads as no cache (jsonl::lenient_object).
	_ = json.Unmarshal(t.Cache, &cache)
	b := Buckets{Input: u64(t.Input), Output: u64(t.Output), CacheRead: u64(cache.Read), CacheWrite: u64(cache.Write)}
	b.Output, b.Reasoning = fallback(b.Input, b.Output, b.CacheWrite, b.CacheRead, u64(t.Reasoning), u64(t.Total))
	if b.Zero() {
		return Buckets{}, false
	}
	b.Total = b.Sum()
	return b, true
}

// OpenCodeForkCutoffs maps each forked session to the largest session_message
// seq that is copied parent history. ccusage skips those rows: the copies get
// new ids, so an id dedupe cannot catch them. A fork whose boundary cannot be
// resolved keeps all of its rows. Without the columns the map is empty.
func OpenCodeForkCutoffs(db *sql.DB) map[string]int64 {
	out := map[string]int64{}
	rows, err := db.Query(`SELECT id, fork_session_id, fork_boundary FROM session_v2 WHERE fork_session_id IS NOT NULL AND fork_boundary IS NOT NULL`)
	if err != nil {
		return out
	}
	type fork struct{ id, parent, boundary string }
	var forks []fork
	for rows.Next() {
		var f fork
		if rows.Scan(&f.id, &f.parent, &f.boundary) == nil && f.id != "" && f.parent != "" {
			forks = append(forks, f)
		}
	}
	rows.Close()
	for _, f := range forks {
		var b struct {
			Type      string `json:"type"`
			MessageID string `json:"messageID"`
		}
		if json.Unmarshal([]byte(f.boundary), &b) != nil || b.MessageID == "" {
			continue
		}
		var seq int64
		if db.QueryRow(`SELECT seq FROM session_message WHERE session_id = ? AND id = ? LIMIT 1`, f.parent, b.MessageID).Scan(&seq) != nil {
			continue
		}
		switch b.Type {
		case "through":
			out[f.id] = seq
		case "before":
			// seq is sparse: the last parent row below the boundary, not boundary-1.
			var last sql.NullInt64
			if db.QueryRow(`SELECT MAX(seq) FROM session_message WHERE session_id = ? AND seq < ?`, f.parent, seq).Scan(&last) == nil && last.Valid {
				out[f.id] = last.Int64
			}
		}
	}
	return out
}
