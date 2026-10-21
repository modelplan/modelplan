package history

import (
	"encoding/json"
	"errors"
	"math"
	"os"
	"path/filepath"
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

// The pace ledger, <cache>/observed/pace.json, keeps how fast each window's percentage rose, as
// evidence for later advice. It runs beside cycles.json, which is not changed and never mixed in:
// every reading that counts is kept (at most one unchanged reading per paceThrottle), so the
// observed span and its gaps are known; a drop under the same reset (a reset card, a correction)
// starts a new segment instead of being ignored; and a rise seen only after a gap longer than the
// window's gap limit is not credited to any configuration. Points stay percentage points: they
// are never converted to tokens, nor tokens to points.

// PaceCycle is one window from one reset to the next, as watched here since the ledger started.
type PaceCycle struct {
	Source        string `json:"source"` // claude-code | codex
	Plan          string `json:"plan,omitempty"`
	Limit         string `json:"limit,omitempty"`
	Kind          string `json:"kind"`
	WindowMinutes int    `json:"windowMinutes,omitempty"`
	// LengthBasis: how the window's length is known. reported: the source gives it (Codex's
	// window_minutes); field-name: the source's field names it (Claude Code's five_hour and
	// seven_day); "" unknown, and then no coverage is given.
	LengthBasis     string    `json:"lengthBasis,omitempty"`
	ResetsAt        time.Time `json:"resetsAt"`
	FirstObservedAt time.Time `json:"firstObservedAt"`
	FirstUsed       float64   `json:"firstUsed"`
	LastObservedAt  time.Time `json:"lastObservedAt"`
	LastUsed        float64   `json:"lastUsed"`
	Readings        int       `json:"readings"`
	// Gaps between consecutive readings longer than the window's gap limit.
	GapCount      int `json:"gapCount"`
	MaxGapMinutes int `json:"maxGapMinutes"`
	// Drops: falls of the meter under the same reset; each starts a new segment.
	Drops int `json:"drops"`
	// Points: every rise observed; GapPoints the part seen only after a gap (configuration
	// unknown). Spent: the rest, by the configuration of the reading that saw it.
	Points    float64 `json:"points"`
	GapPoints float64 `json:"gapPoints"`
	Spent     []Share `json:"spent,omitempty"`
}

type PaceLedger struct {
	SchemaVersion int         `json:"schemaVersion"`
	Since         time.Time   `json:"since"`
	Cycles        []PaceCycle `json:"cycles"`
}

const (
	paceKeepFiveHour = 35 * 24 * time.Hour
	paceKeepLonger   = 84 * 24 * time.Hour
	paceThrottle     = 2 * time.Minute
	paceMaxFile      = 1 << 20
	// PaceMinCycles: closed cycles needed before a rate is shown. An engineering threshold for
	// showing a number, not proof that it is reliable enough to advise from.
	PaceMinCycles = 2
	paceShown     = 10 // cycles per group in the snapshot, newest first
)

// GapLimit: a rise seen after a longer silence than this is not credited to the configuration of
// the reading that saw it.
func GapLimit(kind string) time.Duration {
	switch kind {
	case "five_hour":
		return time.Hour
	case "monthly":
		return 24 * time.Hour
	}
	return 6 * time.Hour
}

func PacePath(cache string) string { return filepath.Join(cache, "observed", "pace.json") }

// LoadPace reads the ledger: a missing file is a new one (zero Since); ok is false for a file
// that is there but cannot be used, which is then left alone.
func LoadPace(cache string) (l PaceLedger, ok bool) {
	b, err := os.ReadFile(PacePath(cache))
	if errors.Is(err, os.ErrNotExist) {
		return PaceLedger{SchemaVersion: 1}, true
	}
	if err != nil || len(b) > paceMaxFile {
		return PaceLedger{}, false
	}
	if json.Unmarshal(b, &l) != nil || l.SchemaVersion != 1 || l.Since.IsZero() {
		return PaceLedger{}, false
	}
	return l, true
}

func observePace(cache string, r quota.Report, now time.Time) error {
	unlock, ok := lockNamed(cache, "pace.lock")
	if !ok {
		return nil
	}
	defer unlock()
	l, ok := LoadPace(cache)
	if !ok {
		return nil
	}
	created := l.Since.IsZero()
	if created {
		l.Since = now.UTC().Truncate(time.Second)
	}
	changed := false
	for i := range r.Accounts {
		a := &r.Accounts[i]
		if a.Source != "claude-code" && a.Source != "codex" {
			continue
		}
		for _, w := range a.Windows {
			changed = l.add(a, w) || changed
		}
	}
	if !changed && !created {
		return nil
	}
	l.prune(now)
	b, _ := json.Marshal(l)
	return write(PacePath(cache), append(b, '\n'))
}

func lengthBasis(source, kind string) string {
	switch {
	case source == "codex":
		return "reported"
	case source == "claude-code" && (kind == "five_hour" || kind == "weekly"):
		return "field-name"
	}
	return ""
}

func (l *PaceLedger) add(a *quota.Account, w quota.Window) bool {
	if w.UsedPercent == nil || w.ResetsAt == nil || w.ObservedAt.IsZero() || w.Kind == "unknown" || w.Kind == "spend" ||
		!w.ResetsAt.After(w.ObservedAt) || w.ObservedAt.Before(l.Since) {
		return false
	}
	used, at := *w.UsedPercent, w.ObservedAt.UTC().Truncate(time.Second)
	c := l.find(a, w)
	if c == nil {
		l.Cycles = append(l.Cycles, PaceCycle{Source: a.Source, Plan: a.Plan, Limit: w.Limit, Kind: w.Kind, WindowMinutes: w.WindowMinutes,
			LengthBasis: lengthBasis(a.Source, w.Kind), ResetsAt: w.ResetsAt.UTC(), FirstObservedAt: at, FirstUsed: used, LastObservedAt: at, LastUsed: used, Readings: 1})
		return true
	}
	gap := at.Sub(c.LastObservedAt)
	if gap <= 0 || (used == c.LastUsed && gap < paceThrottle) {
		return false
	}
	if gap > GapLimit(w.Kind) {
		c.GapCount++
	}
	if m := int(gap.Minutes()); m > c.MaxGapMinutes && gap > GapLimit(w.Kind) {
		c.MaxGapMinutes = m
	}
	switch d := used - c.LastUsed; {
	case d < 0:
		c.Drops++ // later rises count from here
	case d > 0 && gap > GapLimit(w.Kind):
		c.Points, c.GapPoints = round1(c.Points+d), round1(c.GapPoints+d)
	case d > 0:
		c.Points = round1(c.Points + d)
		s := config(a)
		found := false
		for i := range c.Spent {
			x := &c.Spent[i]
			if x.Model == s.Model && x.Effort == s.Effort && x.Fast == s.Fast {
				x.Points, found = round1(x.Points+d), true
			}
		}
		if !found {
			s.Points = round1(d)
			c.Spent = append(c.Spent, s)
		}
	}
	c.LastObservedAt, c.LastUsed = at, used
	c.Readings++
	return true
}

func (l *PaceLedger) find(a *quota.Account, w quota.Window) *PaceCycle {
	for i := range l.Cycles {
		c := &l.Cycles[i]
		d := c.ResetsAt.Sub(*w.ResetsAt)
		if c.Source == a.Source && c.Plan == a.Plan && c.Limit == w.Limit && c.Kind == w.Kind && c.WindowMinutes == w.WindowMinutes && d < 2*time.Minute && d > -2*time.Minute {
			return c
		}
	}
	return nil
}

func (l *PaceLedger) prune(now time.Time) {
	kept := l.Cycles[:0]
	for _, c := range l.Cycles {
		keep := paceKeepLonger
		if c.Kind == "five_hour" {
			keep = paceKeepFiveHour
		}
		if now.Sub(c.ResetsAt) <= keep {
			kept = append(kept, c)
		}
	}
	sort.SliceStable(kept, func(i, j int) bool { return kept[i].ResetsAt.Before(kept[j].ResetsAt) })
	if len(kept) > maxCycles {
		kept = kept[len(kept)-maxCycles:]
	}
	l.Cycles = kept
}

// PaceCycleView is one cycle in the snapshot.
type PaceCycleView struct {
	ResetsAt        time.Time `json:"resetsAt"`
	Closed          bool      `json:"closed"` // the reset passed; LastUsed is the last reading, not a final one
	FirstObservedAt time.Time `json:"firstObservedAt"`
	FirstUsed       float64   `json:"firstUsed"`
	LastObservedAt  time.Time `json:"lastObservedAt"`
	LastUsed        float64   `json:"lastUsed"`
	Readings        int       `json:"readings"`
	SpanMinutes     int       `json:"spanMinutes"`
	// Coverage: the span against the window's length, when the source gives the length; the span
	// is not sampling coverage, and gaps are reported apart.
	Coverage      *float64 `json:"coverage"`
	GapCount      int      `json:"gapCount"`
	MaxGapMinutes int      `json:"maxGapMinutes"`
	Drops         int      `json:"drops"`
	HadDrop       bool     `json:"hadDrop"`
	Points        float64  `json:"points"`
	GapPoints     float64  `json:"gapPoints"`
	Spent         []Share  `json:"spent"`
	// SpentBasis: the points are credited to the configuration of the reading that saw the rise.
	SpentBasis string `json:"spentBasis"`
}

// PaceGroup is one window of one account and plan. Two accounts on the same plan are not told
// apart, so every group is unattributed and not for personal advice by account.
type PaceGroup struct {
	Source        string `json:"source"`
	Plan          string `json:"plan,omitempty"`
	Limit         string `json:"limit,omitempty"`
	Kind          string `json:"kind"`
	WindowMinutes int    `json:"windowMinutes,omitempty"`
	Attribution   string `json:"attribution"`
	// ValidCycles: closed cycles without a drop and with a span, the basis of the rate.
	ClosedCycles int `json:"closedCycles"`
	ValidCycles  int `json:"validCycles"`
	// ObservedIntervalRatePerHour: points per hour over the observed spans of the valid cycles,
	// idle time inside them included: an average over watched intervals, not a burn rate while
	// working. Set only when Status is ok.
	ObservedIntervalRatePerHour *float64        `json:"observedIntervalRatePerHour"`
	Status                      string          `json:"status"` // ok | insufficient | off | unavailable
	Reason                      string          `json:"reason,omitempty"`
	Min                         int             `json:"min"`
	Cycles                      []PaceCycleView `json:"cycles"`
}

// PaceView projects the pace ledger for the snapshot.
type PaceView struct {
	Ledger    PaceLedger
	OK        bool
	Recording bool
	Now       time.Time
}

// PaceHistory is the snapshot's paceHistory: the ledger's start, its state and the groups.
type PaceHistory struct {
	Since *time.Time `json:"since"`
	// Status: ok | off (recording is off) | unavailable (reason ledger-unreadable).
	Status string `json:"status"`
	Reason string `json:"reason,omitempty"`
	// GapLimitMinutes: per window kind, the silence after which a rise is not credited.
	GapLimitMinutes map[string]int `json:"gapLimitMinutes"`
	Groups          []PaceGroup    `json:"groups"`
}

func (v PaceView) History() PaceHistory {
	h := PaceHistory{Status: "ok", Groups: v.Groups(), GapLimitMinutes: map[string]int{}}
	for _, k := range []string{"five_hour", "weekly", "monthly"} {
		h.GapLimitMinutes[k] = int(GapLimit(k).Minutes())
	}
	switch {
	case !v.OK:
		h.Status, h.Reason = "unavailable", "ledger-unreadable"
	case !v.Recording:
		h.Status = "off"
	}
	if v.OK && !v.Ledger.Since.IsZero() {
		t := v.Ledger.Since
		h.Since = &t
	}
	return h
}

func (v PaceView) Groups() []PaceGroup {
	out := []PaceGroup{}
	if !v.OK {
		return out
	}
	type key struct {
		source, plan, limit, kind string
		minutes                   int
	}
	by := map[key][]PaceCycle{}
	var keys []key
	for _, c := range v.Ledger.Cycles {
		k := key{c.Source, c.Plan, c.Limit, c.Kind, c.WindowMinutes}
		if _, ok := by[k]; !ok {
			keys = append(keys, k)
		}
		by[k] = append(by[k], c)
	}
	sort.Slice(keys, func(i, j int) bool {
		a, b := keys[i], keys[j]
		if a.source != b.source {
			return a.source < b.source
		}
		if a.plan != b.plan {
			return a.plan < b.plan
		}
		if a.limit != b.limit {
			return a.limit < b.limit
		}
		return a.minutes < b.minutes
	})
	for _, k := range keys {
		g := PaceGroup{Source: k.source, Plan: k.plan, Limit: k.limit, Kind: k.kind, WindowMinutes: k.minutes, Attribution: "unattributed", Min: PaceMinCycles, Cycles: []PaceCycleView{}}
		var points, hours float64
		cs := by[k]
		sort.SliceStable(cs, func(i, j int) bool { return cs[i].ResetsAt.After(cs[j].ResetsAt) })
		for _, c := range cs {
			cv := view(c, v.Now)
			if cv.Closed {
				g.ClosedCycles++
				if !cv.HadDrop && cv.SpanMinutes > 0 {
					g.ValidCycles++
					points += c.Points
					hours += c.LastObservedAt.Sub(c.FirstObservedAt).Hours()
				}
			}
			if len(g.Cycles) < paceShown {
				g.Cycles = append(g.Cycles, cv)
			}
		}
		switch {
		case !v.Recording:
			g.Status = "off"
		case g.ValidCycles < PaceMinCycles:
			g.Status = "insufficient"
		default:
			x := math.Round(points/hours*100) / 100
			g.Status, g.ObservedIntervalRatePerHour = "ok", &x
		}
		out = append(out, g)
	}
	return out
}

func view(c PaceCycle, now time.Time) PaceCycleView {
	span := int(c.LastObservedAt.Sub(c.FirstObservedAt).Minutes())
	v := PaceCycleView{ResetsAt: c.ResetsAt, Closed: !c.ResetsAt.After(now), FirstObservedAt: c.FirstObservedAt, FirstUsed: c.FirstUsed, LastObservedAt: c.LastObservedAt,
		LastUsed: c.LastUsed, Readings: c.Readings, SpanMinutes: span, GapCount: c.GapCount, MaxGapMinutes: c.MaxGapMinutes, Drops: c.Drops, HadDrop: c.Drops > 0,
		Points: c.Points, GapPoints: c.GapPoints, Spent: c.Spent, SpentBasis: "reading-time-heuristic"}
	if v.Spent == nil {
		v.Spent = []Share{}
	}
	if c.LengthBasis != "" && c.WindowMinutes > 0 {
		x := math.Round(float64(span)/float64(c.WindowMinutes)*1000) / 1000
		v.Coverage = &x
	}
	return v
}

// Boundaries: open cycles closing at their reset.
func (v PaceView) Boundaries() []time.Time {
	var out []time.Time
	for _, c := range v.Ledger.Cycles {
		if c.ResetsAt.After(v.Now) {
			out = append(out, c.ResetsAt)
		}
	}
	return out
}
