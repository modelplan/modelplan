// SPDX-License-Identifier: MIT
package speed

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// The history importer reads the Claude Code and Codex logs written before the live observers
// started, so charts and the effort suggestion are not empty on day one. It reads what the live
// parsers read (timestamps, token counts, model, effort, speed mode) and nothing else: never a
// prompt, reply, tool input or output, path, project or id. Its ledger is <cache>/observed/
// imported.json; every row in it carries origin "import" and a per-source coverage span. It is
// local only, read-only on the logs and stopped by MODELPLAN_HISTORY=off.
//
// Dedupe: a turn belongs to the span its start time falls in, and the importer never counts a turn
// outside the part of the timeline a source has not covered yet. It stops at the live ledger's
// start (perf.json since): live observers count turns that start at or after it, the importer the
// ones before, so a re-import, an import then live reads and live reads then an import never count
// a turn twice. Quota cycles are not reconstructed: logs hold no meter readings.

const (
	OriginImport      = "import"
	ImportDefaultDays = 30
	ImportMaxDays     = LongDays

	StatusImported    = "imported"
	StatusNoConsent   = "skipped_no_consent"
	StatusNothing     = "nothing_found"
	StatusOff         = "off"
	maxImportFiles    = 200000
	importCancelEvery = 512 // lines between cancel checks
)

// Span is the part of the timeline one source's imported rows cover: turns that started in
// [From, Through).
type Span struct {
	From    time.Time `json:"from"`
	Through time.Time `json:"through"`
	// Epoch: the grant the span was imported under. After a revoke and a new grant the span no
	// longer counts and the source is read again.
	Epoch *GrantEpoch `json:"epoch,omitempty"`
}

// ImportLedger is imported.json's content.
type ImportLedger struct {
	SchemaVersion int `json:"schemaVersion"`
	// AutoRan: when the first-run import ran (also when it skipped every source), so it is not
	// repeated; the Settings action stays available.
	AutoRan  *time.Time      `json:"autoRan,omitempty"`
	Coverage map[string]Span `json:"coverage,omitempty"`
	Rows     []PerfRow       `json:"rows"`
}

// ImportPath is the ledger file.
func ImportPath(cache string) string { return filepath.Join(cache, "observed", "imported.json") }

// LoadImported reads the ledger. A missing file is an empty ledger; ok is false when the file is
// there but unusable (unreadable, too large or another schema), and it is then left as it is.
func LoadImported(cache string) (l ImportLedger, ok bool) {
	b, err := os.ReadFile(ImportPath(cache))
	if errors.Is(err, os.ErrNotExist) {
		return ImportLedger{SchemaVersion: 1, Rows: []PerfRow{}}, true
	}
	if err != nil || len(b) > maxFile {
		return ImportLedger{}, false
	}
	if json.Unmarshal(b, &l) != nil || l.SchemaVersion != 1 {
		return ImportLedger{}, false
	}
	if l.Rows == nil {
		l.Rows = []PerfRow{}
	}
	return l, true
}

// NeedsAutoImport: the first-run import has not run yet and recording is on.
func NeedsAutoImport(cache string) bool {
	if Off() {
		return false
	}
	l, ok := LoadImported(cache)
	return ok && l.AutoRan == nil
}

// ImportRoot is one harness's home (Claude Code: ~/.claude or CLAUDE_CONFIG_DIR; Codex: its home).
// A nil root means the caller has no consent for that tool. Background names the Codex threads the
// harness runs by itself (skipped, as the live reader skips them); nil skips none.
type ImportRoot struct {
	Dir        string
	Background func(path string) bool
}

// ImportOptions: what to import and under which grants.
type ImportOptions struct {
	Days   int // 0 = ImportDefaultDays; capped at ImportMaxDays
	Claude *ImportRoot
	Codex  *ImportRoot
	Now    time.Time
	// Auto marks the run as the first-run import.
	Auto bool
	// Admission: the consent in force; nil reads the current one. A source without its history
	// grant is skipped.
	Admission *consent.Admission
	// Guard runs a source's write under the caller's consent fence (consent.LocalWrite); nil runs
	// it directly.
	Guard func(source string, write func() error) error
}

// SourceResult reports one source without any path or id.
type SourceResult struct {
	Source string `json:"source"`
	Status string `json:"status"`
	Turns  int    `json:"turns"`
}

// ImportResult: what a run did. A cancelled run wrote nothing.
type ImportResult struct {
	Days      int            `json:"days"`
	Cancelled bool           `json:"cancelled,omitempty"`
	Sources   []SourceResult `json:"sources"`
}

type span struct{ lo, hi time.Time }

func (s span) has(t time.Time) bool { return !t.Before(s.lo) && t.Before(s.hi) }

type importJob struct {
	source string
	root   *ImportRoot
	dir    string // under the root
	prefix string // file name prefix, "" for any
	newP   func() parser
	parser string
	ranges []span
	rows   []PerfRow
	turns  int
	status string
}

// Import reads the older logs of the sources the caller holds consent for and merges their turns
// into imported.json. Cancelling ctx before the read finishes leaves the ledger untouched.
func Import(ctx context.Context, cache string, o ImportOptions) (ImportResult, error) {
	days := o.Days
	if days <= 0 {
		days = ImportDefaultDays
	}
	if days > ImportMaxDays {
		days = ImportMaxDays
	}
	res := ImportResult{Days: days, Sources: []SourceResult{}}
	now := o.Now
	if now.IsZero() {
		now = time.Now()
	}
	adm := consent.Capture()
	if o.Admission != nil {
		adm = *o.Admission
	}
	jobs := []*importJob{
		{source: "claude-code", root: o.Claude, dir: "projects", newP: func() parser { return newClaude(now) }, parser: ParserClaude},
		{source: "codex", root: o.Codex, dir: "sessions", prefix: "rollout-", newP: func() parser { return newCodex() }, parser: ParserCodex},
	}
	if Off() {
		for _, j := range jobs {
			res.Sources = append(res.Sources, SourceResult{Source: j.source, Status: StatusOff})
		}
		return res, nil
	}
	led, ok := LoadImported(cache)
	if !ok {
		return res, errors.New("imported history unreadable; left as it is")
	}
	// The live ledger starts at its own since: the importer stops there.
	cutoff := now
	if p, ok := LoadPerf(cache); ok && !p.Since.IsZero() && p.Since.Before(cutoff) {
		cutoff = p.Since
	}
	from := dayStart(now.AddDate(0, 0, -days))
	var active []*importJob
	for _, j := range jobs {
		if j.root == nil || j.root.Dir == "" || currentEpoch(adm, j.source) == nil {
			j.status = StatusNoConsent
			continue
		}
		c := led.Coverage[j.source]
		if !sameEpoch(c.Epoch, currentEpoch(adm, j.source)) {
			c = Span{}
		}
		j.ranges = missing(c, from, cutoff)
		active = append(active, j)
	}
	// One pass per source: files that may hold turns of a missing range.
	for _, j := range active {
		if len(j.ranges) == 0 {
			j.status = StatusImported
			continue
		}
		if err := j.read(ctx); err != nil {
			if ctx.Err() != nil {
				res.Cancelled = true
				return res, nil
			}
			return res, err
		}
	}
	for _, j := range jobs {
		if j.status == "" {
			j.status = StatusImported
			if j.turns == 0 && len(j.ranges) > 0 {
				j.status = StatusNothing
			}
		}
		res.Sources = append(res.Sources, SourceResult{Source: j.source, Status: j.status, Turns: j.turns})
	}
	// Commit, source by source, each under its own consent fence.
	committed := false
	for _, j := range active {
		j := j
		write := func() error { return commitImport(cache, j, o.Auto, now, adm, &committed) }
		var err error
		if o.Guard != nil {
			err = o.Guard(consentTool(j.source), write)
		} else {
			err = write()
		}
		if err != nil {
			return res, err
		}
	}
	if !committed && o.Auto {
		return res, markAutoRan(cache, now)
	}
	return res, nil
}

func consentTool(source string) string {
	if source == "claude-code" {
		return "claude"
	}
	return source
}

// missing: the parts of [from, cutoff) a source has not covered. Spans stay contiguous.
func missing(c Span, from, cutoff time.Time) []span {
	if !from.Before(cutoff) {
		return nil
	}
	if c.From.IsZero() {
		return []span{{from, cutoff}}
	}
	var out []span
	if from.Before(c.From) {
		out = append(out, span{from, c.From})
	}
	if cutoff.After(c.Through) {
		out = append(out, span{c.Through, cutoff})
	}
	return out
}

func (j *importJob) read(ctx context.Context) error {
	earliest := j.ranges[0].lo
	for _, r := range j.ranges {
		if r.lo.Before(earliest) {
			earliest = r.lo
		}
	}
	tmp := &PerfLedger{}
	for _, p := range j.files(earliest) {
		if err := ctx.Err(); err != nil {
			return err
		}
		if j.root.Background != nil && j.source == "codex" && j.root.Background(p) {
			continue
		}
		turns, err := readWhole(ctx, p, j.newP())
		if err != nil {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			continue // unreadable file: skipped
		}
		for _, t := range turns {
			if t.at.IsZero() || !j.inRange(t.at) {
				continue
			}
			tmp.addTurn(j.source, j.parser, t, false)
			j.turns++
		}
	}
	for _, r := range tmp.Rows {
		r.Origin = OriginImport
		j.rows = append(j.rows, r)
	}
	return nil
}

func (j *importJob) inRange(t time.Time) bool {
	for _, r := range j.ranges {
		if r.has(t) {
			return true
		}
	}
	return false
}

// files lists the source's logs modified since `since`, in a stable order. Links, directories and
// the harness's sub-agent folders are not followed.
func (j *importJob) files(since time.Time) []string {
	root := filepath.Join(j.root.Dir, j.dir)
	if !filepath.IsAbs(root) {
		return nil
	}
	var out []string
	visited := 0
	_ = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if visited++; visited > maxImportFiles {
			return fs.SkipAll
		}
		if err != nil {
			return nil
		}
		if d.IsDir() {
			if d.Name() == "subagents" {
				return fs.SkipDir
			}
			return nil
		}
		if d.Type()&os.ModeSymlink != 0 || !strings.HasSuffix(path, ".jsonl") || !strings.HasPrefix(d.Name(), j.prefix) {
			return nil
		}
		if fi, e := d.Info(); e != nil || !fi.Mode().IsRegular() || fi.ModTime().Before(since) {
			return nil
		}
		out = append(out, path)
		return nil
	})
	sort.Strings(out)
	return out
}

// readWhole streams one log line by line through a parser and returns its finished turns. A line
// that is too long or does not parse is skipped by the parser; an unfinished last turn is dropped.
func readWhole(ctx context.Context, path string, p parser) ([]turn, error) {
	fh, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer fh.Close()
	if fi, err := fh.Stat(); err != nil || !fi.Mode().IsRegular() {
		return nil, errors.New("not a regular file")
	}
	r := bufio.NewReaderSize(fh, 256<<10)
	var off int64
	for n := 0; ; n++ {
		if n%importCancelEvery == 0 {
			if err := ctx.Err(); err != nil {
				return nil, err
			}
		}
		b, size, err := readLine(r)
		if err != nil {
			if errors.Is(err, io.EOF) || errors.Is(err, io.ErrUnexpectedEOF) {
				break
			}
			return nil, err
		}
		if b != nil {
			p.line(off, off+size, b)
		}
		off += size
	}
	done, _ := p.finish()
	return done, nil
}

// commitImport merges one source's rows and coverage into imported.json under perf.lock.
func commitImport(cache string, j *importJob, auto bool, now time.Time, adm consent.Admission, committed *bool) error {
	epoch := currentEpoch(adm, j.source) // re-checked inside the consent fence
	if epoch == nil {
		j.status = StatusNoConsent
		return nil
	}
	unlock, ok := lock(cache, "perf.lock")
	if !ok {
		return errors.New("readings busy; retry the import")
	}
	defer unlock()
	led, ok := LoadImported(cache)
	if !ok {
		return errors.New("imported history unreadable; left as it is")
	}
	if led.Coverage == nil {
		led.Coverage = map[string]Span{}
	}
	c := led.Coverage[j.source]
	if !sameEpoch(c.Epoch, epoch) { // an older grant's rows and span are not ours to extend
		kept := led.Rows[:0]
		for _, r := range led.Rows {
			if r.Source != j.source {
				kept = append(kept, r)
			}
		}
		led.Rows, c = kept, Span{}
	}
	for _, r := range j.rows {
		r.GrantEpoch = epoch
		led.merge(r)
	}
	for _, r := range j.ranges {
		if c.From.IsZero() {
			c = Span{From: r.lo, Through: r.hi}
			continue
		}
		if r.lo.Before(c.From) {
			c.From = r.lo
		}
		if r.hi.After(c.Through) {
			c.Through = r.hi
		}
	}
	c.Epoch = epoch
	led.Coverage[j.source] = c
	if auto && led.AutoRan == nil {
		t := now.UTC().Truncate(time.Second)
		led.AutoRan = &t
	}
	led.prune(now)
	*committed = true
	return writeImported(cache, led)
}

func markAutoRan(cache string, now time.Time) error {
	unlock, ok := lock(cache, "perf.lock")
	if !ok {
		return errors.New("readings busy; retry the import")
	}
	defer unlock()
	led, ok := LoadImported(cache)
	if !ok {
		return nil
	}
	if led.AutoRan == nil {
		t := now.UTC().Truncate(time.Second)
		led.AutoRan = &t
		return writeImported(cache, led)
	}
	return nil
}

func writeImported(cache string, led ImportLedger) error {
	if err := os.MkdirAll(filepath.Join(cache, "observed"), 0o700); err != nil {
		return err
	}
	b, err := json.Marshal(led)
	if err != nil {
		return err
	}
	return write(ImportPath(cache), append(b, '\n'))
}

// RemoveImported deletes exactly the imported rows and their coverage ("Remove imported history").
// The first-run marker stays so the import is not started again on its own.
func RemoveImported(cache string) error {
	unlock, ok := lock(cache, "perf.lock")
	if !ok {
		return errors.New("readings busy; retry")
	}
	defer unlock()
	led, ok := LoadImported(cache)
	if !ok {
		return os.Remove(ImportPath(cache))
	}
	if len(led.Rows) == 0 && len(led.Coverage) == 0 {
		return nil
	}
	if led.AutoRan == nil {
		if err := os.Remove(ImportPath(cache)); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
		return nil
	}
	return writeImported(cache, ImportLedger{SchemaVersion: 1, AutoRan: led.AutoRan, Rows: []PerfRow{}})
}

// merge adds a row's sums into the ledger's row of the same configuration.
func (l *ImportLedger) merge(r PerfRow) {
	for i := range l.Rows {
		x := &l.Rows[i]
		if x.Day == r.Day && x.Source == r.Source && x.Model == r.Model && x.EffortStatus == r.EffortStatus && x.Effort == r.Effort &&
			x.Speed == r.Speed && x.Parser == r.Parser && x.Eligibility == r.Eligibility && sameEpoch(x.GrantEpoch, r.GrantEpoch) {
			if r.ObservedRequests > 0 {
				x.TokenKinds.add(r.TokenKinds, x.ObservedRequests == 0)
			}
			x.ObservedRequests += r.ObservedRequests
			x.ObservedOutputTokens += r.ObservedOutputTokens
			x.EligibleRequests += r.EligibleRequests
			x.EligibleOutputTokens += r.EligibleOutputTokens
			x.GenMs += r.GenMs
			x.Turns += r.Turns
			x.TurnMs += r.TurnMs
			x.TurnOutputTokens += r.TurnOutputTokens
			x.MixedConfigTurnsExcluded += r.MixedConfigTurnsExcluded
			x.TTFTMs = x.TTFTMs.merge(r.TTFTMs)
			x.TurnMsHist = x.TurnMsHist.merge(r.TurnMsHist)
			x.TurnTokensHist = x.TurnTokensHist.merge(r.TurnTokensHist)
			if r.LastAt != nil && (x.LastAt == nil || r.LastAt.After(*x.LastAt)) {
				t := *r.LastAt
				x.LastAt = &t
			}
			return
		}
	}
	l.Rows = append(l.Rows, r)
}

// prune keeps ImportMaxDays local days, at most maxRows rows and less than maxFile bytes, dropping
// the oldest days first and moving each source's coverage start past what went.
func (l *ImportLedger) prune(now time.Time) {
	from := windowFrom(now, ImportMaxDays)
	kept := l.Rows[:0]
	droppedDay := ""
	for _, r := range l.Rows {
		if r.Day >= from {
			kept = append(kept, r)
		} else if r.Day > droppedDay {
			droppedDay = r.Day
		}
	}
	sort.SliceStable(kept, func(i, j int) bool { return kept[i].Day < kept[j].Day })
	if len(kept) > maxRows {
		if d := kept[len(kept)-maxRows-1].Day; d > droppedDay {
			droppedDay = d
		}
		kept = kept[len(kept)-maxRows:]
	}
	l.Rows = kept
	for {
		b, _ := json.Marshal(l)
		if len(b) < maxFile || len(l.Rows) == 0 {
			break
		}
		n := len(l.Rows) / 10
		if n == 0 {
			n = 1
		}
		if d := l.Rows[n-1].Day; d > droppedDay {
			droppedDay = d
		}
		l.Rows = l.Rows[n:]
	}
	if droppedDay == "" {
		return
	}
	cut := dayStart(mustDay(nextDay(droppedDay)))
	for s, c := range l.Coverage {
		if c.From.Before(cut) {
			c.From = cut
		}
		if !c.From.Before(c.Through) {
			delete(l.Coverage, s)
			continue
		}
		l.Coverage[s] = c
	}
}

func mustDay(d string) time.Time {
	t, err := time.ParseInLocation("2006-01-02", d, time.Local)
	if err != nil {
		return time.Now()
	}
	return t
}
