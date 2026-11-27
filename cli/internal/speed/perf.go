package speed

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"github.com/modelplan/modelplan/cli/internal/idlework"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// The performance ledger, <cache>/observed/perf.json, runs beside speed.json and never merges with
// it. Its rows also count every request the parsers saw, keep turn sums and the time of the newest
// sample, and say which parser and which validity rule produced them, so their figures are sums
// that add up across days rather than rates. It starts at Since: only turns that started at or
// after it are counted, so log content read before it can never be counted again. speed.json keeps
// being written as before, by this CLI and older ones. Each write also rolls its days up into
// daily-long.json (daily.go), which keeps them for a year.

const (
	PerfKeep = 35 * 24 * time.Hour // a 30-day view stays complete on any day
	// Parsers and the validity rule of a generation sample; rows of different ones never merge.
	ParserCodex   = "codex-rollout/1"
	ParserClaude  = "claude-transcript/1"
	EligibilityV1 = "gen-v1"
)

// PerfLedger is perf.json's content.
type PerfLedger struct {
	UsageRows []PerfRow `json:"-"` // response accounting, loaded independently of timing samples
	// UsageSessions: the same responses by the log they came from (PerfSession.Key), each counted once.
	UsageSessions map[string][]SessionResponse `json:"-"`
	SchemaVersion int                          `json:"schemaVersion"`
	Since         time.Time                    `json:"since"` // UTC, when the file was created
	Hourly        []Hourly                     `json:"hourly,omitempty"`
	Live          []LiveRecord                 `json:"live,omitempty"`
	Rows          []PerfRow                    `json:"rows"`
	Sessions      []PerfSession                `json:"sessions,omitempty"`
	Files         map[string]Cursor            `json:"files,omitempty"`
	Counted       []CountedRequest             `json:"counted,omitempty"` // Claude requests already counted (speed.go)
	// Stores: how far each agent database was read (sqlite.go).
	Stores map[string]DBCursor `json:"stores,omitempty"`

	admission    consent.Admission
	project      func(source, cwd string, np nativeProject) projectInfo // while observing: names a session's project
	codexNames   map[string]string                                      // while observing: Codex thread names read this run
	titles       bool                                                   // while observing: project labels are on, so session titles are kept
	subscription string                                                 // while observing: the harness account's reference
	cleared      Cleared                                                // while observing: the clear boundaries (cleared.go)
}

// Ingest: what the caller knows while the ledger reads new turns. Labels: project labels are on
// (while off, none is kept). Subscription: the reference of the account the harness is signed in
// to now (quota's identity.go), "" when unknown.
type Ingest struct {
	Labels       bool
	Subscription string
}

// PerfSession is one harness session (a Claude Code transcript, a Codex thread), known only by a
// random reference. It holds no title, path or session id: Key is the log's file key, as the
// cursors use, and never leaves this file.
type PerfSession struct {
	GrantEpoch *GrantEpoch `json:"grantEpoch,omitempty"`
	Ref        string      `json:"ref"`
	Key        string      `json:"key"`
	Source     string      `json:"source"`
	// ProjectRef: the opaque reference of the session's project (project.go), "" when its log
	// records no working directory. ProjectLabel: the project folder's name, only while project
	// labels are on.
	ProjectRef   string `json:"projectRef,omitempty"`
	ProjectLabel string `json:"projectLabel,omitempty"`
	// ProjectRule: the project rule that set ProjectRef (0 = the old git-root grouping, 1 = each tool's own
	// definition, G3-100, 2 = the repository root with worktrees merged, then a workspace, then a bucket, D470). An older session is re-attributed once on its next observation.
	ProjectRule int `json:"projectRule,omitempty"`
	// ProjectKind: repo | workspace | independent | home | none (projectid.go); "" for a session recorded before it.
	ProjectKind string `json:"projectKind,omitempty"`
	// Title: the tool's own generated or user-set session title, only while project labels are on (D470 3).
	// Never the first message. Local only, like the label.
	Title string `json:"title,omitempty"`
	// SubscriptionRef: the account the harness was signed in to when the session's first turn
	// with a known one was read; "" when unknown.
	SubscriptionRef string       `json:"subscriptionRef,omitempty"`
	FirstAt         time.Time    `json:"firstAt"` // its first counted turn's start, to the minute
	LastAt          time.Time    `json:"lastAt"`  // its newest sample's completion, to the minute
	Days            []SessionDay `json:"days"`
}

// SessionDay: what one configuration of a session produced on one local day.
type SessionDay struct {
	Day                  string `json:"day"`
	Model                string `json:"model"`
	EffortStatus         string `json:"effortStatus"`
	Effort               string `json:"effort,omitempty"`
	Speed                string `json:"speed,omitempty"`
	ObservedRequests     int    `json:"observedRequests"`
	ObservedOutputTokens int64  `json:"observedOutputTokens"`
	// Kinds are the day's input, cache-read and cache-write sums (CKP-STRIP-16): each is unknown, never zero, unless
	// every recorded request supplied it. Absent for days recorded before they were kept, which read as unknown.
	Kinds *TokenKinds `json:"tokenKinds,omitempty"`
}

// PerfRow is one local day of one configuration, as one parser read it.
type PerfRow struct {
	GrantEpoch *GrantEpoch `json:"grantEpoch,omitempty"`
	TokenKinds
	Day          string `json:"day"` // local date of the turns' start, YYYY-MM-DD
	Source       string `json:"source"`
	Model        string `json:"model"`
	EffortStatus string `json:"effortStatus"`     // reported | unreported
	Effort       string `json:"effort,omitempty"` // native key; "" when unreported
	Speed        string `json:"speed,omitempty"`
	Parser       string `json:"parser"`
	Eligibility  string `json:"eligibility"`
	// Every request the parser saw in a finished turn, counted once, eligible or not.
	ObservedRequests     int   `json:"observedRequests"`
	ObservedOutputTokens int64 `json:"observedOutputTokens"`
	// The requests that pass Eligibility: the basis of the generation rate.
	EligibleRequests     int   `json:"eligibleRequests"`
	EligibleOutputTokens int64 `json:"eligibleOutputTokens"`
	GenMs                int64 `json:"genMs"`
	// Finished turns under this one configuration, tools included; a turn whose requests ran under
	// more than one configuration is only counted as excluded.
	Turns                    int   `json:"turns"`
	TurnMs                   int64 `json:"turnMs"`
	TurnOutputTokens         int64 `json:"turnOutputTokens"`
	MixedConfigTurnsExcluded int   `json:"mixedConfigTurnsExcluded"`
	TTFTMs                   Hist  `json:"ttftMs,omitempty"`
	TurnMsHist               Hist  `json:"turnMsHist,omitempty"`
	TurnTokensHist           Hist  `json:"turnTokensHist,omitempty"`
	// LastAt: when the newest sample in the row completed (UTC, to the minute).
	LastAt *time.Time `json:"lastAt,omitempty"`
	// Origin: "import" on rows the history importer made (import.go); empty on live rows.
	Origin string `json:"origin,omitempty"`
	// Responses: on response-accounting rows only, each counted response in the row, so a
	// price can be applied per request (cost.go). Never stored; rebuilt from the ledger.
	Responses []Response `json:"-"`
}

// PerfPath is the ledger file.
func PerfPath(cache string) string { return filepath.Join(cache, "observed", "perf.json") }

// LoadPerf reads the ledger. A missing file is a new, empty ledger (zero Since). ok is false when
// the file is there but cannot be used (unreadable, too large, another schema or no Since); it is
// then left as it is and nothing is reported from it.
func LoadPerf(cache string) (PerfLedger, bool) {
	l, ok := loadPerf(cache)
	if ok {
		l = accountingOverlay(cache, l)
	}
	return l, ok
}
func loadPerf(cache string) (l PerfLedger, ok bool) { return loadPerfUpTo(cache, maxFile) }

// loadPerfUpTo reads perf.json up to limit bytes. Readers use maxFile; the writer uses recoverMax, so a file that grew past the
// reader limit is read whole and shrunk by the next write instead of staying unreadable for good.
func loadPerfUpTo(cache string, limit int) (l PerfLedger, ok bool) {
	b, err := os.ReadFile(PerfPath(cache))
	if errors.Is(err, os.ErrNotExist) {
		return PerfLedger{SchemaVersion: 1}, true
	}
	if err == nil {
		idlework.Open()
		idlework.Read(len(b))
	}
	if err != nil || len(b) > limit {
		return PerfLedger{}, false
	}
	idlework.Decode()
	if json.Unmarshal(b, &l) != nil || l.SchemaVersion != 1 || l.Since.IsZero() {
		return PerfLedger{}, false
	}
	return l, true
}

// observePerf: as observe, for perf.json. A new ledger is written even with nothing in it yet, so
// that its Since holds.
func observePerf(cache string, now time.Time, in Ingest, f func(*PerfLedger) bool) error {
	labels := in.Labels
	if Off() {
		return nil
	}
	unlock, ok := lock(cache, "perf.lock")
	if !ok {
		return nil
	}
	defer unlock()
	l, ok := loadPerfUpTo(cache, recoverMax)
	if !ok {
		return nil // not ours to overwrite
	}
	oversize := false
	if fi, err := os.Stat(PerfPath(cache)); err == nil && fi.Size() > maxFile {
		oversize = true // written by an older build or grown past the limit: the next write shrinks it
	}
	created := l.Since.IsZero()
	if created {
		l.Since = now.UTC().Truncate(time.Second)
	}
	if l.Files == nil {
		l.Files = map[string]Cursor{}
	}
	l.project, l.subscription, l.titles = projectorInfo(cache, labels), in.Subscription, labels
	l.admission = consent.Capture()
	l.cleared = LoadCleared(cache)
	changed := false
	for i := range l.Sessions {
		if !labels && (l.Sessions[i].ProjectLabel != "" || l.Sessions[i].Title != "") {
			l.Sessions[i].ProjectLabel, l.Sessions[i].Title, changed = "", "", true
		}
	}
	for i := range l.Live {
		if !labels && l.Live[i].ProjectLabel != "" {
			l.Live[i].ProjectLabel, changed = "", true
		}
	}
	if !f(&l) && !created && !changed && !oversize {
		return nil
	}
	roll := rollup(l.Rows, "") // before pruning, so days perf.json lets go are kept in daily-long.json
	b := l.prune(now)
	if b == nil {
		return nil // nothing fits under the load limit: keep the old file rather than write one the loader would refuse
	}
	if err := write(PerfPath(cache), b); err != nil {
		return err
	}
	return observeLong(cache, now, l.Since, roll)
}

func (l *PerfLedger) scan(path, source, parser string, p parser, now time.Time) bool {
	done, changed := scanLog(l.Files, path, source, p, now)
	thread := ""
	if source == "codex" {
		thread = codexThreadOfPath(path)
	}
	for _, t := range done {
		l.add(source, parser, t)
		if thread != "" {
			t.np.Thread = thread
		}
		l.addSession(fileKey(path), source, t)
	}
	return changed
}

// maxSessions: the sessions kept; the ones last active longest ago go first.
const maxSessions = 2000

func (l *PerfLedger) addSession(key, source string, t turn) {
	if t.at.IsZero() || t.at.Before(l.Since) || t.at.Before(l.start(source)) || len(t.all) == 0 {
		return
	}
	epoch := currentEpoch(l.admission, source)
	var s *PerfSession
	for i := range l.Sessions {
		if l.Sessions[i].Key == key && l.Sessions[i].Source == source && sameEpoch(l.Sessions[i].GrantEpoch, epoch) {
			s = &l.Sessions[i]
		}
	}
	start := t.at.UTC().Truncate(time.Minute)
	if s == nil {
		ref := newRef()
		for _, r := range l.Live {
			if r.Key == key && r.Source == source && sameEpoch(r.GrantEpoch, epoch) {
				ref = r.Ref
				break
			}
		}
		l.Sessions = append(l.Sessions, PerfSession{GrantEpoch: epoch, Ref: ref, Key: key, Source: source, FirstAt: start, LastAt: start})
		s = &l.Sessions[len(l.Sessions)-1]
	}
	if start.Before(s.FirstAt) {
		s.FirstAt = start
	}
	if s.SubscriptionRef == "" {
		s.SubscriptionRef = l.subscription
	}
	if (t.cwd != "" || t.np.ID != "" || t.np.Thread != "") && l.project != nil && (s.ProjectRule < projectRule || s.ProjectRef == "" || s.ProjectLabel == "" || s.ProjectKind == "") {
		// The first working directory names the project; a label comes once labels are on. A session recorded
		// under an older rule is recomputed once under the current one, dropping a guessed project.
		p := l.project(source, t.cwd, t.np)
		ref, label := p.Ref, p.Label
		if s.ProjectRule < projectRule {
			// macrevb-909-1: the live record of the same session carries the old guess too; it follows the
			// recomputed project at once instead of waiting for (or outliving) its next live observation.
			for i := range l.Live {
				if l.Live[i].Key == key && l.Live[i].Source == source && sameEpoch(l.Live[i].GrantEpoch, epoch) && l.Live[i].ProjectRef == s.ProjectRef {
					l.Live[i].ProjectRef, l.Live[i].ProjectLabel = ref, label
				}
			}
			s.ProjectRef, s.ProjectLabel, s.ProjectKind, s.ProjectRule = ref, label, p.Kind, projectRule
		} else if s.ProjectRef == "" {
			s.ProjectRef, s.ProjectLabel, s.ProjectKind = ref, label, p.Kind
		} else if ref == s.ProjectRef {
			s.ProjectLabel, s.ProjectKind = label, p.Kind
		}
	}
	if l.titles {
		title := t.np.Title
		if title == "" && source == "codex" && t.np.Thread != "" && s.Title == "" {
			title = l.codexTitle(t.np.Thread)
		}
		if title = cleanTitle(title); title != "" {
			s.Title = title
		}
	}
	d := day(t.at)
	for _, q := range t.all {
		if q.cfg.model == "" {
			continue
		}
		status := "reported"
		if q.cfg.effort == "" {
			status = "unreported"
		}
		var x *SessionDay
		for i := range s.Days {
			y := &s.Days[i]
			if y.Day == d && y.Model == q.cfg.model && y.EffortStatus == status && y.Effort == q.cfg.effort && y.Speed == q.cfg.speed {
				x = y
			}
		}
		if x == nil {
			s.Days = append(s.Days, SessionDay{Day: d, Model: q.cfg.model, EffortStatus: status, Effort: q.cfg.effort, Speed: q.cfg.speed})
			x = &s.Days[len(s.Days)-1]
		}
		if x.Kinds == nil {
			x.Kinds = &TokenKinds{}
		}
		x.Kinds.add(q.TokenKinds, x.ObservedRequests == 0)
		x.ObservedRequests++
		x.ObservedOutputTokens += q.out
		if e := q.end.UTC().Truncate(time.Minute); e.After(s.LastAt) {
			s.LastAt = e
		}
	}
	if e := t.at.Add(t.dur).UTC().Truncate(time.Minute); t.dur > 0 && e.After(s.LastAt) {
		s.LastAt = e
	}
}

// start: the earliest time a live turn of source counts from: its grant, or the tool's last clear.
func (l *PerfLedger) start(source string) time.Time {
	at := grantStart(l.admission, source)
	if f := l.cleared.floor(source); f.After(at) {
		at = f
	}
	return at
}

// newRef: a random reference, so a session is known here without any id of its own.
func newRef() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func (l *PerfLedger) add(source, parser string, t turn) {
	if t.at.IsZero() || t.at.Before(l.Since) || t.at.Before(l.start(source)) {
		return // started before the ledger did
	}
	l.addTurn(source, parser, t, true)
}

// addTurn counts one finished turn without the live ledger's start and grant checks; the history
// importer (import.go) uses it for turns that predate both. hourly: also feed the hourly view.
func (l *PerfLedger) addTurn(source, parser string, t turn, hourly bool) {
	d := day(t.at)
	for _, q := range t.all {
		if q.cfg.model == "" {
			continue
		}
		r := l.row(d, source, parser, q.cfg)
		r.TokenKinds.add(q.TokenKinds, r.ObservedRequests == 0)
		r.ObservedRequests++
		r.ObservedOutputTokens += q.out
		if hourly {
			l.addHourly(source, q, t.at)
		}
		if q.ttft > 0 && q.ttft <= maxTTFT {
			r.TTFTMs = r.TTFTMs.add(float64(q.ttft.Milliseconds()))
		}
		if q.eligible() {
			r.EligibleRequests++
			r.EligibleOutputTokens += q.out
			r.GenMs += q.gen.Milliseconds()
		}
		r.seen(q.end)
	}
	if t.cfg.model == "" {
		return
	}
	r := l.row(d, source, parser, t.cfg)
	if t.mixed {
		r.MixedConfigTurnsExcluded++
		return
	}
	if t.dur > 0 && t.dur <= maxTurn && len(t.reqs) > 0 {
		r.Turns++
		r.TurnMs += t.dur.Milliseconds()
		r.TurnOutputTokens += t.out
		r.TurnMsHist = r.TurnMsHist.add(float64(t.dur.Milliseconds()))
		r.TurnTokensHist = r.TurnTokensHist.add(float64(t.out))
		r.seen(t.at.Add(t.dur))
	}
}

func (r *PerfRow) seen(t time.Time) {
	if t.IsZero() {
		return
	}
	t = t.UTC().Truncate(time.Minute)
	if r.LastAt == nil || t.After(*r.LastAt) {
		r.LastAt = &t
	}
}

func (l *PerfLedger) row(d, source, parser string, c config) *PerfRow {
	epoch := currentEpoch(l.admission, source)
	status := "reported"
	if c.effort == "" {
		status = "unreported"
	}
	for i := range l.Rows {
		r := &l.Rows[i]
		if r.Day == d && r.Source == source && r.Model == c.model && r.EffortStatus == status && r.Effort == c.effort && r.Speed == c.speed &&
			r.Parser == parser && r.Eligibility == EligibilityV1 && sameEpoch(r.GrantEpoch, epoch) {
			return r
		}
	}
	l.Rows = append(l.Rows, PerfRow{GrantEpoch: epoch, Day: d, Source: source, Model: c.model, EffortStatus: status, Effort: c.effort, Speed: c.speed, Parser: parser, Eligibility: EligibilityV1})
	return &l.Rows[len(l.Rows)-1]
}

// prune keeps PerfKeep, at most maxRows rows and under writeLimit bytes (dropping the oldest days first),
// and returns the file's content, or nil when it cannot get under maxFile.
func (l *PerfLedger) prune(now time.Time) []byte {
	l.pruneLive(now)
	l.pruneHourly(now)
	from := day(now.Add(-PerfKeep))
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
	sessions := l.Sessions[:0]
	for _, x := range l.Sessions {
		days := x.Days[:0]
		for _, d := range x.Days {
			if d.Day >= from {
				days = append(days, d)
			}
		}
		if x.Days = days; len(days) > 0 {
			sessions = append(sessions, x)
		}
	}
	sort.SliceStable(sessions, func(i, j int) bool { return sessions[i].LastAt.Before(sessions[j].LastAt) })
	if len(sessions) > maxSessions {
		sessions = sessions[len(sessions)-maxSessions:]
	}
	// At most maxProjects projects: the ones last active longest ago lose their reference (their
	// sessions stay). A reference lives only on its sessions, so it goes with the last of them.
	seen := map[string]bool{}
	for i := len(sessions) - 1; i >= 0; i-- {
		x := &sessions[i]
		if x.ProjectRef == "" {
			continue
		}
		if !seen[x.ProjectRef] && len(seen) == maxProjects {
			x.ProjectRef, x.ProjectLabel = "", ""
			continue
		}
		seen[x.ProjectRef] = true
	}
	l.Sessions = sessions
	for k, c := range l.Files {
		if c.Seen < from {
			delete(l.Files, k)
		}
	}
	for k, c := range l.Stores {
		if c.Day < from {
			delete(l.Stores, k)
		}
	}
	// The encoded file is under writeLimit (maxFile minus a margin) whenever it can be, and never at or above maxFile (nil is
	// returned instead, and the caller keeps the old file), so the loader never refuses what this writes.
	// Shed order: whole oldest hourly days, the oldest rows and sessions, the hourly rows that are left (a derived view), then
	// counted requests. Cursors are not shed, see below.
	for {
		b, _ := json.Marshal(l)
		if len(b) < writeLimit {
			return append(b, '\n')
		}
		if h, ok := dropOldestHourlyDay(l.Hourly, now); ok {
			l.Hourly = h
			continue
		}
		if len(l.Rows) > 0 || len(l.Sessions) > 0 {
			l.Rows = l.Rows[len(l.Rows)/10:]
			l.Sessions = l.Sessions[len(l.Sessions)/10:]
			if len(l.Rows) < 10 && len(l.Sessions) < 10 {
				l.Rows, l.Sessions = nil, nil
			}
			continue
		}
		if len(l.Hourly) > 0 { // hourly is a derived view, so it can go down to none
			i := 1
			for i < len(l.Hourly) && l.Hourly[i].Hour == l.Hourly[0].Hour {
				i++
			}
			l.Hourly = l.Hourly[i:]
			continue
		}
		if len(l.Counted) > 0 {
			l.Counted = l.Counted[len(l.Counted)/10+1:]
			continue
		}
		// Cursors are never shed here: a cursor whose log can still be read again vouches for rows already counted, and losing it
		// would count that log twice. (The day pruning above already drops cursors older than every retained row.) Over writeLimit
		// but under maxFile the file is still written; at or over maxFile prune returns nil and the caller keeps the old file.
		if len(b) >= maxFile {
			return nil
		}
		return append(b, '\n')
	}
}

// projectRule is the current project attribution rule (see PerfSession.ProjectRule).
const projectRule = 2

// CompleteTotal is the day's total: input, cache reads, cache writes and output, each counted once (the ccusage
// definition; reasoning is part of output). It is unknown unless every part is, and never falls back to output alone.
func (d SessionDay) CompleteTotal() (int64, bool) {
	total := d.ObservedOutputTokens
	if total < 0 {
		return 0, false
	}
	if d.Kinds == nil {
		return 0, false
	}
	// The accounting total of every recorded request (TOK-50, ccusage-aligned) wins when it is known.
	if t := d.Kinds.TotalTokens; t != nil && *t >= 0 {
		return *t, true
	}
	for _, part := range []*int64{d.Kinds.InputTokens, d.Kinds.CacheReadTokens, d.Kinds.CacheWriteTokens} {
		if part == nil || *part < 0 || *part > math.MaxInt64-total {
			return 0, false
		}
		total += *part
	}
	return total, true
}

// maxTitle: the longest session title kept, in characters.
const maxTitle = 96

// cleanTitle: a tool's session title on one line, bounded. It is the tool's own generated or user-set title,
// never conversation content.
func cleanTitle(t string) string {
	t = strings.Join(strings.Fields(t), " ")
	if r := []rune(t); len(r) > maxTitle {
		t = string(r[:maxTitle-1]) + "…"
	}
	return t
}
