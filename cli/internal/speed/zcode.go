package speed

import (
	"database/sql"
	"path/filepath"
	"strings"
	"time"
)

// ZCode (Z.ai's coding agent, github.com/zai-org/ZCode) records one row per model call in
// ~/.zcode/cli/db/db.sqlite, table model_usage: session, turn, model, token counts and the call's
// start and end in unix ms; output_tokens includes reasoning. The session table names its
// working directory. Read as tokei (github.com/cclank/tokei, MIT) and Tokscale
// (github.com/junhoyeo/tokscale, MIT) read it; no transcript is read.

const ParserZCode = "zcode-db/1"

// ZCodeDB: $MODELPLAN_ZCODE_DB, else ~/.zcode/cli/db/db.sqlite.
func ZCodeDB(home string) string {
	if p := envPath("MODELPLAN_ZCODE_DB"); p != "" {
		return p
	}
	return filepath.Join(home, ".zcode", "cli", "db", "db.sqlite")
}

func readZCode(db *sql.DB, after int64, pending []int64) ([]dbRow, error) {
	join, dir := "", "''"
	if hasColumns(db, "session", "id", "directory") {
		join, dir = " LEFT JOIN session s ON s.id = mu.session_id", "COALESCE(s.directory, '')"
	}
	q := `SELECT mu.rowid, CAST(mu.id AS TEXT), COALESCE(mu.session_id, ''), COALESCE(mu.model_id, ''),
		COALESCE(mu.started_at, 0), COALESCE(mu.completed_at, 0), COALESCE(mu.output_tokens, 0), ` + dir + `
		FROM model_usage mu` + join + ` WHERE mu.rowid > ?` + inRowIDs("mu.rowid", pending) + ` ORDER BY mu.rowid LIMIT ` + itoa64(dbBatch)
	rows, err := db.Query(q, after)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []dbRow
	for rows.Next() {
		var r dbRow
		var id string
		if rows.Scan(&r.rowid, &id, &r.session, &r.model, &r.start, &r.end, &r.out, &r.cwd) != nil {
			continue
		}
		r.key = "zcode:" + id
		out = append(out, r)
	}
	return out, rows.Err()
}

// ObserveZCode reads what is new in ZCode's database into the performance ledger.
func ObserveZCode(cache, home string, in Ingest, now time.Time) error {
	path := ZCodeDB(home)
	if dbSig(path) == "" {
		return nil
	}
	return observePerf(cache, now, in, func(l *PerfLedger) bool {
		return l.scanDB(path, "zcode", ParserZCode, now, readZCode)
	})
}

// hasColumns: the table exists with these columns.
func hasColumns(db *sql.DB, table string, cols ...string) bool {
	rows, err := db.Query("SELECT name FROM pragma_table_info(?)", table)
	if err != nil {
		return false
	}
	defer rows.Close()
	have := map[string]bool{}
	for rows.Next() {
		var n string
		if rows.Scan(&n) == nil {
			have[n] = true
		}
	}
	for _, c := range cols {
		if !have[c] {
			return false
		}
	}
	return len(have) > 0
}

// inRowIDs: " OR <col> IN (…)" for the pending rows, "" for none. Integers only.
func inRowIDs(col string, ids []int64) string {
	if len(ids) == 0 {
		return ""
	}
	parts := make([]string, len(ids))
	for i, id := range ids {
		parts[i] = itoa64(id)
	}
	return " OR " + col + " IN (" + strings.Join(parts, ",") + ")"
}
