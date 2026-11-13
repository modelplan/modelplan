package speed

import (
	"encoding/json"
	"errors"
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
// count nothing of that tool from before it. The file holds only tool names and times: no
// paths, hashes or counts.
//
// Logs: cursors written by an earlier build carry no source, so a clear removes them all. The
// logs boundary keeps the other tools' logs whose cursors went with them from being read again
// from the start by the live observers (the importer, which reads by date, does not use it).
type Cleared struct {
	SchemaVersion int                  `json:"schemaVersion"`
	Tools         map[string]time.Time `json:"tools,omitempty"` // consent tool id → clear time, UTC
	Logs          time.Time            `json:"logs,omitzero"`
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

// MarkCleared records a clear of tool (and, with logs, of the unattributed log cursors) at now.
// A boundary never moves back. The caller holds the ledger locks (LockLedgersForCleanup).
func MarkCleared(cache, tool string, logs bool, now time.Time) error {
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
	if logs && at.After(c.Logs) {
		c.Logs = at
	}
	if err := os.MkdirAll(filepath.Dir(ClearedPath(cache)), 0o700); err != nil {
		return err
	}
	b, _ := json.Marshal(c)
	return write(ClearedPath(cache), append(b, '\n'))
}

// sourceTool: the consent tool id of a ledger source (claude-code → claude, zcode → zai, …).
func sourceTool(source string) string {
	if scope := sourceScope(source); scope != "" {
		tool, _, _ := strings.Cut(scope, ".")
		return tool
	}
	return source
}

// floor: the earliest time a turn of source may count from in the live ledgers.
func (c Cleared) floor(source string) time.Time {
	at := c.Tools[sourceTool(source)]
	if (source == "claude-code" || source == "codex") && c.Logs.After(at) {
		at = c.Logs
	}
	return at
}

// tool: the importer's boundary for source (the logs boundary does not apply to it).
func (c Cleared) tool(source string) time.Time { return c.Tools[sourceTool(source)] }

// HasUnattributedCursors: a ledger holds a log cursor without a source (written by an earlier
// build). A clear removes those, so it also sets the logs boundary.
func HasUnattributedCursors(cache string) bool {
	for _, p := range []string{Path(cache), PerfPath(cache)} {
		b, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		var l struct {
			Files map[string]Cursor `json:"files"`
		}
		if json.Unmarshal(b, &l) != nil {
			return true // unreadable: assume the worst
		}
		for _, c := range l.Files {
			if c.Source == "" {
				return true
			}
		}
	}
	return false
}
