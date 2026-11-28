package speed

import (
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/logindex"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"sync/atomic"
	"time"
)

// LiveWithin is how recently a log must have changed to be tailed, and how long a turn can read as
// running. It does not decide how long a finished session stays listed (D277: idle sessions read "6m
// ago"); LiveIdleKeep and LiveIdleMax do.
const LiveWithin = 5 * time.Minute

// LiveIdleKeep and LiveIdleMax: idle sessions stay listed, newest first, up to LiveIdleMax within LiveIdleKeep.
const LiveIdleKeep = 24 * time.Hour
const LiveIdleMax = 5
const LiveRateWindow = time.Minute
const maxLive = 64
const liveTail = 256 << 10

// LiveLog names a local log to inspect. Paths never leave the parser or its hashed cursor key.
type LiveLog struct {
	Path, Source string
	Sidechain    bool
}
type liveProbe struct {
	cfg         config
	start, last time.Time
	running     bool
	requests    []request
	cwd         string
	np          nativeProject
}
type liveSample struct {
	At       time.Time `json:"at"`
	Out      int64     `json:"out"`
	GenMs    int64     `json:"genMs"`
	Eligible bool      `json:"eligible"`
}

// LiveRecord is bounded local observation state, not a public session identifier.
type LiveRecord struct {
	GrantEpoch      *GrantEpoch   `json:"grantEpoch,omitempty"`
	Activity        *TurnActivity `json:"activity,omitempty"`
	Key             string        `json:"key"`
	Ref             string        `json:"ref"`
	Source          string        `json:"source"`
	Model           string        `json:"model"`
	Effort          string        `json:"effort"`
	Speed           string        `json:"speed"`
	ProjectRef      string        `json:"projectRef,omitempty"`
	ProjectLabel    string        `json:"projectLabel,omitempty"` // only while project labels are on
	SubscriptionRef string        `json:"subscriptionRef,omitempty"`
	StartedAt       time.Time     `json:"startedAt"`
	LastAt          time.Time     `json:"lastAt"`
	Running         bool          `json:"running"`
	Samples         []liveSample  `json:"samples,omitempty"`
}

// LiveSession contains only local opaque references, configuration and timing evidence.
type LiveSession struct {
	Activity        *TurnActivity `json:"activity,omitempty"`
	Ref             string        `json:"ref"`
	Source          string        `json:"source"`
	Model           string        `json:"model"`
	Effort          string        `json:"effort"`
	EffortStatus    string        `json:"effortStatus"`
	Speed           string        `json:"speed"`
	ProjectRef      *string       `json:"projectRef"`
	ProjectLabel    string        `json:"projectLabel,omitempty"`
	SubscriptionRef *string       `json:"subscriptionRef"`
	StartedAt       time.Time     `json:"startedAt"`
	LastAt          time.Time     `json:"lastAt"`
	Status          string        `json:"status"`
	Rate            Rate          `json:"rate"`
	// InProgress is true while a turn is open: the parser reports one running, or an unexpired activity record says
	// so. It can stay true after Status reads "idle" (activity expiry without a completion event). Totals read from
	// the completed-turn ledger would undercount then, so consumers use this, never the Status word.
	InProgress bool `json:"-"`
}

// turnOpen is the one definition of "a turn is in progress" for a live record at now (macrevb-1024-1).
func (r LiveRecord) turnOpen(now time.Time) bool {
	if r.Running {
		return true
	}
	return r.Activity != nil && r.Activity.Phase != "finished" && now.Before(r.Activity.ExpiresAt)
}

func (p *claudeParser) liveProbe() liveProbe {
	turns := append([]turn(nil), p.done...)
	if p.cur != nil {
		turns = append(turns, ccAsTurn(p.cur))
	}
	x := probeTurns(turns)
	if t := p.cur; t != nil {
		if len(t.reqs) == 0 {
			x.cfg = config{}
		}
		x.running = !t.ended
		x.last = later(x.last, later(t.trigger, t.at))
		x.cwd = t.cwd
	}
	return x
}
func (p *codexParser) liveProbe() liveProbe {
	turns := append([]turn(nil), p.done...)
	if t := p.cur; t != nil {
		qs := append([]request(nil), t.reqs...)
		for i := range qs {
			qs[i].cfg = t.cfg
		}
		turns = append(turns, turn{cfg: t.cfg, at: t.at, all: qs, cwd: t.cwd})
	}
	x := probeTurns(turns)
	if t := p.cur; t != nil {
		x.running = true
		x.cfg = t.cfg
		x.last = later(x.last, t.start)
		x.cwd = t.cwd
	}
	return x
}
func probeTurns(turns []turn) liveProbe {
	x := liveProbe{}
	for _, t := range turns {
		if x.start.IsZero() || t.at.Before(x.start) {
			x.start = t.at
		}
		x.last = later(x.last, t.at.Add(t.dur))
		if t.cfg.model != "" {
			x.cfg = t.cfg
		}
		if t.cwd != "" {
			x.cwd = t.cwd
		}
		for _, q := range t.all {
			x.last = later(x.last, q.end)
			x.requests = append(x.requests, q)
		}
	}
	return x
}

// ActiveLogs discovers only regular JSONL files under the harness's history roots, including
// separate Claude subagent files. It follows no symlinks, keeps at most 20,000 entries per root,
// and returns at most 64 newest logs changed in the last five minutes. Each read is a 256 KiB tail.
func ActiveLogs(claudeHome, codexHome string, now time.Time) []LiveLog {
	return ActiveLogsIn(nil, consent.Fence{}, logindex.Ticket{}, claudeHome, codexHome, now)
}

// ActiveLogsIn is ActiveLogs from the app-server's shared history inventory, under the caller's
// consent fence and the withdrawal ticket it took with it; a nil inventory scans afresh.
func ActiveLogsIn(inv *logindex.Inventory, fence consent.Fence, ticket logindex.Ticket, claudeHome, codexHome string, now time.Time) []LiveLog {
	if inv == nil {
		inv = &logindex.Inventory{}
	}
	return recentLogsCached(inv, fence, []liveRoot{{filepath.Join(claudeHome, "projects"), "claude-code", claudeHome != ""}, {filepath.Join(codexHome, "sessions"), "codex", codexHome != ""}}, now, now, nil, ticket)
}

type liveRoot struct {
	dir, source string
	enabled     bool
}

// ActivityLogs shares the existing bounded discovery with the ZCode lifecycle root.
func ActivityLogs(claudeHome, codexHome, zcodeHome string, now time.Time) []LiveLog {
	return recentLogs(&logindex.Inventory{}, consent.Fence{}, activityRoots(claudeHome, codexHome, zcodeHome), now, now)
}
func activityRoots(claudeHome, codexHome, zcodeHome string) []liveRoot {
	return []liveRoot{{filepath.Join(claudeHome, "projects"), "claude-code", claudeHome != ""},
		{filepath.Join(codexHome, "sessions"), "codex", codexHome != ""},
		{filepath.Join(zcodeHome, "cli", "log"), "zcode", zcodeHome != ""}}
}

// recentLogs: the newest (at most 64) logs under the enabled roots changed in the last five
// minutes, from the inventory's metadata.
func recentLogs(inv *logindex.Inventory, fence consent.Fence, roots []liveRoot, now, elapsed time.Time) []LiveLog {
	return recentLogsCached(inv, fence, roots, now, elapsed, nil, logindex.Ticket{})
}

// liveCandidate is a log changed within LiveWithin of when its selection was made.
type liveCandidate struct {
	log LiveLog
	at  time.Time
}

// liveSelection caches the candidates selected at an inventory generation. The window only moves
// forward with now, so the candidates of an unchanged inventory stay a superset of the logs
// that are still recent, and each tick filters only them (#1222 sampling P2).
type liveSelection struct {
	gen   uint64
	want  []logindex.Root
	fence consent.Fence
	built time.Time
	cands []liveCandidate
}

func recentLogsCached(inv *logindex.Inventory, fence consent.Fence, roots []liveRoot, now, elapsed time.Time, c *liveSelection, ticket logindex.Ticket) []LiveLog {
	var want []logindex.Root
	for _, root := range roots {
		if root.enabled && filepath.IsAbs(root.dir) {
			want = append(want, logindex.Root{Dir: root.dir, Source: root.source})
		}
	}
	if len(want) == 0 {
		// Every source withdrawn (or the consent store unavailable): a withdrawal. Forget the
		// cached selection and the roots it came from, and record it, so a read or commit under
		// a ticket from before it is refused (macrev2-1261-2).
		var dirs []string
		if c != nil {
			for _, r := range c.want {
				dirs = append(dirs, r.Dir)
			}
			*c = liveSelection{}
		}
		inv.Withdraw(dirs...)
		return []LiveLog{}
	}
	have := uint64(0)
	if c != nil && c.gen != 0 && c.fence == fence && slices.Equal(c.want, want) && !now.Before(c.built) {
		have = c.gen
	}
	files, gen, changed := inv.FilesIfChanged(fence, want, now, elapsed, have, ticket)
	if changed && gen == 0 { // refused: a withdrawal since the ticket; keep nothing
		return []LiveLog{}
	}
	var cands []liveCandidate
	if changed {
		for _, f := range files {
			if f.Mod.Before(now.Add(-LiveWithin)) {
				continue
			}
			cands = append(cands, liveCandidate{LiveLog{Path: f.Path, Source: f.Source, Sidechain: filepath.Base(filepath.Dir(f.Path)) == "subagents"}, f.Mod})
		}
		sort.Slice(cands, func(i, j int) bool {
			if cands[i].at.Equal(cands[j].at) {
				return cands[i].log.Path < cands[j].log.Path
			}
			return cands[i].at.After(cands[j].at)
		})
		if c != nil {
			next := liveSelection{gen: gen, want: want, fence: fence, built: now, cands: cands}
			// Under the lock Withdraw takes: a withdrawal since the ticket drops the result.
			if !inv.CommitIf(ticket, func() { *c = next }) {
				return []LiveLog{}
			}
		} else if !inv.CommitIf(ticket, func() {}) {
			return []LiveLog{}
		}
	} else {
		cands = c.cands
	}
	// Newest first: the first expired candidate ends the recent ones, so a tick visits at most
	// maxLive+1 of them however many have aged out under an unchanged inventory (macrev2-1261-1).
	out := []LiveLog{}
	for _, cand := range cands {
		liveCandidateVisits.Add(1)
		if len(out) == maxLive || cand.at.Before(now.Add(-LiveWithin)) {
			break
		}
		out = append(out, cand.log)
	}
	return out
}

// liveCandidateVisits counts cached candidates visited by the activity selection (tests).
var liveCandidateVisits atomic.Int64

// ObserveLive reads only bounded local log tails. It neither adds historical token counts nor
// asks an account endpoint. Existing normal observations provide subscription references.
func ObserveLive(cache string, logs []LiveLog, labels bool, subscriptions map[string]string, now time.Time) error {
	return observePerf(cache, now, Ingest{Labels: labels}, func(l *PerfLedger) bool {
		changed := false
		for i, log := range logs {
			if i == maxLive {
				break
			}
			fi, err := os.Stat(log.Path)
			if err != nil || !fi.Mode().IsRegular() {
				continue
			}
			files := map[string]Cursor{fileKey(log.Path): {Offset: max(0, fi.Size()-liveTail), Seen: day(now)}}
			var x liveProbe
			switch log.Source {
			case "claude-code":
				p := newClaude(now)
				p.sidechains = log.Sidechain
				scanLog(files, log.Path, log.Source, p, now)
				x = p.probe
			case "codex":
				p := newCodex()
				p.liveOnly = true
				scanLog(files, log.Path, log.Source, p, now)
				x = p.probe
			default:
				continue
			}
			changed = l.setLive(fileKey(log.Path), log.Source, x, subscriptions[log.Source], now) || changed
			// Reuse the decisive lifecycle parser without changing token/rate eligibility.
			if verdicts, err := readActivityTail(log, fi, now); err == nil && len(verdicts) == 1 && !verdicts[0].RecordAt.Before(l.start(log.Source)) {
				for j := range l.Live {
					if l.Live[j].Key == fileKey(log.Path) && l.Live[j].Source == log.Source && sameEpoch(l.Live[j].GrantEpoch, currentEpoch(l.admission, log.Source)) {
						v := verdicts[0].TurnActivity
						l.Live[j].Activity = &v
					}
				}
			}
		}
		return changed
	})
}
func (l *PerfLedger) setLive(key, source string, x liveProbe, subscription string, now time.Time) bool {
	start := l.start(source)
	if x.cfg.model == "" || autoReview(x.cfg.model) || x.last.IsZero() || x.last.Before(start) || !x.last.After(now.Add(-LiveWithin)) || x.last.After(now) || x.start.IsZero() {
		return false
	}
	r := LiveRecord{GrantEpoch: currentEpoch(l.admission, source), Key: key, Ref: newRef(), Source: source, Model: clip(x.cfg.model), Effort: clip(x.cfg.effort), Speed: speedMode(x.cfg.speed), StartedAt: x.start.UTC(), LastAt: x.last.UTC(), Running: x.running, SubscriptionRef: subscription}
	recorded := false // the recorded session is the authority on its project, even when it has none
	for _, s := range l.Sessions {
		if s.Key == key && s.Source == source && sameEpoch(s.GrantEpoch, r.GrantEpoch) {
			recorded = true
			r.Ref = s.Ref
			r.ProjectRef = s.ProjectRef
			r.SubscriptionRef = s.SubscriptionRef
			if s.FirstAt.Before(r.StartedAt) {
				r.StartedAt = s.FirstAt
			}
			break
		}
	}
	at := -1
	for i, old := range l.Live {
		if old.Key == key && old.Source == source && sameEpoch(old.GrantEpoch, r.GrantEpoch) {
			at = i
			r.Ref = old.Ref
			if old.StartedAt.Before(r.StartedAt) {
				r.StartedAt = old.StartedAt
			}
			// macrevb-909-1: a session the tool's own rule moved to no project must not get back the old
			// live record's guess; only a live record with no recorded session keeps its earlier project.
			if r.ProjectRef == "" && !recorded {
				r.ProjectRef = old.ProjectRef
			}
			if r.SubscriptionRef == "" {
				r.SubscriptionRef = old.SubscriptionRef
			}
			break
		}
	}
	if (x.cwd != "" || x.np.ID != "") && l.project != nil {
		ref, label := l.project(source, x.cwd, x.np)
		if r.ProjectRef == "" {
			r.ProjectRef = ref
		}
		if ref == r.ProjectRef {
			r.ProjectLabel = label
		}
	}
	for _, q := range x.requests {
		if q.cfg != x.cfg || q.end.Before(start) || q.end.After(now) || !q.end.After(now.Add(-LiveRateWindow)) {
			continue
		}
		r.Samples = append(r.Samples, liveSample{At: q.end.UTC(), Out: q.out, GenMs: q.gen.Milliseconds(), Eligible: q.eligible()})
	}
	if len(r.Samples) > 256 {
		r.Samples = r.Samples[len(r.Samples)-256:]
	}
	if at < 0 {
		l.Live = append(l.Live, r)
	} else {
		l.Live[at] = r
	}
	return true
}
func (l *PerfLedger) pruneLive(now time.Time) {
	kept := l.Live[:0]
	for _, r := range l.Live {
		if autoReview(r.Model) {
			continue // a record cached before the auto-review rule
		}
		if r.LastAt.After(now.Add(-LiveIdleKeep)) && !r.LastAt.After(now) {
			if !r.LastAt.After(now.Add(-LiveWithin)) {
				r.Running, r.Activity = false, nil // a kept idle session never reads as running
			}
			kept = append(kept, r)
		}
	}
	sort.Slice(kept, func(i, j int) bool { return kept[i].LastAt.After(kept[j].LastAt) })
	if len(kept) > maxLive {
		kept = kept[:maxLive]
	}
	for len(kept) > 0 {
		b, _ := json.Marshal(kept)
		if len(b) <= 512<<10 {
			break
		}
		kept = kept[:len(kept)*9/10]
	}
	l.Live = kept
}
func (v PerfView) LiveSessions() []LiveSession {
	out := []LiveSession{}
	if !v.OK || !v.Recording {
		return out
	}
	recs := slices.Clone(v.Ledger.Live)
	sort.SliceStable(recs, func(i, j int) bool { return recs[i].LastAt.After(recs[j].LastAt) })
	for _, r := range recs {
		// A record cached before the auto-review rule is never published (the model is not a session).
		if autoReview(r.Model) || r.LastAt.After(v.Now) || !r.LastAt.After(v.Now.Add(-LiveIdleKeep)) {
			continue
		}
		if !r.LastAt.After(v.Now.Add(-LiveWithin)) {
			r.Running, r.Activity = false, nil // past the live window: idle by definition
		}
		x := LiveSession{Ref: r.Ref, Source: r.Source, Model: r.Model, Effort: r.Effort, EffortStatus: "unreported", Speed: r.Speed, StartedAt: r.StartedAt, LastAt: r.LastAt, Status: "idle", ProjectRef: refOrNil(r.ProjectRef), ProjectLabel: r.ProjectLabel, SubscriptionRef: refOrNil(r.SubscriptionRef), InProgress: r.turnOpen(v.Now)}
		if r.Effort != "" {
			x.EffortStatus = "reported"
		}
		if r.Running {
			x.Status = "running"
		}
		if r.Activity != nil {
			a := *r.Activity
			if !v.Now.Before(a.ExpiresAt) {
				a.Phase = "finished"
			}
			x.Activity = &a
			x.LastAt = a.RecordAt
			if a.Phase == "finished" {
				x.Status = "idle"
			} else {
				x.Status = "running"
			}
		}
		rate := Rate{Source: r.Source, Window: "60s", Scope: "session", Min: MinSamples, Status: "insufficient", Reason: "too-few-samples"}
		var output, gen int64
		const maxInt64 = int64(^uint64(0) >> 1)
		observed := 0
		for _, s := range r.Samples {
			if !s.At.After(v.Now.Add(-LiveRateWindow)) || s.At.After(v.Now) {
				continue
			}
			observed++
			if rate.LastAt == nil || s.At.After(*rate.LastAt) {
				t := s.At
				rate.LastAt = &t
			}
			// Cached eligibility is not proof that the persisted numbers are
			// valid. Skip non-positive or overflowing samples before summing.
			if s.Eligible && s.Out > 0 && s.GenMs > 0 && s.Out <= maxInt64-output && s.GenMs <= maxInt64-gen {
				rate.N++
				output += s.Out
				gen += s.GenMs
			}
		}
		if rate.N >= MinSamples && gen > 0 {
			n := tps(output, gen)
			rate.Value = &n
			rate.Status = "ok"
			rate.Reason = ""
		} else if observed > 0 && rate.N == 0 {
			rate.Status = "unavailable"
			rate.Reason = "no-eligible-generation"
		}
		x.Rate = rate
		out = append(out, x)
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].LastAt.Equal(out[j].LastAt) {
			return out[i].Ref < out[j].Ref
		}
		return out[i].LastAt.After(out[j].LastAt)
	})
	// Running rows are never cut; only the newest LiveIdleMax idle rows stay, however recently they finished.
	idle := 0
	kept := out[:0]
	for _, x := range out {
		if x.Status != "running" {
			if idle == LiveIdleMax {
				continue
			}
			idle++
		}
		kept = append(kept, x)
	}
	return kept
}
