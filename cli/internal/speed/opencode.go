package speed

import (
	"database/sql"
	"path/filepath"
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/tokenacct"
)

// OpenCode V2 (github.com/sst/opencode) keeps assistant messages in opencode.db, table
// session_message (type "assistant"), as JSON: time.created and time.completed in unix ms,
// model.id, and tokens with output and reasoning apart (both count as output here, as Codex and
// Claude Code report them). Sessions name their working directory in session or session_v2. A
// forked session copies earlier messages with their own JSON id and times, so a message is known
// by that id (else by its time, model and tokens). Read as tokei (github.com/cclank/tokei, MIT)
// and Tokscale (github.com/junhoyeo/tokscale, MIT) read it. The V1 message table and JSON
// storage are not read.
//
// Token accounting matches ccusage (tokenacct, ccusage@58866ba6 rust/adapters/opencode): a
// completed compaction is billed usage of its own; rows a fork copied from its parent (seq at
// or below the fork boundary) are not counted again; output is output + reasoning + whatever
// part of a reported total the other buckets leave unexplained.

const ParserOpenCode = "opencode-db/1"

// OpenCodeDB: $MODELPLAN_OPENCODE_DB, else <data home>/opencode/opencode.db, else the first
// release channel's opencode-<channel>.db there.
func OpenCodeDB(home string) string {
	if p := envPath("MODELPLAN_OPENCODE_DB"); p != "" {
		return p
	}
	dir := filepath.Join(dataHome(home), "opencode")
	p := filepath.Join(dir, "opencode.db")
	if dbSig(p) != "" {
		return p
	}
	chans, _ := filepath.Glob(filepath.Join(dir, "opencode-*.db"))
	sort.Strings(chans)
	if len(chans) > 0 {
		return chans[0]
	}
	return p
}

// openCodeCounted: the session_message rows that carry billed usage (ccusage's
// SessionMessageKind: assistant steps and completed compactions).
const openCodeCounted = `(type = 'assistant' OR (type = 'compaction' AND json_extract(data, '$.status') = 'completed'))`

func readOpenCode(db *sql.DB, after int64, pending []int64) ([]dbRow, error) {
	dir, join, pid, pname, seq := "''", "", "''", "''", "NULL"
	forks := map[string]int64{}
	if hasColumns(db, "session_message", "seq") {
		seq = "m.seq"
		if hasColumns(db, "session_v2", "id", "fork_session_id", "fork_boundary") {
			forks = tokenacct.OpenCodeForkCutoffs(db)
		}
	}
	for _, t := range []string{"session_v2", "session"} {
		if hasColumns(db, t, "id", "directory") {
			join, dir = " LEFT JOIN "+t+" s ON s.id = m.session_id", "COALESCE(s.directory, '')"
			if hasColumns(db, t, "project_id") {
				pid = "COALESCE(s.project_id, '')"
				if hasColumns(db, "project", "id", "worktree") {
					join += " LEFT JOIN project p ON p.id = s.project_id"
					pname = "COALESCE(NULLIF(" + projectNameExpr(db) + ", ''), p.worktree, '')"
				}
			}
			break
		}
	}
	// Read unfinished compactions too, with end=0, so scanDB keeps them Pending
	// when a later row advances the cursor. Only completed status makes them count.
	q := `SELECT m.rowid,
		COALESCE(json_extract(m.data, '$.id'), ''),
		COALESCE(m.session_id, ''),
		COALESCE(json_extract(m.data, '$.model.id'), json_extract(m.data, '$.modelID'), ''),
		CAST(COALESCE(json_extract(m.data, '$.time.created'), 0) AS INTEGER),
		CAST(CASE WHEN m.type = 'compaction' THEN
            CASE WHEN json_extract(m.data, '$.status') = 'completed'
                THEN COALESCE(json_extract(m.data, '$.time.completed'), json_extract(m.data, '$.time.created'), 0)
                ELSE 0 END
            ELSE COALESCE(json_extract(m.data, '$.time.completed'), 0) END AS INTEGER),
		COALESCE(json_extract(m.data, '$.tokens'), ''),
		` + dir + `, ` + pid + `, ` + pname + `,
        json_extract(m.data, '$.tokens.input'), json_extract(m.data, '$.tokens.cache.read'), json_extract(m.data, '$.tokens.cache.write'), ` + seq + `
        FROM session_message m` + join + ` WHERE m.type IN ('assistant', 'compaction') AND (m.rowid > ?` + inRowIDs("m.rowid", pending) + `) ORDER BY m.rowid LIMIT ` + itoa64(dbBatch)
	rows, err := db.Query(q, after)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []dbRow
	for rows.Next() {
		var r dbRow
		var id, tokens string
		var input, read, write, at sql.NullInt64
		if rows.Scan(&r.rowid, &id, &r.session, &r.model, &r.start, &r.end, &tokens, &r.cwd, &r.np.ID, &r.np.Name, &input, &read, &write, &at) != nil {
			continue
		}
		if b, ok := tokenacct.OpenCodeTokens(tokens); ok {
			r.out = b.Output + b.Reasoning
			if r.out < b.Output {
				r.out = b.Output // saturated
			}
		}
		if cut, ok := forks[r.session]; ok && at.Valid && at.Int64 <= cut {
			r.start = 0 // copied parent history: the row position moves on, nothing counts
		}
		r.TokenKinds = TokenKinds{InputTokens: nullCount(input), CacheReadTokens: nullCount(read), CacheWriteTokens: nullCount(write)}
		r.key = "opencode:" + id
		if id == "" {
			r.key = "opencode~" + itoa64(r.start) + "|" + r.model + "|" + tokens
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// ObserveOpenCode reads what is new in OpenCode's database into the performance ledger.
func ObserveOpenCode(cache, home string, in Ingest, now time.Time) error {
	path := OpenCodeDB(home)
	if dbSig(path) == "" {
		return nil
	}
	return observePerf(cache, now, in, func(l *PerfLedger) bool {
		return l.scanDB(path, "opencode", ParserOpenCode, openCodeAnchor, openCodePostClear, now, readOpenCode)
	})
}

// openCodeAnchor: a message's own id and creation time, which a replaced database does not repeat.
const openCodeAnchor = `SELECT COALESCE(json_extract(data, '$.id'), '') || '|' || COALESCE(json_extract(data, '$.time.created'), 0) FROM session_message WHERE rowid = ?`

// openCodePostClear: the counted messages (openCodeCounted) up to a row created at or after a time, by the start
// readOpenCode reads (a missing or non-numeric creation time is 0).
const openCodePostClear = `FROM session_message WHERE ` + openCodeCounted + ` AND rowid <= ? AND CAST(COALESCE(json_extract(data, '$.time.created'), 0) AS INTEGER) >= ?`

// projectNameExpr: OpenCode's project name column when the table has one.
func projectNameExpr(db *sql.DB) string {
	if hasColumns(db, "project", "name") {
		return "p.name"
	}
	return "''"
}
