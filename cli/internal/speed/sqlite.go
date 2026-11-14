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
	// When the reads passed over rows at a clear (the row at RowID is from before it), the
	// post-clear rows up to RowID are read apart, in row order. Unread: some are still unread, from
	// past row Below on, and the reads past RowID wait. Eligible: how many post-clear rows up to
	// RowID there were once all were read; a different count means the rows changed. Row numbers
	// and a count only: nothing identifies a row.
	Unread   bool  `json:"unread,omitempty"`
	Below    int64 `json:"below,omitempty"`
	Eligible int64 `json:"eligible,omitempty"`
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

// anchorOf: the hashed identity of the row with this rowid, "" when there is none.
func anchorOf(db *sql.DB, query string, rowid int64) (string, error) {
	var id string
	switch err := db.QueryRow(query, rowid).Scan(&id); {
	case errors.Is(err, sql.ErrNoRows):
		return "", nil
	case err != nil:
		return "", err
	}
	return hashID("anchor:" + id), nil
}

// preClear: whether the row with this rowid counts as from before the tool's clear (cleared, unix
// ms; 0: none). It is the one test of that for a row by number, made with the same clause
// (postClear) as the count and read of post-clear rows below a skipped row: a row is post-clear
// only when that clause selects it, so a missing or non-numeric start (read as 0) is pre-clear,
// and so is a missing row.
func preClear(db *sql.DB, postClear string, rowid, cleared int64) (bool, error) {
	if cleared <= 0 {
		return false, nil
	}
	n, err := countPostClear(db, postClear+" AND rowid >= ?", rowid, cleared, rowid)
	return n == 0, err
}

// countPostClear: how many rows a postClear clause (with any extra condition) selects.
func countPostClear(db *sql.DB, clause string, args ...any) (int64, error) {
	var n int64
	err := db.QueryRow("SELECT COUNT(*) "+clause, args...).Scan(&n)
	return n, err
}

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
// that started at or after a time (second parameter, unix ms): see preClear and below.
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
	// atClear: the row at RowID is from before the tool's clear, so the reads went on past it and
	// the rows below it without reading them; the post-clear rows among those are read apart below.
	atClear := false
	if _, had := l.Stores[key]; !had {
		// The tool's history was cleared through row N of its database: read on past it, so the
		// rows from before the clear are not read again. When this database's row N is missing
		// or is post-clear, it is not the database that was cleared (replaced since): it is read
		// from the start, and the clear time keeps its earlier requests out.
		if n := l.cleared.dbRows(source); n > 0 {
			if at, err := anchorOf(db, anchor, n); err == nil && at != "" {
				if pre, err := preClear(db, postClear, n, cleared); err == nil && pre {
					c.RowID, atClear = n, true
				}
			}
		}
	} else if c.RowID > 0 {
		// A database recreated (or emptied, or renumbered) at the same path numbers its rows from 1
		// again: past the old watermark its first rows would never be read. When the row at the
		// watermark is gone or is another request, start over. A cursor saved without an anchor
		// (by an earlier build) cannot be matched to this database and is read again once too.
		at, err := anchorOf(db, anchor, c.RowID)
		if err != nil {
			return false
		}
		// No anchor is kept for a row from before the tool's clear (see below). While that row is
		// still there and still from before the clear, the reads go on past it: going back to row
		// zero would only skip the same pre-clear rows again, and with a full batch of them would
		// never get past them.
		if c.Anchor == "" && at != "" {
			if atClear, err = preClear(db, postClear, c.RowID, cleared); err != nil {
				return false
			}
		}
		if !atClear && (at == "" || c.Anchor == "" || at != c.Anchor) {
			// Every request counted so far started no later than Mark, so the re-read counts only
			// rows that started after it (or were still running): nothing counts twice, however
			// many ids Seen has dropped. While post-clear rows below RowID were still unread, the
			// rows read reach only Below (the reads past RowID waited for them).
			upTo := c.RowID
			if c.Unread {
				upTo = c.Below
			}
			c.ResetRow, c.ResetMark = max(c.ResetRow, upTo), max(c.ResetMark, c.Mark)
			c.ResetPending = append(c.ResetPending, c.Pending...)
			if len(c.ResetPending) > maxPending {
				c.ResetPending = c.ResetPending[len(c.ResetPending)-maxPending:]
			}
			c.RowID, c.Pending, c.Unread, c.Below = 0, nil, false, 0
		}
	}
	// The row at a clear's watermark being from before the clear proves neither that the rows below
	// it are old nor that this is the database that was cleared: a replacement can number a
	// post-clear request lower. So, at such a row, the rows up to it are counted by the one
	// eligibility clause (postClear, the same test as preClear) and only those are read, never a
	// pre-clear one. They are read once, in row order, a batch per scan: Below is how far, and the
	// reads past RowID wait until all are read (More meanwhile), so the two reads never overlap.
	// Once all are read, Eligible keeps their count; a later scan that counts a different number
	// (the database was replaced again under the same pre-clear row) reads them again from the
	// start, and requests already counted are known by Seen.
	var below []dbRow
	held := false
	if atClear {
		if !c.Unread {
			n, err := countPostClear(db, postClear, c.RowID, cleared)
			if err != nil {
				return false
			}
			if n != c.Eligible {
				c.Unread, c.Below = true, 0
			}
		}
		if c.Unread {
			ids, err := rowIDs(db, "SELECT rowid "+postClear+" AND rowid > ? ORDER BY rowid LIMIT "+itoa64(dbBatch), c.RowID, cleared, c.Below)
			if err != nil {
				return false
			}
			if below, err = read(db, math.MaxInt64, ids); err != nil {
				return false
			}
			if held = len(ids) >= dbBatch; held {
				c.Below = ids[len(ids)-1]
			} else {
				c.Unread, c.Below = false, 0
			}
		}
	}
	var rows []dbRow
	more := held
	if held {
		// Only the requests still running last time are read again, beside the batch below RowID.
		if len(c.Pending) > 0 {
			if rows, err = read(db, math.MaxInt64, c.Pending); err != nil {
				return false
			}
		}
	} else {
		if rows, err = read(db, c.RowID, c.Pending); err != nil {
			return false
		}
		more = len(rows) >= dbBatch
	}
	inRows := make(map[int64]bool, len(rows))
	for _, r := range rows {
		inRows[r.rowid] = true
	}
	for _, r := range below {
		if !inRows[r.rowid] {
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
		if r.start <= 0 || r.start < cleared {
			// No readable start, or from before the tool's history was cleared: only the row
			// position moves on. No id hash, start or mark is kept, so the clear's erasure holds.
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
	// The anchor is the identity of the request at the watermark. One that counts as from before
	// the tool's clear (preClear: also one without a readable start) is not kept: the clear erased
	// it. Until a post-clear request is at the watermark, the reads go on from the row number alone
	// (above), with Eligible, a count, to notice a change below it; the first post-clear request
	// then becomes the anchor.
	c.Anchor, c.Eligible = "", 0
	if c.RowID > 0 {
		at, err := anchorOf(db, anchor, c.RowID)
		pre, perr := preClear(db, postClear, c.RowID, cleared)
		switch {
		case err != nil || perr != nil || at == "":
		case !pre:
			c.Anchor = at
		case !c.Unread:
			if c.Eligible, err = countPostClear(db, postClear, c.RowID, cleared); err != nil {
				c.Eligible = -1 // unknown: the next scan reads the post-clear rows below again
			}
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
