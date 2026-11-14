package speed

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"math"
	"net/url"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"strconv"
	"strings"
	"time"

	_ "modernc.org/sqlite" // pure Go, read-only use
)

// Agents that keep their history in SQLite rather than in log files: ZCode (zcode.go) and
// OpenCode V2 (opencode.go). Each database is opened read-only (query_only, never created) and
// read incrementally: rows past the last rowid seen, plus the requests that were still running
// last time. Only finished requests count, each once (by a hash of its own id), and only those
// that started after the ledger did. A row that starts long before the newest one counted is a
// copy of history (OpenCode copies messages into a forked session) and is not counted again.
// Prompts, replies, titles and ids are never read into the ledger; the session id only becomes a
// hashed key, the working directory a project reference.

// DBCursor is how far one database was read.
type DBCursor struct {
	Sig     string           `json:"sig"`               // size and time of the database and its WAL
	RowID   int64            `json:"rowid"`             // the last row read
	Pending []int64          `json:"pending,omitempty"` // rows of requests still running then
	Mark    int64            `json:"mark"`              // newest counted request start, unix ms
	Seen    map[string]int64 `json:"seen,omitempty"`    // hashed ids counted near Mark → start ms
	Day     string           `json:"day"`               // local date of the last read
	Checked time.Time        `json:"checked"`
	More    bool             `json:"more,omitempty"`   // the last read stopped at dbBatch rows
	Anchor  string           `json:"anchor,omitempty"` // hash of the row at RowID: the same database
	// After a reset, rows up to ResetRow that started no later than ResetMark (the newest request
	// counted before it) are never counted again, except the requests still running then.
	ResetRow     int64   `json:"resetRow,omitempty"`
	ResetMark    int64   `json:"resetMark,omitempty"`
	ResetPending []int64 `json:"resetPending,omitempty"`
}

const (
	dbLookback  = 6 * time.Hour // a request runs no longer; older rows past Mark are copies
	dbEvery     = 30 * time.Second
	maxPending  = 500
	maxSeenRows = 20000
	// dbBatch: rows read per run, so a first read of a long history never holds up a hook; the
	// rest follows on the next runs.
	dbBatch = 5000
)

// dbRow is one request as a database reports it.
type dbRow struct {
	rowid      int64
	key        string // the request's own id, or a fingerprint when it has none
	session    string
	model      string
	start, end int64 // unix ms; end 0 while running
	out        int64
	TokenKinds
	cwd string
}

// openRO opens an existing database for reading only.
func openRO(path string) (*sql.DB, error) {
	if fi, err := os.Stat(path); err != nil || !fi.Mode().IsRegular() {
		return nil, os.ErrNotExist
	}
	u := url.URL{Scheme: "file", Path: path, RawQuery: "mode=ro&_pragma=query_only(1)&_pragma=busy_timeout(1000)"}
	db, err := sql.Open("sqlite", u.String())
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	return db, nil
}

// dbSig: the database and WAL sizes and times; unchanged means nothing new to read.
func dbSig(path string) string {
	s := ""
	for _, p := range []string{path, path + "-wal"} {
		if fi, err := os.Stat(p); err == nil {
			s += strconv.FormatInt(fi.Size(), 10) + "@" + strconv.FormatInt(fi.ModTime().UnixNano(), 10) + ";"
		}
	}
	return s
}

// anchorOf: the hashed identity of the row with this rowid, "" when there is none, and the
// request start (unix ms) the anchor query ends with ("<id>|<start>"; 0 when unknown).
func anchorOf(db *sql.DB, query string, rowid int64) (string, int64, error) {
	var id string
	switch err := db.QueryRow(query, rowid).Scan(&id); {
	case errors.Is(err, sql.ErrNoRows):
		return "", 0, nil
	case err != nil:
		return "", 0, err
	}
	var start int64
	if i := strings.LastIndexByte(id, '|'); i >= 0 {
		if f, err := strconv.ParseFloat(id[i+1:], 64); err == nil {
			start = int64(f)
		}
	}
	return hashID("anchor:" + id), start, nil
}

// beforeClear: a request start from before the tool's clear (cleared, unix ms; 0: none).
func beforeClear(start, cleared int64) bool { return start > 0 && start < cleared }

// rowIDs: the row numbers a query selects.
func rowIDs(db *sql.DB, query string, args ...any) ([]int64, error) {
	rows, err := db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []int64
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

func hashID(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:8])
}

// scanDB reads what is new in one database with read (rows past a rowid, plus listed rowids) and
// adds the finished requests to the ledger under source. anchor selects a stable identity of the
// row with the given rowid (its own id and start), so a replaced database is recognised.
// postClear is the FROM … WHERE clause of the requests at or below a row number (first parameter)
// that started at or after a time (second parameter, unix ms): see below.
func (l *PerfLedger) scanDB(path, source, parser, anchor, postClear string, now time.Time, read func(db *sql.DB, after int64, pending []int64) ([]dbRow, error)) bool {
	if l.Stores == nil {
		l.Stores = map[string]DBCursor{}
	}
	key := source + ":" + fileKey(path)
	c := l.Stores[key]
	sig := dbSig(path)
	if sig == "" || (sig == c.Sig && len(c.Pending) == 0 && !c.More) || now.Sub(c.Checked) < dbEvery {
		return false
	}
	db, err := openRO(path)
	if err != nil {
		return false
	}
	defer db.Close()
	var cleared int64
	if f := l.cleared.floor(source); !f.IsZero() {
		cleared = f.UnixMilli()
	}
	// skip: the rows up to it are passed over unread because the row there is from before the clear.
	var skip int64
	if _, had := l.Stores[key]; !had {
		// The tool's history was cleared through row N of its database: read on past it, so the
		// rows from before the clear are not read again. When this database's row N is missing
		// or started after the clear, it is not the database that was cleared (replaced since):
		// it is read from the start, and the clear time keeps its earlier requests out.
		if n := l.cleared.dbRows(source); n > 0 {
			if at, start, err := anchorOf(db, anchor, n); err == nil && at != "" && beforeClear(start, cleared) {
				c.RowID, skip = n, n
			}
		}
	} else if c.RowID > 0 {
		// A database recreated (or emptied, or renumbered) at the same path numbers its rows from 1
		// again: past the old watermark its first rows would never be read. When the row at the
		// watermark is gone or is another request, start over. A cursor saved without an anchor
		// (by an earlier build) cannot be matched to this database and is read again once too.
		at, start, err := anchorOf(db, anchor, c.RowID)
		if err != nil {
			return false
		}
		// No anchor is kept for a row from before the tool's clear (see below). While that row is
		// still there and still from before the clear, the reads go on past it: going back to row
		// zero would only skip the same pre-clear rows again, and with a full batch of them would
		// never get past them.
		keep := c.Anchor == "" && at != "" && beforeClear(start, cleared)
		if keep {
			skip = c.RowID
		}
		if !keep && (at == "" || c.Anchor == "" || at != c.Anchor) {
			// Every request counted so far started no later than Mark, so the re-read counts only
			// rows that started after it (or were still running): nothing counts twice, however
			// many ids Seen has dropped.
			c.ResetRow, c.ResetMark = max(c.ResetRow, c.RowID), max(c.ResetMark, c.Mark)
			c.ResetPending = append(c.ResetPending, c.Pending...)
			if len(c.ResetPending) > maxPending {
				c.ResetPending = c.ResetPending[len(c.ResetPending)-maxPending:]
			}
			c.RowID, c.Pending = 0, nil
		}
	}
	// An old request at the skipped row proves neither that the rows below it are old nor that this
	// is the database that was cleared: a replacement can number a post-clear request lower. One
	// count of the rows up to the skipped one that started at or after the clear: none (the usual
	// case) and they stay skipped, without a re-read; otherwise exactly those rows are read too.
	// Rows from before the clear still record nothing (below). A row whose start is missing or not
	// a number counts as 0, so as from before the clear, and is not read.
	var below []dbRow
	if skip > 0 && cleared > 0 {
		var n int64
		if err := db.QueryRow("SELECT COUNT(*) "+postClear, skip, cleared).Scan(&n); err != nil {
			return false
		}
		if n > 0 {
			ids, err := rowIDs(db, "SELECT rowid "+postClear+" ORDER BY rowid LIMIT "+itoa64(dbBatch), skip, cleared)
			if err != nil {
				return false
			}
			if below, err = read(db, math.MaxInt64, ids); err != nil {
				return false
			}
		}
	}
	rows, err := read(db, c.RowID, c.Pending)
	if err != nil {
		return false
	}
	more := len(rows) >= dbBatch
	for _, r := range below {
		if !slices.ContainsFunc(rows, func(x dbRow) bool { return x.rowid == r.rowid }) {
			rows = append(rows, r)
		}
	}
	if c.Seen == nil {
		c.Seen = map[string]int64{}
	}
	sort.Slice(rows, func(i, j int) bool { return rows[i].rowid < rows[j].rowid })
	since := l.Since.UnixMilli()
	look := dbLookback.Milliseconds()
	var pending []int64
	liveSeen := map[string]bool{}
	for _, r := range rows {
		if r.rowid > c.RowID {
			c.RowID = r.rowid
		}
		if r.start <= 0 {
			continue
		}
		if r.start < cleared {
			// From before the tool's history was cleared: only the row position moves on. No id
			// hash, start or mark is kept, so the clear's erasure of them holds.
			continue
		}
		if r.rowid <= c.ResetRow && r.start <= c.ResetMark && !slices.Contains(c.ResetPending, r.rowid) {
			continue // counted, or skipped, before the reset
		}
		if c.Mark > 0 && r.start < c.Mark-look {
			continue // history copied into a new row
		}
		id := hashID(r.key)
		_, already := c.Seen[id]
		if !already && !liveSeen[id] {
			l.liveDB(source, r, now)
		}
		liveSeen[id] = true
		if r.end <= 0 {
			if len(pending) < maxPending && now.UnixMilli()-r.start < look {
				pending = append(pending, r.rowid)
			}
			continue
		}
		if r.start < since {
			c.Seen[id] = r.start
			if r.start > c.Mark {
				c.Mark = r.start
			}
			continue
		}
		if _, done := c.Seen[id]; done {
			continue
		}
		c.Seen[id] = r.start
		if r.start > c.Mark {
			c.Mark = r.start
		}
		l.addDBRow(source, parser, r)
	}
	for id, at := range c.Seen {
		if at < c.Mark-look || len(c.Seen) > maxSeenRows {
			delete(c.Seen, id)
		}
	}
	if c.RowID >= c.ResetRow && !more {
		c.ResetRow, c.ResetMark, c.ResetPending = 0, 0, nil // the re-read is complete
	}
	c.Anchor = ""
	// The anchor is the identity of the request at the watermark. One from before the tool's clear
	// is not kept: the clear erased it. Until a post-clear request is at the watermark, the reads go
	// on from the row number alone (above); the first post-clear request then becomes the anchor.
	if c.RowID > 0 {
		if at, start, err := anchorOf(db, anchor, c.RowID); err == nil && !beforeClear(start, cleared) {
			c.Anchor = at
		}
	}
	c.Pending, c.Sig, c.Day, c.Checked, c.More = pending, sig, day(now), now.UTC().Truncate(time.Second), more
	l.Stores[key] = c
	return true
}

// addDBRow: one finished request as a one-request turn. Its time is end to end (the request's
// start to its end, the wait for the first token included), so it is never an eligible
// generation sample; tokens, days, sessions and projects count as for the logs.
func (l *PerfLedger) addDBRow(source, parser string, r dbRow) {
	at, end := time.UnixMilli(r.start), time.UnixMilli(r.end)
	cfg := config{model: clip(r.model)}
	q := request{TokenKinds: r.TokenKinds, out: max(r.out, 0), cfg: cfg, end: end}
	t := turn{cfg: cfg, at: at, dur: max(end.Sub(at), 0), out: q.out, all: []request{q}, cwd: r.cwd}
	l.add(source, parser, t)
	if r.session != "" {
		l.addSession(fileKey(source+":"+r.session), source, t)
	}
}

// dataHome: $XDG_DATA_HOME, else ~/.local/share (OpenCode uses it on macOS too).
func dataHome(home string) string {
	if d := os.Getenv("XDG_DATA_HOME"); d != "" && filepath.IsAbs(d) {
		return d
	}
	return filepath.Join(home, ".local", "share")
}

// envPath: an absolute path from the environment, "" otherwise.
func envPath(k string) string {
	if p := os.Getenv(k); p != "" && filepath.IsAbs(p) {
		return p
	}
	return ""
}

func itoa64(v int64) string { return strconv.FormatInt(v, 10) }

func (l *PerfLedger) liveDB(source string, r dbRow, now time.Time) {
	if r.session == "" {
		return
	}
	at := time.UnixMilli(r.start)
	last := at
	if r.end > 0 {
		last = time.UnixMilli(r.end)
	}
	cfg := config{model: clip(r.model)}
	q := request{TokenKinds: r.TokenKinds, out: max(r.out, 0), cfg: cfg, end: last}
	var qs []request
	if r.end > 0 {
		qs = []request{q}
	}
	l.setLive(fileKey(source+":"+r.session), source, liveProbe{cfg: cfg, start: at, last: last, running: r.end <= 0, requests: qs, cwd: r.cwd}, "", now)
}
func nullCount(n sql.NullInt64) *int64 {
	if !n.Valid || n.Int64 < 0 {
		return nil
	}
	x := n.Int64
	return &x
}
