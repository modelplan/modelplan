package speed

import (
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const LiveWithin = 5 * time.Minute
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
}
type liveSample struct {
	At       time.Time `json:"at"`
	Out      int64     `json:"out"`
	GenMs    int64     `json:"genMs"`
	Eligible bool      `json:"eligible"`
}

// LiveRecord is bounded local observation state, not a public session identifier.
type LiveRecord struct {
	Key             string       `json:"key"`
	Ref             string       `json:"ref"`
	Source          string       `json:"source"`
	Model           string       `json:"model"`
	Effort          string       `json:"effort"`
	Speed           string       `json:"speed"`
	ProjectRef      string       `json:"projectRef,omitempty"`
	SubscriptionRef string       `json:"subscriptionRef,omitempty"`
	StartedAt       time.Time    `json:"startedAt"`
	LastAt          time.Time    `json:"lastAt"`
	Running         bool         `json:"running"`
	Samples         []liveSample `json:"samples,omitempty"`
}

// LiveSession contains only local opaque references, configuration and timing evidence.
type LiveSession struct {
	Ref             string    `json:"ref"`
	Source          string    `json:"source"`
	Model           string    `json:"model"`
	Effort          string    `json:"effort"`
	EffortStatus    string    `json:"effortStatus"`
	Speed           string    `json:"speed"`
	ProjectRef      *string   `json:"projectRef"`
	SubscriptionRef *string   `json:"subscriptionRef"`
	StartedAt       time.Time `json:"startedAt"`
	LastAt          time.Time `json:"lastAt"`
	Status          string    `json:"status"`
	Rate            Rate      `json:"rate"`
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
// separate Claude subagent files. It follows no symlinks, visits at most 20,000 entries per root,
// and returns at most 64 newest logs changed in the last five minutes. Each read is a 256 KiB tail.
func ActiveLogs(claudeHome, codexHome string, now time.Time) []LiveLog {
	type candidate struct {
		log LiveLog
		at  time.Time
	}
	var all []candidate
	for _, root := range []struct{ dir, source string }{{filepath.Join(claudeHome, "projects"), "claude-code"}, {filepath.Join(codexHome, "sessions"), "codex"}} {
		if !filepath.IsAbs(root.dir) {
			continue
		}
		if (root.source == "claude-code" && claudeHome == "") || (root.source == "codex" && codexHome == "") {
			continue
		}
		visited := 0
		_ = filepath.WalkDir(root.dir, func(path string, d fs.DirEntry, err error) error {
			visited++
			if visited > 20000 {
				return fs.SkipAll
			}
			if err != nil || d.IsDir() || d.Type()&os.ModeSymlink != 0 || !strings.HasSuffix(path, ".jsonl") {
				return nil
			}
			fi, e := d.Info()
			if e != nil || !fi.Mode().IsRegular() || fi.ModTime().Before(now.Add(-LiveWithin)) {
				return nil
			}
			all = append(all, candidate{LiveLog{Path: path, Source: root.source, Sidechain: filepath.Base(filepath.Dir(path)) == "subagents"}, fi.ModTime()})
			return nil
		})
	}
	sort.Slice(all, func(i, j int) bool {
		if all[i].at.Equal(all[j].at) {
			return all[i].log.Path < all[j].log.Path
		}
		return all[i].at.After(all[j].at)
	})
	out := []LiveLog{}
	for i, c := range all {
		if i == maxLive {
			break
		}
		out = append(out, c.log)
	}
	return out
}

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
				scanLog(files, log.Path, p, now)
				x = p.probe
			case "codex":
				p := newCodex()
				p.liveOnly = true
				scanLog(files, log.Path, p, now)
				x = p.probe
			default:
				continue
			}
			changed = l.setLive(fileKey(log.Path), log.Source, x, subscriptions[log.Source], now) || changed
		}
		return changed
	})
}
func (l *PerfLedger) setLive(key, source string, x liveProbe, subscription string, now time.Time) bool {
	if x.cfg.model == "" || x.last.IsZero() || !x.last.After(now.Add(-LiveWithin)) || x.last.After(now) || x.start.IsZero() {
		return false
	}
	r := LiveRecord{Key: key, Ref: newRef(), Source: source, Model: clip(x.cfg.model), Effort: clip(x.cfg.effort), Speed: speedMode(x.cfg.speed), StartedAt: x.start.UTC(), LastAt: x.last.UTC(), Running: x.running, SubscriptionRef: subscription}
	for _, s := range l.Sessions {
		if s.Key == key && s.Source == source {
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
		if old.Key == key && old.Source == source {
			at = i
			r.Ref = old.Ref
			if old.StartedAt.Before(r.StartedAt) {
				r.StartedAt = old.StartedAt
			}
			if r.ProjectRef == "" {
				r.ProjectRef = old.ProjectRef
			}
			if r.SubscriptionRef == "" {
				r.SubscriptionRef = old.SubscriptionRef
			}
			break
		}
	}
	if r.ProjectRef == "" && x.cwd != "" && l.project != nil {
		r.ProjectRef, _ = l.project(x.cwd)
	}
	for _, q := range x.requests {
		if q.cfg != x.cfg || q.end.After(now) || !q.end.After(now.Add(-LiveRateWindow)) {
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
		if r.LastAt.After(now.Add(-LiveWithin)) && !r.LastAt.After(now) {
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
	for _, r := range v.Ledger.Live {
		if !r.LastAt.After(v.Now.Add(-LiveWithin)) || r.LastAt.After(v.Now) {
			continue
		}
		x := LiveSession{Ref: r.Ref, Source: r.Source, Model: r.Model, Effort: r.Effort, EffortStatus: "unreported", Speed: r.Speed, StartedAt: r.StartedAt, LastAt: r.LastAt, Status: "idle", ProjectRef: refOrNil(r.ProjectRef), SubscriptionRef: refOrNil(r.SubscriptionRef)}
		if r.Effort != "" {
			x.EffortStatus = "reported"
		}
		if r.Running {
			x.Status = "running"
		}
		rate := Rate{Source: r.Source, Window: "60s", Scope: "session", Min: MinSamples, Status: "insufficient", Reason: "too-few-samples"}
		var output, gen int64
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
			if s.Eligible {
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
	return out
}
