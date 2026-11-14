package speed

import (
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Clearing a tool's local history (quota.EraseScope) removes everything the ledgers kept about
// it: rows, sessions, request hashes, log cursors and database cursors. Without those, the next
// read would take the tool's logs from the start, and a resumed Claude Code session's copy of an
// old request would no longer be recognised. So the clear leaves one boundary per tool in
// <cache>/observed/cleared.json: the time of the clear. The observers and the history importer
// count nothing of that tool from before it. For a tool that keeps its history in an agent
// database (ZCode, OpenCode), the clear also keeps one row number: the database's highest row then
// ("cleared through row N"). Its next read starts past that row, so the pre-clear rows are never
// read again; a database that no longer has that row was replaced, and is read from the start
// under the time boundary. The file holds only tool names, times and those row numbers: no paths,
// database hashes, request ids or counts. Each boundary applies only to its own tool: clearing one
// tool never holds back another tool's logs.
type Cleared struct {
	SchemaVersion int                  `json:"schemaVersion"`
	Tools         map[string]time.Time `json:"tools,omitempty"` // consent tool id → clear time, UTC
	// DBRows: consent tool id → the highest row of the tool's agent database at the clear
	// ("cleared through row N"). One number per tool; never a path, a database hash or a row's id.
	DBRows map[string]int64 `json:"dbRows,omitempty"`
}

// ClearedPath is the boundary file.
func ClearedPath(cache string) string { return filepath.Join(cache, "observed", "cleared.json") }

// LoadCleared never fails: a missing or unreadable file has no boundaries.
func LoadCleared(cache string) Cleared {
	var c Cleared
	b, err := os.ReadFile(ClearedPath(cache))
	if err != nil || len(b) > 64<<10 || json.Unmarshal(b, &c) != nil || c.SchemaVersion != 1 {
		return Cleared{SchemaVersion: 1}
	}
	return c
}

// MarkCleared records a clear of tool at now. A boundary never moves back. The caller holds the
// ledger locks (LockLedgersForCleanup).
func MarkCleared(cache, tool string, now time.Time) error {
	if tool == "" {
		return errors.New("no tool")
	}
	// Rounded up: a request that finished in the second of the clear is cleared with it.
	at := now.UTC().Truncate(time.Second).Add(time.Second)
	c := LoadCleared(cache)
	if c.Tools == nil {
		c.Tools = map[string]time.Time{}
	}
	if at.After(c.Tools[tool]) {
		c.Tools[tool] = at
	}
	if err := os.MkdirAll(filepath.Dir(ClearedPath(cache)), 0o700); err != nil {
		return err
	}
	b, _ := json.Marshal(c)
	return write(ClearedPath(cache), append(b, '\n'))
}

// clearedDBs: the agent database of each tool that keeps one, with its ledger source and the
// query for its highest row.
var clearedDBs = map[string]struct {
	source string
	path   func(home string) string
	top    string
}{
	"zai":        {"zcode", ZCodeDB, `SELECT COALESCE(MAX(rowid), 0) FROM model_usage`},
	"opencodego": {"opencode", OpenCodeDB, `SELECT COALESCE(MAX(rowid), 0) FROM session_message`},
}

// MarkClearedDB records how far the tool's agent database went when its history was cleared: its
// highest row, or, when it cannot be read, the row its cursor had reached. Called with the clear's
// MarkCleared, before the tool's cursors are removed; the caller holds the ledger locks. A tool
// without a database records nothing; a clear that finds no rows removes an earlier number.
func MarkClearedDB(cache, home, tool string) error {
	d, ok := clearedDBs[tool]
	if !ok {
		return nil
	}
	var rows int64
	path := d.path(home)
	if db, err := openRO(path); err == nil {
		_ = db.QueryRow(d.top).Scan(&rows)
		db.Close()
	}
	if p, ok := LoadPerf(cache); ok {
		rows = max(rows, p.Stores[d.source+":"+fileKey(path)].RowID)
	}
	c := LoadCleared(cache)
	if c.DBRows == nil {
		c.DBRows = map[string]int64{}
	}
	if rows > 0 {
		c.DBRows[tool] = rows
	} else {
		delete(c.DBRows, tool)
	}
	if err := os.MkdirAll(filepath.Dir(ClearedPath(cache)), 0o700); err != nil {
		return err
	}
	b, _ := json.Marshal(c)
	return write(ClearedPath(cache), append(b, '\n'))
}

// dbRows: the row a database of source was cleared through, 0 when none.
func (c Cleared) dbRows(source string) int64 { return c.DBRows[sourceTool(source)] }

// sourceTool: the consent tool id of a ledger source (claude-code → claude, zcode → zai, …).
func sourceTool(source string) string {
	if scope := sourceScope(source); scope != "" {
		tool, _, _ := strings.Cut(scope, ".")
		return tool
	}
	return source
}

// floor: the earliest time a turn of source may count from in the live ledgers.
func (c Cleared) floor(source string) time.Time { return c.Tools[sourceTool(source)] }

// tool: the importer's boundary for source.
func (c Cleared) tool(source string) time.Time { return c.Tools[sourceTool(source)] }

// LegacyCursorSources attributes the log cursors an earlier build wrote without a source, by
// cursor key. First by where the log lives: the key of every log under roots (each tool's own log
// folder) is computed and compared, which nothing in the key itself could reveal. Then, for keys
// no log under roots matches, from what the ledgers know of that key: the source of the same key's
// cursor in the other ledger, of a perf session or live record kept under it, a Claude counted
// request read from it (claude-code), or a Codex-only field (a cumulative total, a background
// thread's skip mark: codex). A key with no evidence, or with conflicting ledger evidence, is left
// out. A clear removes such a cursor with the cleared tool's: it may be that tool's history. The
// caller holds the ledger locks and calls this once, before rewriting either ledger.
func LegacyCursorSources(cache string, roots []LogRoot) map[string]string {
	evidence := map[string]map[string]bool{}
	note := func(key, source string) {
		if key == "" || (source != "claude-code" && source != "codex") {
			return
		}
		if evidence[key] == nil {
			evidence[key] = map[string]bool{}
		}
		evidence[key][source] = true
	}
	unattributed := map[string]bool{}
	for _, p := range []string{Path(cache), PerfPath(cache)} {
		b, err := os.ReadFile(p)
		if err != nil || len(b) > 4<<20 {
			continue
		}
		var l struct {
			Files    map[string]Cursor `json:"files"`
			Counted  []CountedRequest  `json:"counted"`
			Sessions []struct {
				Key    string `json:"key"`
				Source string `json:"source"`
			} `json:"sessions"`
			Live []struct {
				Key    string `json:"key"`
				Source string `json:"source"`
			} `json:"live"`
		}
		if json.Unmarshal(b, &l) != nil {
			continue
		}
		for key, c := range l.Files {
			switch {
			case c.Source != "":
				note(key, c.Source)
			case c.Total != nil || c.Skip:
				note(key, "codex")
				unattributed[key] = true
			default:
				unattributed[key] = true
			}
		}
		for _, c := range l.Counted {
			note(c.File, "claude-code")
		}
		for _, s := range l.Sessions {
			note(s.Key, s.Source)
		}
		for _, r := range l.Live {
			note(r.Key, r.Source)
		}
	}
	out := map[string]string{}
	if len(unattributed) > 0 {
		for key, source := range logKeys(roots, unattributed) {
			out[key] = source
		}
	}
	for key := range unattributed {
		if out[key] != "" {
			continue
		}
		if len(evidence[key]) == 1 {
			for source := range evidence[key] {
				out[key] = source
			}
		}
	}
	return out
}

// LogRoot: a folder holding one source's logs (Claude Code: <config>/projects; Codex:
// <home>/sessions).
type LogRoot struct{ Dir, Source string }

// maxAttributionEntries bounds the folder walk per root.
const maxAttributionEntries = 50000

// logKeys: for the wanted cursor keys, the source of the log under roots whose key it is. Links
// are not followed; only regular .jsonl files count. A log in two roots' folders is left out.
func logKeys(roots []LogRoot, want map[string]bool) map[string]string {
	found := map[string]map[string]bool{}
	for _, root := range roots {
		if root.Dir == "" || !filepath.IsAbs(root.Dir) || root.Source == "" {
			continue
		}
		visited := 0
		_ = filepath.WalkDir(root.Dir, func(path string, d fs.DirEntry, err error) error {
			if visited++; visited > maxAttributionEntries {
				return fs.SkipAll
			}
			if err != nil || d.IsDir() || d.Type()&fs.ModeSymlink != 0 || !strings.HasSuffix(path, ".jsonl") {
				return nil
			}
			if key := fileKey(path); want[key] {
				if found[key] == nil {
					found[key] = map[string]bool{}
				}
				found[key][root.Source] = true
			}
			return nil
		})
	}
	out := map[string]string{}
	for key, sources := range found {
		if len(sources) == 1 {
			for source := range sources {
				out[key] = source
			}
		}
	}
	return out
}
