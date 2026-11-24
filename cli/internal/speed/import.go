// SPDX-License-Identifier: MIT
package speed

import (
	"bufio"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"github.com/modelplan/modelplan/cli/internal/idlework"
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
// started, so a later slice can fill charts and the effort suggestion from day one (the cockpit's 7- and 30-day views read it back through speed.PerfView.ImportedRows). It reads what the live
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
	AccountingVersion int       `json:"accountingVersion,omitempty"`
	From              time.Time `json:"from"`
	Through           time.Time `json:"through"`
	// Epoch: the grant the span was imported under. After a revoke and a new grant the span no
	// longer counts and the source is read again.
	Epoch *GrantEpoch `json:"epoch,omitempty"`
	// Retry: logs inside the span that could not be read. The span still counts as covered, but
	// each of these files is read again, alone, on the next import (HIST-IMP-12).
	Retry []RetryFile `json:"retry,omitempty"`
	// Archived: the Codex span also covers archived threads (archived_sessions). An older span
	// without it is imported again from both folders, replacing its rows (glm-967-2).
	Archived bool `json:"archived,omitempty"`
	// Complete: an import of the source finished under Epoch, also when the eligible interval was
	// empty (the live ledger or a clear already reaches back past it), so there is no From.
	Complete bool `json:"complete,omitempty"`
}

// RetryFile is one log whose read failed and the turn spans it still owes.
type RetryFile struct {
	// Key identifies the log by a hash of its path; the ledger never holds a path (it can carry a project name). The
	// path itself lives only in memory and is found again by hash on the next import.
	Key   string `json:"key"`
	Path  string `json:"-"`
	Spans []Span `json:"spans"`
}

// RetryKey is the ledger's identity of an unreadable log.
func RetryKey(path string) string {
	h := sha256.Sum256([]byte(path))
	return hex.EncodeToString(h[:16])
}

// importItem is one log to read and the spans whose turns it may contribute.
type importItem struct {
	path   string
	ranges []span
}

// ImportLedger is imported.json's content.
type ImportLedger struct {
	SchemaVersion int `json:"schemaVersion"`
	// AutoRan: when the first-run import ran (also when it skipped every source), so it is not
	// repeated; the Settings action stays available.
	AutoRan *time.Time `json:"autoRan,omitempty"`
	// AutoRequested: when a first-run import was last asked for. With no AutoRan it is owed: the
	// run failed, was interrupted or found no grant, and the engine retries it at launch (G3-112).
	AutoRequested *time.Time `json:"autoRequested,omitempty"`
	// Removed: the grant each source's history was imported under when the user removed it
	// ("Remove imported history"). Under that grant it is not owed again; a revoke and a new
	// grant are a new epoch and owe it again (macrevd-967-1).
	Removed map[string]*GrantMark `json:"removed,omitempty"`
	// Attempts: automatic retries of a source not yet imported, under one grant. They back off
	// and stop at OwedRetryMax; an import of the source or a new grant clears them.
	Attempts map[string]ImportAttempt `json:"attempts,omitempty"`
	// Cancelled: the grant each source was under when the user cancelled an import; no automatic
	// import of it starts again under that grant (macrevd-967-4).
	Cancelled map[string]*GrantMark `json:"cancelled,omitempty"`
	Coverage  map[string]Span       `json:"coverage,omitempty"`
	Rows      []PerfRow             `json:"rows"`
}

// ImportPath is the ledger file.
func ImportPath(cache string) string { return filepath.Join(cache, "observed", "imported.json") }

// LoadImported reads the ledger. A missing file is an empty ledger; ok is false when the file is
// there but unusable (unreadable, too large or another schema), and it is then left as it is.
func LoadImported(cache string) (l ImportLedger, ok bool) {
	b, err := idlework.ReadFile(ImportPath(cache))
	if errors.Is(err, os.ErrNotExist) {
		return ImportLedger{SchemaVersion: 1, Rows: []PerfRow{}}, true
	}
	if err != nil || len(b) > maxFile {
		return ImportLedger{}, false
	}
	idlework.Decode()
	if json.Unmarshal(b, &l) != nil || l.SchemaVersion != 1 {
		return ImportLedger{}, false
	}
	if l.Rows == nil {
		l.Rows = []PerfRow{}
	}
	return l, true
}

// GrantMark names one recorded history grant: the scope's epoch and the time the user allowed it.
// A Cancel or Remove made under it suppresses automatic imports until a different grant: a revoke
// and a new allow (new epoch), or a first explicit allow of a scope nobody had answered (new
// time; macrevd-967-6).
type GrantMark struct {
	Epoch *GrantEpoch `json:"epoch"`
	At    time.Time   `json:"at"`
}

// recordedMark: the mark of source's recorded allow in force, or nil (undecided, refused or off).
func recordedMark(a consent.Admission, source string) *GrantMark {
	state := a.State()
	r, decided := state.Scopes[sourceScope(source)]
	epoch := currentEpoch(a, source)
	if !decided || !r.Allowed || epoch == nil {
		return nil
	}
	return &GrantMark{Epoch: epoch, At: r.At.UTC()}
}

func (m *GrantMark) same(o *GrantMark) bool {
	return m != nil && o != nil && sameEpoch(m.Epoch, o.Epoch) && m.At.Equal(o.At)
}

// ImportAttempt is one source's automatic retry count, when the next may start, and the grant
// they were made under.
type ImportAttempt struct {
	N     int         `json:"n"`
	Next  time.Time   `json:"next"`
	Epoch *GrantEpoch `json:"epoch,omitempty"`
}

// The owner's condition for the retry (2026-11-14): it never disturbs. A source that keeps failing
// is retried at most OwedRetryMax times, OwedRetryBase, then twice as long after each attempt.
const (
	OwedRetryMax  = 5
	OwedRetryBase = time.Hour
)

// OwedSources is OwedSourcesAt now.
func OwedSources(cache string, a consent.Admission) []string {
	return OwedSourcesAt(cache, a, time.Now())
}

// MarkOwedAttempt records an automatic retry of sources: the count under the current grant and
// the backoff before the next one.
func MarkOwedAttempt(cache string, sources []string, a consent.Admission, now time.Time) error {
	unlock, ok := lockWait(cache, "perf.lock")
	if !ok {
		return errors.New("readings busy; retry the import")
	}
	defer unlock()
	led, ok := LoadImported(cache)
	if !ok {
		return errors.New("imported history unreadable; left as it is")
	}
	if led.Attempts == nil {
		led.Attempts = map[string]ImportAttempt{}
	}
	for _, source := range sources {
		epoch := currentEpoch(a, source)
		at := led.Attempts[source]
		if !sameEpoch(at.Epoch, epoch) {
			at = ImportAttempt{}
		}
		at.N++
		at.Epoch = epoch
		at.Next = now.UTC().Add(OwedRetryBase << (at.N - 1))
		led.Attempts[source] = at
	}
	return writeImported(cache, led)
}

// OwedSourcesAt: the history sources the engine still owes an import (G3-112). The first-run import
// was requested (or ran under an older build), and the source holds a recorded grant (never a
// default-on scope the user has not answered) but no span under that grant, or a Codex span
// from before archived threads were read. A fresh profile owes nothing.
func OwedSourcesAt(cache string, a consent.Admission, now time.Time) []string {
	var owed []string
	for _, source := range []string{"claude-code", "codex"} {
		if at, ok := owedAt(cache, a, source); ok && !now.Before(at) {
			owed = append(owed, source)
		}
	}
	return owed
}

// NextOwedAt: the earliest time an owed source may be retried (now or later); ok is false when
// no source will be (macrevd-967-5: a running engine wakes for it).
func NextOwedAt(cache string, a consent.Admission, now time.Time) (time.Time, bool) {
	var next time.Time
	found := false
	for _, source := range []string{"claude-code", "codex"} {
		if at, ok := owedAt(cache, a, source); ok {
			if at.Before(now) {
				at = now
			}
			if !found || at.Before(next) {
				next, found = at, true
			}
		}
	}
	return next, found
}

// owedAt: when source may next be imported automatically (zero: any time); ok is false when it is
// not owed at all: no request, no recorded grant, removed or cancelled by the user under this
// grant, retries used up, or imported.
func owedAt(cache string, a consent.Admission, source string) (time.Time, bool) {
	if Off() {
		return time.Time{}, false
	}
	l, ok := LoadImported(cache)
	if !ok || (l.AutoRequested == nil && l.AutoRan == nil) {
		return time.Time{}, false
	}
	mark := recordedMark(a, source)
	if mark == nil {
		return time.Time{}, false
	}
	epoch := mark.Epoch
	if l.Removed[source].same(mark) {
		return time.Time{}, false // removed by the user under this grant
	}
	if l.Cancelled[source].same(mark) {
		return time.Time{}, false // the user cancelled an import under this grant
	}
	c, has := l.Coverage[source]
	if has && (c.Complete || !c.From.IsZero()) && c.AccountingVersion == 1 && sameEpoch(c.Epoch, epoch) && (source != "codex" || c.Archived) {
		return time.Time{}, false // imported
	}
	if at, tried := l.Attempts[source]; tried && sameEpoch(at.Epoch, epoch) {
		if at.N >= OwedRetryMax {
			return time.Time{}, false // given up under this grant
		}
		return at.Next, true
	}
	return time.Time{}, true
}

// MarkOwedCancelled: the user cancelled an import, so no automatic import of a source with a
// recorded grant starts again under that grant (macrevd-967-4). A new grant, or an import of the
// source, lifts it.
func MarkOwedCancelled(cache string, a consent.Admission) error {
	unlock, ok := lockWait(cache, "perf.lock")
	if !ok {
		return errors.New("readings busy; retry")
	}
	defer unlock()
	led, ok := LoadImported(cache)
	if !ok {
		return errors.New("imported history unreadable; left as it is")
	}
	changed := false
	for _, source := range []string{"claude-code", "codex"} {
		// Only a recorded allow is marked: an undecided default-on scope was never read
		// automatically, and its later first allow must not be blocked (macrevd-967-6).
		if mark := recordedMark(a, source); mark != nil {
			if led.Cancelled == nil {
				led.Cancelled = map[string]*GrantMark{}
			}
			led.Cancelled[source], changed = mark, true
		}
	}
	if !changed {
		return nil
	}
	return writeImported(cache, led)
}

// MarkAutoRequested records that the first-run import was asked for (kept until it completes).
func MarkAutoRequested(cache string, now time.Time) error {
	unlock, ok := lockWait(cache, "perf.lock")
	if !ok {
		return errors.New("readings busy; retry the import")
	}
	defer unlock()
	led, ok := LoadImported(cache)
	if !ok || led.AutoRan != nil {
		return nil
	}
	t := now.UTC().Truncate(time.Second)
	led.AutoRequested = &t
	return writeImported(cache, led)
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
	// Live reads the consent in force now. A source whose history grant is no longer the one the run
	// was admitted under stops before its next log is opened and writes nothing. Nil reads the
	// current consent when Admission is nil too (production), and skips the live check otherwise.
	Live func() consent.Admission
	// Progress, when set, is called with the number of log files read so far and the total to read
	// (counted before the first read), from the importing goroutine.
	Progress func(done, total int)
	// Pause between logs, so an automatic retry stays a light background read (owner condition).
	Pause time.Duration
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
	cache       string
	usage       map[string]usageFile
	usageRanges map[string][]span
	now         time.Time
	pause       time.Duration
	source      string
	root        *ImportRoot
	dirs        []string // under the root
	// reread: the source's older span is replaced, rows included, by this run's (glm-967-2).
	reread bool
	prefix string // file name prefix, "" for any
	newP   func() parser
	parser string
	ranges []span
	list   []string
	pend   []RetryFile // unreadable logs of an earlier run, read again alone
	failed []RetryFile // logs of this run that could not be read
	rows   []PerfRow
	turns  int
	status string
	// epoch: the grant the run was admitted under; live reads the grant in force now (nil: no
	// live check). withdrawn: the grant changed mid-run, so nothing of this source is written.
	epoch     *GrantEpoch
	live      func() consent.Admission
	withdrawn bool
	// cleared: the source's clear boundary (cleared.go) when the run started; nothing before it
	// is read, and a clear during the run withdraws the source as a grant change does.
	cleared time.Time
}

var errGrantWithdrawn = errors.New("history grant withdrawn during the import")

var errImportCancelled = errors.New("import cancelled before its commit")

var errClearedDuringImport = errors.New("history cleared during the import")

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
	live := o.Live
	if live == nil && o.Admission == nil {
		live = consent.Capture
	}
	jobs := []*importJob{
		{source: "claude-code", root: o.Claude, dirs: []string{"projects"}, newP: func() parser { return newClaude(now) }, parser: ParserClaude},
		// G3-112: Codex moves archived threads to archived_sessions; their turns are history too.
		{source: "codex", root: o.Codex, dirs: []string{"sessions", "archived_sessions"}, prefix: "rollout-", newP: func() parser { return newCodex() }, parser: ParserCodex},
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
	clr := LoadCleared(cache)
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
		jfrom := from
		if c.AccountingVersion < 1 {
			if !c.From.IsZero() && c.From.Before(jfrom) {
				jfrom = c.From
			}
			c, j.reread = Span{}, true
		}
		if j.source == "codex" && !c.From.IsZero() && !c.Archived {
			// Written before archived threads were read: import the whole span again from both
			// folders and replace its rows, so each turn counts once wherever its log now lies.
			if c.From.Before(jfrom) {
				jfrom = c.From
			}
			c, j.reread = Span{}, true
		}
		j.cleared = clr.tool(j.source)
		if j.cleared.After(jfrom) {
			jfrom = j.cleared // a cleared history is not imported again
		}
		j.ranges = missing(c, jfrom, cutoff)
		j.pend = c.Retry
		j.cache = cache
		j.now = now
		j.epoch, j.live, j.pause = currentEpoch(adm, j.source), live, o.Pause
		active = append(active, j)
	}
	// One pass per source: files that may hold turns of a missing range.
	prog := &importProgress{fn: o.Progress}
	for _, j := range active {
		if len(j.ranges) > 0 {
			j.list = j.files(j.earliest())
			prog.total += len(j.list)
		}
		if len(j.pend) > 0 { // find the unreadable logs again by their hash (no path is stored)
			byKey := map[string]string{}
			found, complete := j.walk(time.Time{})
			for _, f := range found {
				byKey[RetryKey(f)] = f
			}
			// An unfound log counts as deleted only after a complete scan. While a folder cannot be
			// listed (or the scan stops at its cap) the log is left out of this run and stays owed.
			var pend []RetryFile
			for _, r := range j.pend {
				r.Path = byKey[r.Key]
				if r.Path != "" || complete {
					pend = append(pend, r)
				}
			}
			j.pend = pend
		}
		prog.total += len(j.pend)
	}
	prog.report()
	for _, j := range active {
		if len(j.ranges) == 0 && len(j.pend) == 0 {
			j.status = StatusImported
			continue
		}
		if err := j.read(ctx, prog); err != nil {
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
	// A cancel that arrives after the reads and before the first write still writes nothing.
	if ctx.Err() != nil {
		res.Cancelled = true
		return res, nil
	}
	// Commit, source by source, each under its own consent fence. A source whose grant changed
	// after its read (revoked, or revoked and granted again) writes nothing; the others go on.
	skip := func(j *importJob) {
		j.withdrawn, j.status, j.rows, j.turns = true, StatusNoConsent, nil, 0
		for i := range res.Sources {
			if res.Sources[i].Source == j.source {
				res.Sources[i].Status, res.Sources[i].Turns = StatusNoConsent, 0
			}
		}
	}
	grantChanged := func(j *importJob) bool {
		return j.live != nil && !sameEpoch(currentEpoch(j.live(), j.source), j.epoch)
	}
	committed := false
	for _, j := range active {
		j := j
		if j.withdrawn {
			continue
		}
		write := func() error {
			if !committed && ctx.Err() != nil { // checked again under the fence, just before the write
				res.Cancelled = true
				return nil
			}
			if grantChanged(j) { // under the fence: the live grant is not the one this read was made under
				skip(j)
				return nil
			}
			err := commitImport(ctx, cache, j, o.Auto, now, adm, &committed)
			if errors.Is(err, errImportCancelled) {
				res.Cancelled = true
				return nil
			}
			if errors.Is(err, errClearedDuringImport) {
				skip(j)
				return nil
			}
			return err
		}
		var err error
		if o.Guard != nil {
			err = o.Guard(consentTool(j.source), write)
		} else {
			err = write()
		}
		if err != nil {
			if grantChanged(j) { // the guard refused because consent was withdrawn: not a failure
				skip(j)
				continue
			}
			return res, err
		}
	}
	if res.Cancelled {
		return res, nil
	}
	// G3-112: a first-run import that could read no source (no history grant yet) stays pending, so
	// it runs when a grant arrives; once a source was admitted the first run is done.
	// glm-967-4: only a source that finished under its grant completes it; a run whose every
	// source was withdrawn before its commit stays owed.
	finished := false
	for _, j := range active {
		finished = finished || !j.withdrawn
	}
	if !committed && o.Auto && finished {
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

type importProgress struct {
	fn          func(done, total int)
	done, total int
}

func (p *importProgress) report() {
	if p.fn != nil {
		p.fn(p.done, p.total)
	}
}

func (j *importJob) earliest() time.Time {
	e := j.ranges[0].lo
	for _, r := range j.ranges {
		if r.lo.Before(e) {
			e = r.lo
		}
	}
	return e
}

func (j *importJob) read(ctx context.Context, prog *importProgress) error {
	tmp := &PerfLedger{}
	seen := map[string]bool{} // Claude request ids counted so far in this run
	// admitted: still running and still under the grant the run started with. Checked before each
	// log is opened and while one is parsed, so a revoke stops the reads, not only the write.
	admitted := func() error {
		if err := ctx.Err(); err != nil {
			return err
		}
		if j.live != nil && !sameEpoch(currentEpoch(j.live(), j.source), j.epoch) {
			return errGrantWithdrawn
		}
		return nil
	}
	var work []importItem
	withdraw := func(i int) error {
		j.withdrawn, j.status, j.rows, j.turns = true, StatusNoConsent, nil, 0
		prog.done += len(work) - i - 1 // the logs left unread
		prog.report()
		return nil
	}
	for _, p := range j.list {
		work = append(work, importItem{path: p, ranges: append([]span(nil), j.ranges...)})
	}
	for _, r := range j.pend {
		if r.Path == "" {
			prog.done++ // gone for good: nothing left to retry
			continue
		}
		if _, err := os.Lstat(r.Path); errors.Is(err, os.ErrNotExist) {
			prog.done++ // gone for good: nothing left to retry
			continue
		}
		// A retry log that is also in this run's list is read once with both range sets: reading it
		// twice would let the first pass mark every request id seen and drop the owed turns.
		at := -1
		for k := range work {
			if work[k].path == r.Path {
				at = k
				break
			}
		}
		if at < 0 {
			work = append(work, importItem{path: r.Path})
			at = len(work) - 1
		}
		for _, sp := range r.Spans {
			work[at].ranges = append(work[at].ranges, span{sp.From, sp.Through})
		}
	}
	for i, it := range work {
		p := it.path
		if err := ctx.Err(); err != nil {
			return err
		}
		prog.done++
		prog.report()
		if err := admitted(); err != nil {
			if errors.Is(err, errGrantWithdrawn) {
				return withdraw(i)
			}
			return err
		}
		if j.pause > 0 && i > 0 {
			select { // a light background read: yield between logs
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(j.pause):
			}
		}
		if j.root.Background != nil && j.source == "codex" && j.root.Background(p) {
			continue
		}
		parser := j.newP()
		var cp *claudeParser
		if c, ok := parser.(*claudeParser); ok {
			cp = c
			c.prior, c.mine = seen, map[string]bool{}
		}
		infoBefore, statErr := os.Stat(p)
		usage := newAccountingParser(j.source, fileKey(p))
		turns, err := readWhole(admitted, p, &accountingTee{parser: parser, usage: usage})
		if err != nil {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			if errors.Is(err, errGrantWithdrawn) {
				return withdraw(i)
			}
			// Unreadable: its span stays covered but the file is retried on the next import.
			rf := RetryFile{Key: RetryKey(p), Path: p}
			for _, r := range it.ranges {
				rf.Spans = append(rf.Spans, Span{From: r.lo, Through: r.hi})
			}
			j.failed = append(j.failed, rf)
			continue
		}
		if j.usage == nil {
			j.usage = map[string]usageFile{}
			j.usageRanges = map[string][]span{}
		}
		if fi := infoBefore; statErr == nil {
			records := []usageRecord{}
			for _, r := range usage.records {
				if inRange(it.ranges, r.At) && day(r.At) >= windowFrom(j.now, 35) && !r.At.Before(j.cleared) && !r.At.After(j.now) {
					r.Imported = true
					records = append(records, r)
				}
			}
			j.usage[fileKey(p)] = usageFile{Tiered: true, Source: j.source, Epoch: j.epoch, Size: fi.Size(), Modified: fi.ModTime().UnixNano(), Records: records, Session: usageHash(usage.session), Parent: usage.parent, Started: usage.started}
			j.usageRanges[fileKey(p)] = append([]span(nil), it.ranges...)
		}
		if cp != nil {
			for id := range cp.mine {
				seen[id] = true
			}
		}
		for _, t := range turns {
			if t.at.IsZero() || !inRange(it.ranges, t.at) || t.at.Before(j.cleared) {
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

func inRange(ranges []span, t time.Time) bool {
	for _, r := range ranges {
		if r.has(t) {
			return true
		}
	}
	return false
}

// importWalkDir and importOpen are the importer's filesystem calls; tests replace them to fail a
// folder listing or a log read without depending on file permissions (which root ignores).
var (
	importWalkDir = filepath.WalkDir
	importOpen    = os.Open
)

// files lists the source's logs modified since `since`, in a stable order. Links, directories and
// the harness's sub-agent folders are not followed.
func (j *importJob) files(since time.Time) []string {
	out, _ := j.walk(since)
	return out
}

// walk is files plus whether the scan saw every log: false when a folder could not be listed or the
// scan stopped at its cap. A missing root is complete (there are no logs).
func (j *importJob) walk(since time.Time) ([]string, bool) {
	var out []string
	visited, complete := 0, true
	for _, dir := range j.dirs {
		var ok bool
		out, visited, ok = j.walkDir(filepath.Join(j.root.Dir, dir), since, out, visited)
		complete = complete && ok
	}
	sort.Strings(out)
	return out, complete
}

// walkDir adds one folder's logs to out; visited counts entries across all of a source's folders.
func (j *importJob) walkDir(root string, since time.Time, out []string, visited int) ([]string, int, bool) {
	if !filepath.IsAbs(root) {
		return out, visited, true
	}
	complete := true
	_ = importWalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if visited++; visited > maxImportFiles {
			complete = false
			return fs.SkipAll
		}
		if err != nil {
			if !(path == root && errors.Is(err, fs.ErrNotExist)) {
				complete = false
			}
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
	return out, visited, complete
}

// readWhole streams one log line by line through a parser and returns its finished turns. A line
// that is too long or does not parse is skipped by the parser; an unfinished last turn is dropped.
func readWhole(admitted func() error, path string, p parser) ([]turn, error) {
	fh, err := importOpen(path)
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
			if err := admitted(); err != nil {
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
func commitImport(ctx context.Context, cache string, j *importJob, auto bool, now time.Time, adm consent.Admission, committed *bool) error {
	epoch := currentEpoch(adm, j.source) // re-checked inside the consent fence
	if epoch == nil {
		j.status = StatusNoConsent
		return nil
	}
	unlock, ok := lockWait(cache, "perf.lock")
	if !ok {
		return errors.New("readings busy; retry the import")
	}
	defer unlock()
	if !*committed && ctx.Err() != nil { // a cancel that arrived while waiting for perf.lock
		return errImportCancelled
	}
	if !LoadCleared(cache).tool(j.source).Equal(j.cleared) { // under perf.lock, as the clear writes it
		return errClearedDuringImport
	}
	led, ok := LoadImported(cache)
	if !ok {
		return errors.New("imported history unreadable; left as it is")
	}
	if led.Coverage == nil {
		led.Coverage = map[string]Span{}
	}
	c := led.Coverage[j.source]
	if !sameEpoch(c.Epoch, epoch) || j.reread { // an older grant's (or a re-read span's) rows are replaced
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
	c.AccountingVersion = 1
	c.Archived = j.source == "codex"
	c.Complete = true
	// Every pending log was tried this run: the ones that read are done, the ones that failed
	// again (and new failures) are in j.failed.
	tried := map[string]bool{}
	for _, r := range j.pend {
		tried[r.Key] = true
	}
	var retry []RetryFile
	for _, r := range c.Retry {
		if !tried[r.Key] {
			retry = append(retry, r)
		}
	}
	for _, f := range j.failed {
		merged := false
		for i := range retry {
			if retry[i].Key == f.Key {
				retry[i].Spans = append(retry[i].Spans, f.Spans...)
				merged = true
			}
		}
		if !merged {
			retry = append(retry, f)
		}
	}
	c.Retry = retry
	led.Coverage[j.source] = c
	delete(led.Removed, j.source) // imported again on purpose
	delete(led.Attempts, j.source)
	delete(led.Cancelled, j.source)
	if auto && led.AutoRan == nil {
		t := now.UTC().Truncate(time.Second)
		led.AutoRan = &t
	}
	led.prune(now)
	*committed = true
	if len(j.usage) > 0 {
		usage, ok := loadAccounting(cache)
		if !ok {
			return errors.New("accounting history unreadable; left as it is")
		}
		for key, f := range j.usage {
			usage.Files[key] = mergeImportedUsage(usage.Files[key], f, j.usageRanges[key])
		}
		if err := saveAccounting(cache, usage); err != nil {
			return err
		}
	}
	return writeImported(cache, led)
}

func markAutoRan(cache string, now time.Time) error {
	unlock, ok := lockWait(cache, "perf.lock")
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
func RemoveImported(cache string) error { return RemoveImportedUnder(cache, consent.Capture()) }

// RemoveImportedUnder is RemoveImported under the consent a.
func RemoveImportedUnder(cache string, a consent.Admission) error {
	unlock, ok := lockWait(cache, "perf.lock")
	if !ok {
		return errors.New("readings busy; retry")
	}
	defer unlock()
	if err := removeImportedAccountingLocked(cache); err != nil {
		return err
	}
	led, ok := LoadImported(cache)
	if !ok {
		return os.Remove(ImportPath(cache))
	}
	if len(led.Rows) == 0 && len(led.Coverage) == 0 && led.AutoRan == nil && led.AutoRequested == nil {
		return nil
	}
	if led.AutoRan == nil && led.AutoRequested == nil {
		if err := os.Remove(ImportPath(cache)); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
		return nil
	}
	// Every source with a recorded allow now is marked, imported or still owed: the user asked
	// for no imported history under these grants (macrevd-967-1).
	removed := led.Removed
	for _, source := range []string{"claude-code", "codex"} {
		if mark := recordedMark(a, source); mark != nil {
			if removed == nil {
				removed = map[string]*GrantMark{}
			}
			removed[source] = mark
		}
	}
	// The user's earlier Cancel and the retry counts stay: a removal never re-arms an import.
	return writeImported(cache, ImportLedger{SchemaVersion: 1, AutoRan: led.AutoRan, AutoRequested: led.AutoRequested, Removed: removed, Cancelled: led.Cancelled, Attempts: led.Attempts, Rows: []PerfRow{}})
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

// ImportCoverage is what the importer has covered for one source: local days, no paths.
type ImportCoverage struct {
	Source  string
	From    string // first local day, YYYY-MM-DD
	Through string // last local day, YYYY-MM-DD
	Rows    int
}

// ImportState is the read-only view Settings shows: nothing is read from the logs.
type ImportState struct {
	AutoRan  bool
	Rows     int
	Coverage []ImportCoverage
}

// ImportedCoverage is one source's coverage end and imported row count; ok is false when the
// source has none. It reads imported.json only.
func ImportedCoverage(cache, source string) (through time.Time, rows int, ok bool) {
	l, readable := LoadImported(cache)
	if !readable {
		return time.Time{}, 0, false
	}
	c, has := l.Coverage[source]
	if !has || c.Through.IsZero() {
		return time.Time{}, 0, false
	}
	for _, r := range l.Rows {
		if r.Source == source {
			rows++
		}
	}
	return c.Through, rows, true
}

// ImportStatus reads imported.json only.
func ImportStatus(cache string) ImportState {
	l, ok := LoadImported(cache)
	st := ImportState{Coverage: []ImportCoverage{}}
	if !ok {
		return st
	}
	st.AutoRan, st.Rows = l.AutoRan != nil, len(l.Rows)
	for _, src := range []string{"claude-code", "codex"} {
		c, has := l.Coverage[src]
		if !has {
			continue
		}
		n := 0
		for _, r := range l.Rows {
			if r.Source == src {
				n++
			}
		}
		st.Coverage = append(st.Coverage, ImportCoverage{Source: src, From: day(c.From), Through: day(c.Through.Add(-time.Second)), Rows: n})
	}
	return st
}

// lockWait: the live observers hold perf.lock only for a moment, so an import waits a few seconds for
// it instead of failing.
func lockWait(cache, name string) (func(), bool) {
	for i := 0; i < 50; i++ {
		if unlock, ok := lock(cache, name); ok {
			return unlock, true
		}
		time.Sleep(100 * time.Millisecond)
	}
	return nil, false
}
