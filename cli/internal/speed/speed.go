// Package speed measures, on this machine only, how fast the user's own requests and turns run
// under each configuration (model, effort, speed mode): output tokens per second of generation,
// the time to the first token, and the time and output tokens of a whole turn. It reads only
// timestamps, token counts, model, effort and speed mode from the harness's own session logs (the
// current Claude Code session's transcript, Codex rollouts), never prompts, replies, tool input or
// output, paths or ids, and nothing leaves the machine.
//
// The ledger is <cache>/observed/speed.json: one row per local day and configuration, with sums
// and histograms only. The performance ledger, perf.json (perf.go), is read from the same logs
// beside it. MODELPLAN_HISTORY=off stops both, as it stops the quota history; deleting a file
// clears it.
package speed

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"time"
)

// Ledger is the file's content.
type Ledger struct {
	SchemaVersion int               `json:"schemaVersion"`
	Rows          []Row             `json:"rows"`
	Files         map[string]Cursor `json:"files,omitempty"` // by a hash of the log's path
}

// Row is one local day of one configuration.
type Row struct {
	Day    string `json:"day"`              // local date, YYYY-MM-DD
	Source string `json:"source"`           // claude-code | codex
	Model  string `json:"model"`            // as the harness reports it
	Effort string `json:"effort,omitempty"` // "" = the harness default
	Speed  string `json:"speed,omitempty"`  // "" = standard; fast, …
	// Requests whose first token is known: their output tokens and generation time (first token to
	// the last output), the basis of tokens per second.
	Requests     int   `json:"requests"`
	OutputTokens int64 `json:"outputTokens"`
	GenMs        int64 `json:"genMs"`
	TTFTMs       Hist  `json:"ttftMs,omitempty"` // from the request (prompt or tool result) to the first token
	// Turns: from the user's prompt to the turn's last output, tools included.
	Turns      int  `json:"turns"`
	TurnMs     Hist `json:"turnMs,omitempty"`
	TurnTokens Hist `json:"turnTokens,omitempty"` // output tokens per turn
}

// Cursor is how far a log has been read: up to the end of its last finished turn.
type Cursor struct {
	Offset     int64    `json:"offset"`
	Seen       string   `json:"seen"` // local date of the last read
	CodexTotal *cxUsage `json:"codexTotal,omitempty"`
	Skip       bool     `json:"skip,omitempty"` // a thread Codex runs by itself
}

// A sample is either one request or one finished turn of one configuration.
type config struct{ model, effort, speed string }

type request struct {
	out                          int64
	input, cacheRead, cacheWrite *int64
	key                          string        // local deduplication key; never a harness id
	gen, ttft                    time.Duration // 0 when unknown
	cfg                          config        // Claude Code: the request's own; Codex: the turn's
	end                          time.Time     // when its last output was logged
}

type turn struct {
	cfg  config
	at   time.Time
	dur  time.Duration
	out  int64
	reqs []request // the requests under cfg
	// all: every request of the turn under its own configuration; mixed: they were not all under
	// cfg (Claude Code can change model within a turn).
	all   []request
	mixed bool
	cwd   string // the working directory its log records, "" when none
}

const (
	Keep       = 28 * 24 * time.Hour
	maxRows    = 3000
	maxFile    = 2 << 20
	maxScan    = 8 << 20 // bytes read from one log per run
	maxLine    = 4 << 20 // longer lines (huge tool output) are skipped unread
	lockStale  = 10 * time.Second
	statusGap  = 15 * time.Second // the status line refreshes often; read at most this often from it
	MinSamples = 5                // fewer requests or turns than this give no median or rate
)

// Valid samples, as the usual practice for local logs: a request with fewer output tokens, a
// shorter or longer generation, or a faster rate than these says more about the clock than the model.
const (
	minOutput  = 20
	minGen     = 200 * time.Millisecond
	maxGen     = 30 * time.Minute
	maxRate    = 3000.0
	maxTTFT    = 2 * time.Minute
	maxTurn    = 6 * time.Hour
	histFactor = 1.1 // histogram buckets 10% wide
)

// Path is the ledger file.
func Path(cache string) string { return filepath.Join(cache, "observed", "speed.json") }

// Off: the user turned local recording off.
func Off() bool { return os.Getenv("MODELPLAN_HISTORY") == "off" }

// Load never fails: a missing or unreadable ledger is empty.
func Load(cache string) Ledger {
	l := Ledger{SchemaVersion: 1}
	b, err := os.ReadFile(Path(cache))
	if err != nil || len(b) > maxFile {
		return l
	}
	var on Ledger
	if json.Unmarshal(b, &on) == nil && on.SchemaVersion == 1 {
		l.Rows, l.Files = on.Rows, on.Files
	}
	return l
}

// ObserveClaude reads what is new in the current Claude Code session's transcript, into both
// ledgers. From the status line (often=true) it reads at most every statusGap.
func ObserveClaude(cache, transcript string, often bool, in Ingest, now time.Time) error {
	if transcript == "" || !filepath.IsAbs(transcript) {
		return nil
	}
	if often {
		if fi, err := os.Stat(Path(cache)); err == nil && now.Sub(fi.ModTime()) < statusGap && fi.ModTime().Before(now.Add(time.Minute)) {
			return nil
		}
	}
	err := observe(cache, now, func(l *Ledger) bool { return l.scan(transcript, "claude-code", newClaude(now), now) })
	return errors.Join(err, observePerf(cache, now, in, func(l *PerfLedger) bool {
		return l.scanClaudeFamily(transcript, now)
	}))
}

// ObserveCodex reads what is new in the most recent Codex rollouts, into both ledgers.
func ObserveCodex(cache string, rollouts []string, background func(string) bool, in Ingest, now time.Time) error {
	if len(rollouts) == 0 {
		return nil
	}
	err := observe(cache, now, func(l *Ledger) bool {
		return scanCodex(l.Files, rollouts, background, now, func(p string) bool { return l.scan(p, "codex", newCodex(), now) })
	})
	return errors.Join(err, observePerf(cache, now, in, func(l *PerfLedger) bool {
		changed := false
		for _, path := range rollouts {
			p := newCodex()
			p.liveOnly = background(path)
			changed = l.scan(path, "codex", ParserCodex, p, now) || changed
		}
		return changed
	}))
}

// scanCodex scans the rollouts with their cursors in files, marking the threads Codex runs by
// itself to skip.
func scanCodex(files map[string]Cursor, rollouts []string, background func(string) bool, now time.Time, scan func(string) bool) bool {
	changed := false
	for _, p := range rollouts {
		key := fileKey(p)
		c, seen := files[key]
		if !seen && background(p) {
			files[key] = Cursor{Seen: day(now), Skip: true}
			changed = true
			continue
		}
		if c.Skip {
			continue
		}
		changed = scan(p) || changed
	}
	return changed
}

func observe(cache string, now time.Time, f func(*Ledger) bool) error {
	if Off() {
		return nil
	}
	unlock, ok := lock(cache, "speed.lock")
	if !ok {
		return nil // another process is reading; the next run picks up the same lines
	}
	defer unlock()
	l := Load(cache)
	if l.Files == nil {
		l.Files = map[string]Cursor{}
	}
	if !f(&l) {
		return nil
	}
	l.prune(now)
	b, _ := json.Marshal(l)
	return write(Path(cache), append(b, '\n'))
}

// A parser sees each complete line with its offset, buffers a turn until it is finished and returns
// the offset to read from next time: past the last finished turn.
type parser interface {
	line(off, end int64, b []byte)
	finish() (done []turn, commit int64)
}

// scan reads one log from its cursor into the ledger.
func (l *Ledger) scan(path, source string, p parser, now time.Time) bool {
	done, changed := scanLog(l.Files, path, p, now)
	for _, t := range done {
		l.add(source, t)
	}
	return changed
}

// scanLog reads one log from its cursor in files and returns its finished turns. A log seen for
// the first time is read from its last maxScan bytes; a log that shrank (rewritten) starts over.
func scanLog(files map[string]Cursor, path string, p parser, now time.Time) ([]turn, bool) {
	fh, err := os.Open(path)
	if err != nil {
		return nil, false
	}
	defer fh.Close()
	fi, err := fh.Stat()
	if err != nil || !fi.Mode().IsRegular() {
		return nil, false
	}
	key := fileKey(path)
	c, seen := files[key]
	start, partial := c.Offset, false
	if !seen && fi.Size() > maxScan {
		start, partial = fi.Size()-maxScan, true
	}
	if start > fi.Size() {
		start = 0
	}
	if seen && start == fi.Size() {
		if c.Seen != day(now) {
			c.Seen = day(now)
			files[key] = c
			return nil, true
		}
		return nil, false
	}
	if _, err := fh.Seek(start, io.SeekStart); err != nil {
		return nil, false
	}
	r := bufio.NewReaderSize(io.LimitReader(fh, maxScan), 256<<10)
	off := start
	if partial { // starting inside a line: skip to the next one
		_, n, err := readLine(r)
		if err != nil {
			return nil, false
		}
		off += n
	}
	last := off
	for {
		b, n, err := readLine(r)
		if err != nil {
			break // EOF, or an unfinished last line: it is read again next time
		}
		if b != nil {
			p.line(off, off+n, b)
		}
		off += n
		last = off
	}
	done, commit := p.finish()
	if commit < 0 {
		commit = last
	}
	// A turn (or a line) longer than a whole read never finishes inside one: give up on it.
	if commit <= start && fi.Size()-start >= maxScan {
		commit = last
		if last == start {
			commit = start + maxScan
		}
	}
	files[key] = Cursor{Offset: commit, Seen: day(now)}
	return done, true
}

// readLine reads one line through its newline and returns its length, with its bytes unless it is
// longer than maxLine; an unfinished last line is an error.
func readLine(r *bufio.Reader) ([]byte, int64, error) {
	var buf []byte
	var n int64
	for {
		chunk, err := r.ReadSlice('\n')
		n += int64(len(chunk))
		if n <= maxLine {
			buf = append(buf, chunk...)
		} else {
			buf = nil
		}
		switch err {
		case nil:
			return buf, n, nil
		case bufio.ErrBufferFull:
			continue
		default:
			return nil, n, err
		}
	}
}

func (l *Ledger) add(source string, t turn) {
	if t.cfg.model == "" || t.at.IsZero() {
		return
	}
	r := l.row(day(t.at), source, t.cfg)
	for _, q := range t.reqs {
		if q.ttft > 0 && q.ttft <= maxTTFT {
			r.TTFTMs = r.TTFTMs.add(float64(q.ttft.Milliseconds()))
		}
		if !q.eligible() {
			continue
		}
		r.Requests++
		r.OutputTokens += q.out
		r.GenMs += q.gen.Milliseconds()
	}
	if t.dur > 0 && t.dur <= maxTurn && len(t.reqs) > 0 {
		r.Turns++
		r.TurnMs = r.TurnMs.add(float64(t.dur.Milliseconds()))
		r.TurnTokens = r.TurnTokens.add(float64(t.out))
	}
}

// eligible: a valid sample of generation speed (first token known, enough output, a plausible
// generation time and rate).
func (q request) eligible() bool {
	return q.out >= minOutput && q.gen >= minGen && q.gen <= maxGen && float64(q.out)/q.gen.Seconds() <= maxRate
}

func (l *Ledger) row(d, source string, c config) *Row {
	for i := range l.Rows {
		r := &l.Rows[i]
		if r.Day == d && r.Source == source && r.Model == c.model && r.Effort == c.effort && r.Speed == c.speed {
			return r
		}
	}
	l.Rows = append(l.Rows, Row{Day: d, Source: source, Model: c.model, Effort: c.effort, Speed: c.speed})
	return &l.Rows[len(l.Rows)-1]
}

func (l *Ledger) prune(now time.Time) {
	from := day(now.Add(-Keep))
	kept := l.Rows[:0]
	for _, r := range l.Rows {
		if r.Day >= from {
			kept = append(kept, r)
		}
	}
	sort.SliceStable(kept, func(i, j int) bool { return kept[i].Day < kept[j].Day })
	if len(kept) > maxRows {
		kept = kept[len(kept)-maxRows:]
	}
	l.Rows = kept
	for k, c := range l.Files {
		if c.Seen < from {
			delete(l.Files, k)
		}
	}
}

func day(t time.Time) string { return t.Local().Format("2006-01-02") }

// fileKey: the cursor's key, so the ledger holds no paths.
func fileKey(p string) string {
	h := sha256.Sum256([]byte(p))
	return hex.EncodeToString(h[:8])
}

// Hist counts values in buckets histFactor wide (bucket k holds [1.1^k, 1.1^(k+1))), so days and
// configurations merge by adding counts and a median is within 5%.
type Hist map[string]int

func (h Hist) add(v float64) Hist {
	if h == nil {
		h = Hist{}
	}
	k := 0
	if v > 1 {
		k = int(math.Floor(math.Log(v) / math.Log(histFactor)))
	}
	h[strconv.Itoa(k)]++
	return h
}

func (h Hist) merge(o Hist) Hist {
	for k, n := range o {
		if h == nil {
			h = Hist{}
		}
		h[k] += n
	}
	return h
}

// Count is the number of values.
func (h Hist) Count() int {
	n := 0
	for _, c := range h {
		n += c
	}
	return n
}

// Median: the middle bucket's geometric centre.
func (h Hist) Median() float64 {
	n := h.Count()
	if n == 0 {
		return 0
	}
	ks := make([]int, 0, len(h))
	for k := range h {
		if i, err := strconv.Atoi(k); err == nil {
			ks = append(ks, i)
		}
	}
	sort.Ints(ks)
	seen := 0
	for _, k := range ks {
		seen += h[strconv.Itoa(k)]
		if 2*seen >= n {
			return math.Pow(histFactor, float64(k)+0.5)
		}
	}
	return 0
}

func lock(cache, name string) (func(), bool) {
	p := filepath.Join(cache, "observed", name)
	if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
		return nil, false
	}
	if fi, err := os.Stat(p); err == nil && time.Since(fi.ModTime()) > lockStale {
		_ = os.Remove(p) // left behind by a killed process
	}
	f, err := os.OpenFile(p, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		return nil, false
	}
	f.Close()
	return func() { _ = os.Remove(p) }, true
}

func write(p string, b []byte) error {
	f, err := os.CreateTemp(filepath.Dir(p), ".speed-*")
	if err != nil {
		return err
	}
	_, err = f.Write(b)
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err == nil {
		err = os.Chmod(f.Name(), 0o600)
	}
	if err == nil {
		err = os.Rename(f.Name(), p)
	}
	if err != nil {
		os.Remove(f.Name())
	}
	return err
}
