package speed

import (
	"sort"
	"time"
)

const (
	LiveWithin     = 5 * time.Minute
	maxLive        = 256
	maxLiveSamples = 128
)

// LiveRecord is short-lived local state, separate from completed-turn history. Key is hashed;
// samples carry only a local offset-derived key, counts, configuration and timestamps.
type LiveRecord struct {
	Ref             string       `json:"ref"`
	Key             string       `json:"key"`
	Source          string       `json:"source"`
	Model           string       `json:"model"`
	Effort          string       `json:"effort"`
	Speed           string       `json:"speed"`
	ProjectRef      string       `json:"projectRef,omitempty"`
	SubscriptionRef string       `json:"subscriptionRef,omitempty"`
	StartedAt       time.Time    `json:"startedAt"`
	LastAt          time.Time    `json:"lastAt"`
	Running         bool         `json:"running"`
	Samples         []LiveSample `json:"samples,omitempty"`
}
type LiveSample struct {
	Key      string    `json:"key"`
	End      time.Time `json:"end"`
	Model    string    `json:"model"`
	Effort   string    `json:"effort"`
	Speed    string    `json:"speed"`
	Out      int64     `json:"out"`
	GenMs    int64     `json:"genMs"`
	Eligible bool      `json:"eligible"`
}
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
type sessionSignal struct {
	start, last time.Time
	cfg         config
	running     bool
	cwd         string
	reqs        []request
}

func completedSignals(ts []turn) []sessionSignal {
	out := []sessionSignal{}
	for _, t := range ts {
		out = append(out, sessionSignal{start: t.at, last: t.at.Add(t.dur), cfg: t.cfg, cwd: t.cwd, reqs: t.all})
	}
	return out
}

// finish captures the provisional state before the regular parser discards an unfinished turn.
// Such samples can power a live gauge but do not advance the completed-turn ledger's cursor.
type liveParser struct {
	parser
	ledger      *PerfLedger
	key, source string
	now         time.Time
}

func (p *liveParser) finish() ([]turn, int64) {
	if s, ok := p.parser.(interface{ signals() []sessionSignal }); ok {
		for _, x := range s.signals() {
			p.ledger.signal(p.key, p.source, x, p.now)
		}
	}
	return p.parser.finish()
}
func (l *PerfLedger) signal(key, source string, x sessionSignal, now time.Time) {
	if x.start.IsZero() || x.last.IsZero() || x.last.Before(now.Add(-LiveWithin)) || x.last.After(now) {
		return
	}
	var r *LiveRecord
	for i := range l.Live {
		if l.Live[i].Key == key && l.Live[i].Source == source {
			r = &l.Live[i]
			break
		}
	}
	if r == nil {
		ref := newRef()
		for _, s := range l.Sessions {
			if s.Key == key && s.Source == source {
				ref = s.Ref
				break
			}
		}
		l.Live = append(l.Live, LiveRecord{Ref: ref, Key: key, Source: source, StartedAt: x.start.UTC()})
		r = &l.Live[len(l.Live)-1]
	}
	if x.start.Before(r.StartedAt) {
		r.StartedAt = x.start.UTC()
	}
	if !x.last.Before(r.LastAt) {
		r.LastAt = x.last.UTC()
		r.Model, r.Effort, r.Speed = x.cfg.model, x.cfg.effort, x.cfg.speed
		r.Running = x.running
	}
	if r.ProjectRef == "" && x.cwd != "" && l.project != nil {
		r.ProjectRef, _ = l.project(x.cwd)
	}
	// Only a binding actually observed by ingestion, never guessed from a model/provider.
	if r.SubscriptionRef == "" {
		r.SubscriptionRef = l.subscription
	}
	for _, q := range x.reqs {
		if q.end.Before(now.Add(-time.Minute)) || q.end.After(now) {
			continue
		}
		sample := LiveSample{Key: q.key, End: q.end.UTC(), Model: q.cfg.model, Effort: q.cfg.effort, Speed: q.cfg.speed, Out: q.out, GenMs: q.gen.Milliseconds(), Eligible: q.eligible()}
		found := false
		for i := range r.Samples {
			if r.Samples[i].Key == sample.Key {
				r.Samples[i] = sample
				found = true
				break
			}
		}
		if !found {
			r.Samples = append(r.Samples, sample)
		}
	}
}
func (l *PerfLedger) pruneLive(now time.Time) {
	kept := l.Live[:0]
	for _, r := range l.Live {
		if r.LastAt.Before(now.Add(-LiveWithin)) || r.LastAt.After(now) {
			continue
		}
		ss := r.Samples[:0]
		for _, q := range r.Samples {
			if !q.End.Before(now.Add(-time.Minute)) && !q.End.After(now) {
				ss = append(ss, q)
			}
		}
		sort.SliceStable(ss, func(i, j int) bool { return ss[i].End.Before(ss[j].End) })
		if len(ss) > maxLiveSamples {
			ss = ss[len(ss)-maxLiveSamples:]
		}
		r.Samples = ss
		kept = append(kept, r)
	}
	sort.SliceStable(kept, func(i, j int) bool { return kept[i].LastAt.Before(kept[j].LastAt) })
	if len(kept) > maxLive {
		kept = kept[len(kept)-maxLive:]
	}
	l.Live = kept
}
func (v PerfView) LiveSessions() []LiveSession {
	out := []LiveSession{}
	if !v.OK || !v.Recording {
		return out
	}
	for _, r := range v.Ledger.Live {
		if r.LastAt.Before(v.Now.Add(-LiveWithin)) || r.LastAt.After(v.Now) {
			continue
		}
		x := LiveSession{Ref: r.Ref, Source: r.Source, Model: r.Model, Effort: r.Effort, EffortStatus: "unreported", Speed: r.Speed, ProjectRef: refOrNil(r.ProjectRef), SubscriptionRef: refOrNil(r.SubscriptionRef), StartedAt: r.StartedAt, LastAt: r.LastAt, Status: "idle"}
		if r.Effort != "" {
			x.EffortStatus = "reported"
		}
		if r.Running {
			x.Status = "running"
		}
		var n, observed int
		var tokens, ms int64
		var last *time.Time
		for _, q := range r.Samples {
			if q.End.Before(v.Now.Add(-time.Minute)) || q.End.After(v.Now) || q.Model != r.Model || q.Effort != r.Effort || q.Speed != r.Speed {
				continue
			}
			observed++
			if last == nil || q.End.After(*last) {
				t := q.End
				last = &t
			}
			if q.Eligible {
				n++
				tokens += q.Out
				ms += q.GenMs
			}
		}
		m := v.metric(n, observed, func() float64 { return tps(tokens, ms) }, last)
		if m.Status == "insufficient" {
			m.Reason = "too-few-samples"
		}
		x.Rate = Rate{Source: r.Source, Window: "60s", Scope: "session-configuration", Value: m.Value, Status: m.Status, N: m.N, Min: m.Min, Reason: m.Reason, LastAt: last}
		out = append(out, x)
	}
	sort.SliceStable(out, func(i, j int) bool {
		if !out[i].LastAt.Equal(out[j].LastAt) {
			return out[i].LastAt.After(out[j].LastAt)
		}
		return out[i].Ref < out[j].Ref
	})
	return out
}
