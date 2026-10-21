// Package history keeps, on this machine only, how much of each usage window the user ended up
// using and under which configuration (model, effort, Fast) the points were spent. It is the
// basis for suggesting a default effort from the user's own past cycles; nothing in it leaves
// the machine. It holds no prompts, projects, tokens or session ids: only window meters and the
// harness's model and effort, which the quota snapshot already holds.
//
// The ledger is <cache>/observed/cycles.json; the pace ledger, pace.json (pace.go), is kept from
// the same readings beside it. MODELPLAN_HISTORY=off stops both; deleting a file clears it.
package history

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

// Ledger is the file's content.
type Ledger struct {
	SchemaVersion int     `json:"schemaVersion"`
	Cycles        []Cycle `json:"cycles"`
}

// Cycle is one window from one reset to the next, as observed here.
type Cycle struct {
	Source        string    `json:"source"` // claude-code | codex
	Plan          string    `json:"plan,omitempty"`
	Limit         string    `json:"limit,omitempty"`
	Kind          string    `json:"kind"`
	WindowMinutes int       `json:"windowMinutes,omitempty"`
	ResetsAt      time.Time `json:"resetsAt"`
	// FirstAt/FirstUsed: the first reading of this cycle here; points used before it are
	// unattributed (the cycle started before we watched, or on another machine).
	FirstAt   time.Time `json:"firstAt"`
	FirstUsed float64   `json:"firstUsed"`
	// LastAt/LastUsed: the latest reading that moved the meter; LastUsed is the cycle's use so far,
	// its final use once ResetsAt has passed.
	LastAt   time.Time `json:"lastAt"`
	LastUsed float64   `json:"lastUsed"`
	HitLimit bool      `json:"hitLimit,omitempty"`
	// Spent: the points of each rise, attributed to the configuration of the reading that saw it.
	Spent []Share `json:"spent,omitempty"`
}

// Share is the points one configuration spent in a cycle.
type Share struct {
	Model  string  `json:"model,omitempty"`  // as the harness reports it; "" when unknown
	Effort string  `json:"effort,omitempty"` // "" = the harness default
	Fast   bool    `json:"fast,omitempty"`
	Points float64 `json:"points"`
}

// Done: the cycle's reset has passed, so LastUsed is its final use.
func (c Cycle) Done(now time.Time) bool { return !c.ResetsAt.After(now) }

const (
	keepFiveHour = 28 * 24 * time.Hour
	keepLonger   = 84 * 24 * time.Hour
	maxCycles    = 600
	lockStale    = 10 * time.Second
)

// Path is the ledger file.
func Path(cache string) string { return filepath.Join(cache, "observed", "cycles.json") }

// Off: the user turned recording off.
func Off() bool { return os.Getenv("MODELPLAN_HISTORY") == "off" }

// Load never fails: a missing or unreadable ledger is empty.
func Load(cache string) Ledger {
	l := Ledger{SchemaVersion: 1}
	b, err := os.ReadFile(Path(cache))
	if err != nil || len(b) > 1<<20 {
		return l
	}
	var on Ledger
	if json.Unmarshal(b, &on) == nil && on.SchemaVersion == 1 {
		l.Cycles = on.Cycles
	}
	return l
}

// Observe adds the harness windows of a report to the ledger, and to the pace ledger beside it. A
// rise since the cycle's last reading is attributed to the configuration in use now. When
// another process holds the ledger the reading is skipped: the next one counts the same rise,
// since it starts from LastUsed.
func Observe(cache string, r quota.Report, now time.Time) error {
	if Off() {
		return nil
	}
	return errors.Join(observe(cache, r, now), observePace(cache, r, now))
}

func observe(cache string, r quota.Report, now time.Time) error {
	unlock, ok := lockNamed(cache, "cycles.lock")
	if !ok {
		return nil
	}
	defer unlock()
	l := Load(cache)
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
	if !changed {
		return nil
	}
	l.prune(now)
	b, _ := json.MarshalIndent(l, "", " ")
	return write(Path(cache), append(b, '\n'))
}

func (l *Ledger) add(a *quota.Account, w quota.Window) bool {
	if w.UsedPercent == nil || w.ResetsAt == nil || w.ObservedAt.IsZero() || w.Kind == "unknown" || w.Kind == "spend" || !w.ResetsAt.After(w.ObservedAt) {
		return false
	}
	used := *w.UsedPercent
	c := l.find(a, w)
	if c == nil {
		l.Cycles = append(l.Cycles, Cycle{Source: a.Source, Plan: a.Plan, Limit: w.Limit, Kind: w.Kind, WindowMinutes: w.WindowMinutes, ResetsAt: w.ResetsAt.UTC(),
			FirstAt: w.ObservedAt.UTC().Truncate(time.Second), FirstUsed: used, LastAt: w.ObservedAt.UTC().Truncate(time.Second), LastUsed: used, HitLimit: used >= 100})
		return true
	}
	// An older reading (another thread's) or a meter that did not move adds nothing.
	if !w.ObservedAt.After(c.LastAt) || used <= c.LastUsed {
		return false
	}
	c.spend(config(a), used-c.LastUsed)
	c.LastAt, c.LastUsed = w.ObservedAt.UTC().Truncate(time.Second), used
	c.HitLimit = c.HitLimit || used >= 100
	return true
}

// find: the cycle of this window, matched on its reset (within the jitter of a computed time).
func (l *Ledger) find(a *quota.Account, w quota.Window) *Cycle {
	for i := range l.Cycles {
		c := &l.Cycles[i]
		d := c.ResetsAt.Sub(*w.ResetsAt)
		if c.Source == a.Source && c.Limit == w.Limit && c.Kind == w.Kind && c.WindowMinutes == w.WindowMinutes && d < 2*time.Minute && d > -2*time.Minute {
			return c
		}
	}
	return nil
}

func config(a *quota.Account) Share {
	h := a.Harness
	if h == nil {
		return Share{}
	}
	return Share{Model: h.Model, Effort: h.Effort, Fast: (h.FastMode != nil && *h.FastMode) || h.ServiceTier == "fast"}
}

func (c *Cycle) spend(s Share, points float64) {
	for i := range c.Spent {
		x := &c.Spent[i]
		if x.Model == s.Model && x.Effort == s.Effort && x.Fast == s.Fast {
			x.Points = round1(x.Points + points)
			return
		}
	}
	s.Points = round1(points)
	c.Spent = append(c.Spent, s)
}

func round1(v float64) float64 {
	if v < 0 {
		return -round1(-v)
	}
	return float64(int64(v*10+0.5)) / 10
}

func (l *Ledger) prune(now time.Time) {
	kept := l.Cycles[:0]
	for _, c := range l.Cycles {
		keep := keepLonger
		if c.Kind == "five_hour" {
			keep = keepFiveHour
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

func lockNamed(cache, name string) (func(), bool) {
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
	f, err := os.CreateTemp(filepath.Dir(p), ".cycles-*")
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
