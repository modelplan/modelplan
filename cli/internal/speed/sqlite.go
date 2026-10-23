package speed

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"net/url"
	"os"
	"path/filepath"
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
	More    bool             `json:"more,omitempty"` // the last read stopped at dbBatch rows
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
	cwd        string
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

func hashID(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:8])
}

// scanDB reads what is new in one database with read (rows past a rowid, plus listed rowids) and
// adds the finished requests to the ledger under source.
func (l *PerfLedger) scanDB(path, source, parser string, now time.Time, read func(db *sql.DB, after int64, pending []int64) ([]dbRow, error)) bool {
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
	rows, err := read(db, c.RowID, c.Pending)
	if err != nil {
		return false
	}
	if c.Seen == nil {
		c.Seen = map[string]int64{}
	}
	sort.Slice(rows, func(i, j int) bool { return rows[i].rowid < rows[j].rowid })
	since := l.Since.UnixMilli()
	look := dbLookback.Milliseconds()
	var pending []int64
	for _, r := range rows {
		if r.rowid > c.RowID {
			c.RowID = r.rowid
		}
		if r.start <= 0 || r.start < since {
			continue
		}
		if c.Mark > 0 && r.start < c.Mark-look {
			continue // history copied into a new row
		}
		cfg := config{model: clip(r.model)}
		end := time.UnixMilli(r.end)
		if r.end <= 0 {
			end = time.UnixMilli(r.start)
		}
		q := request{out: max(r.out, 0), cfg: cfg, end: end, key: hashID(r.key)}
		if r.session != "" {
			l.signal(fileKey(source+":"+r.session), source, sessionSignal{start: time.UnixMilli(r.start), last: end, cfg: cfg, running: r.end <= 0, cwd: r.cwd, reqs: completedDBRequest(r.end, q)}, now)
		}
		if r.end <= 0 {
			if len(pending) < maxPending && now.UnixMilli()-r.start < look {
				pending = append(pending, r.rowid)
			}
			continue
		}
		id := hashID(r.key)
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
	c.Pending, c.Sig, c.Day, c.Checked, c.More = pending, sig, day(now), now.UTC().Truncate(time.Second), len(rows) >= dbBatch
	l.Stores[key] = c
	return true
}

// addDBRow: one finished request as a one-request turn. Its time is end to end (the request's
// start to its end, the wait for the first token included), so it is never an eligible
// generation sample; tokens, days, sessions and projects count as for the logs.
func (l *PerfLedger) addDBRow(source, parser string, r dbRow) {
	at, end := time.UnixMilli(r.start), time.UnixMilli(r.end)
	cfg := config{model: clip(r.model)}
	q := request{out: max(r.out, 0), cfg: cfg, end: end}
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

func completedDBRequest(end int64, q request) []request {
	if end <= 0 {
		return nil
	}
	return []request{q}
}
