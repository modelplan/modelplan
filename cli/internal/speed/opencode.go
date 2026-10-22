package speed

import (
	"database/sql"
	"path/filepath"
	"sort"
	"time"
)

// OpenCode V2 (github.com/sst/opencode) keeps assistant messages in opencode.db, table
// session_message (type "assistant"), as JSON: time.created and time.completed in unix ms,
// model.id, and tokens with output and reasoning apart (both count as output here, as Codex and
// Claude Code report them). Sessions name their working directory in session or session_v2. A
// forked session copies earlier messages with their own JSON id and times, so a message is known
// by that id (else by its time, model and tokens). Read as tokei (github.com/cclank/tokei, MIT)
// and Tokscale (github.com/junhoyeo/tokscale, MIT) read it. The V1 message table and JSON
// storage are not read.

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

func readOpenCode(db *sql.DB, after int64, pending []int64) ([]dbRow, error) {
	dir, join := "''", ""
	for _, t := range []string{"session_v2", "session"} {
		if hasColumns(db, t, "id", "directory") {
			join, dir = " LEFT JOIN "+t+" s ON s.id = m.session_id", "COALESCE(s.directory, '')"
			break
		}
	}
	q := `SELECT m.rowid,
		COALESCE(json_extract(m.data, '$.id'), ''),
		COALESCE(m.session_id, ''),
		COALESCE(json_extract(m.data, '$.model.id'), json_extract(m.data, '$.modelID'), ''),
		CAST(COALESCE(json_extract(m.data, '$.time.created'), 0) AS INTEGER),
		CAST(COALESCE(json_extract(m.data, '$.time.completed'), 0) AS INTEGER),
		CAST(COALESCE(json_extract(m.data, '$.tokens.output'), 0) AS INTEGER) + CAST(COALESCE(json_extract(m.data, '$.tokens.reasoning'), 0) AS INTEGER),
		COALESCE(json_extract(m.data, '$.tokens'), ''),
		` + dir + `
		FROM session_message m` + join + ` WHERE m.type = 'assistant' AND (m.rowid > ?` + inRowIDs("m.rowid", pending) + `) ORDER BY m.rowid LIMIT ` + itoa64(dbBatch)
	rows, err := db.Query(q, after)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []dbRow
	for rows.Next() {
		var r dbRow
		var id, tokens string
		if rows.Scan(&r.rowid, &id, &r.session, &r.model, &r.start, &r.end, &r.out, &tokens, &r.cwd) != nil {
			continue
		}
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
		return l.scanDB(path, "opencode", ParserOpenCode, now, readOpenCode)
	})
}
