// Package quota reads the user's own usage windows from files the harnesses already write
// on this machine: Codex session logs, the Claude Code status-line snapshot that
// `modelplan statusline` records, the user-maintained local.json and, for providers the user
// enabled, CodexBar's reading (codexbar.go) or a native reader's (quota_native.go: the vendor's
// usage endpoint, with an API key the user keeps in an environment variable, sent only to that
// vendor). It never opens credential files, and nothing it reads leaves the machine. Which account a
// meter belongs to is kept only as a random local reference (identity.go).
package quota

import (
	"encoding/json"
	"math"
	"sort"
	"strconv"
	"strings"
	"time"
)

// Window is one usage window as last observed, plus values derived at evaluation time.
type Window struct {
	Kind          string     `json:"kind"` // five_hour | weekly | monthly | spend | unknown
	Limit         string     `json:"limit,omitempty"`
	UsedPercent   *float64   `json:"usedPercent"`
	WindowMinutes int        `json:"windowMinutes,omitempty"`
	ResetsAt      *time.Time `json:"resetsAt"`
	ResetMode     string     `json:"resetMode,omitempty"` // fixed | rolling | unknown; harness windows are fixed
	ObservedAt    time.Time  `json:"observedAt"`
	UsedUSD       *float64   `json:"usedUsd,omitempty"`
	LimitUSD      *float64   `json:"limitUsd,omitempty"`

	RemainingPercent *float64 `json:"remainingPercent"`
	ResetsInMinutes  *int     `json:"resetsInMinutes"`
	ElapsedPercent   *float64 `json:"elapsedPercent"`   // share of the window already elapsed
	ProjectedPercent *float64 `json:"projectedPercent"` // share used at reset if the current pace holds
	AgeMinutes       *int     `json:"ageMinutes"`
	// RecentPercentPerHour: how fast the window filled over the last readings (up to 45 minutes,
	// at least 10), in percentage points per hour; nil without enough fresh readings.
	RecentPercentPerHour *float64 `json:"recentPercentPerHour"`
	// RunsOutInMinutes: when the window is used up at that rate, only when that comes before its reset.
	RunsOutInMinutes *int   `json:"runsOutInMinutes"`
	Pace             string `json:"pace"` // exhausted | tight | on_track | surplus | reset_passed | unknown

	recent []Sample // earlier readings of this window in its current cycle, oldest first
}

// Sample is one earlier reading of a window, kept to measure the recent rate of use.
type Sample struct {
	At       time.Time  `json:"at"`
	Used     float64    `json:"used"`
	ResetsAt *time.Time `json:"resetsAt,omitempty"`
}

// The recent rate looks back up to recentLook over at least recentMinSpan, from a reading no older
// than recentFresh (an idle harness has no recent rate), and projects a run-out only from a rise of
// recentMinRise points or more (meters move in whole points).
const (
	recentLook    = 45 * time.Minute
	recentMinSpan = 10 * time.Minute
	recentFresh   = 10 * time.Minute
	recentMinRise = 2.0
)

// RunsOutTight: a run-out at the recent rate within this many minutes, before the reset, makes a
// window tight.
const RunsOutTight = 180

// Harness is what the harness itself reported about the session, when it did.
// For Codex the reading comes from one thread's log: attribution says which (current-thread when
// the caller named it, else recent-thread, the newest interactive thread on this machine), and
// observedAt when that thread last reported it. An empty effort means the turn context named none.
type Harness struct {
	Model       string     `json:"model,omitempty"`
	Effort      string     `json:"effort,omitempty"`
	FastMode    *bool      `json:"fastMode,omitempty"`
	Version     string     `json:"version,omitempty"`
	ServiceTier string     `json:"serviceTier,omitempty"`
	ObservedAt  *time.Time `json:"observedAt,omitempty"`
	Attribution string     `json:"attribution,omitempty"` // current-thread | recent-thread
	Origin      string     `json:"origin,omitempty"`      // cli, vscode, exec, …
	Endpoint    string     `json:"endpoint,omitempty"`    // Claude Code: ANTHROPIC_BASE_URL (scheme, host, path) when set
}

type Card struct {
	Kind      string     `json:"kind"`
	Count     *int       `json:"count"`
	ExpiresAt *time.Time `json:"expiresAt"`
}

// Credits: the balance as the harness reported it, without account ids. Balance is nil when
// the harness sent none (unlimited, or an older reader).
type Credits struct {
	Unlimited  bool      `json:"unlimited,omitempty"`
	Balance    *float64  `json:"balance,omitempty"`
	ObservedAt time.Time `json:"observedAt"`
	AgeMinutes *int      `json:"ageMinutes,omitempty"`
}

// CreditsFresh: a balance read this recently is quoted without its age.
const CreditsFresh = 15 * time.Minute

// creditsFrom: has, unlimited and balance as sent (a decimal string, a number or null). Nil
// when the account has no credits.
func creditsFrom(has, unlimited bool, balance json.RawMessage, at time.Time) *Credits {
	if !has && !unlimited {
		return nil
	}
	c := &Credits{Unlimited: unlimited, ObservedAt: at.UTC()}
	raw := strings.Trim(strings.TrimSpace(string(balance)), `"`)
	if v, err := strconv.ParseFloat(raw, 64); err == nil && v >= 0 && v < 1e12 {
		c.Balance = &v
	}
	if c.Balance == nil && !unlimited {
		return nil // credits with no figure tell the user nothing they can check
	}
	return c
}

// Account groups the windows one subscription reports; Claude Code and Codex are separate accounts.
type Account struct {
	Source     string    `json:"source"` // claude-code | codex | user | codexbar:<provider>
	Plan       string    `json:"plan,omitempty"`
	Generation string    `json:"generation,omitempty"` // user: the plan's metering generation, as declared
	ObservedAt time.Time `json:"observedAt"`
	Stale      bool      `json:"stale"`
	Harness    *Harness  `json:"harness,omitempty"`
	Windows    []Window  `json:"windows"`
	Cards      []Card    `json:"cards,omitempty"`
	// Subscription: the account the windows belong to, when a reader saw it (identity.go).
	Subscription *Binding `json:"subscription,omitempty"`
	// Credits: the account's usage credits (Codex: bought or granted), which the harness draws on
	// once a plan window is used up. Unlike cards they restore no window.
	Credits  *Credits `json:"credits,omitempty"`
	Via      string   `json:"via,omitempty"` // codex-account: windows from Codex's account reading, not only the logs; codexbar: read by CodexBar
	Headroom string   `json:"headroom"`      // spend | normal | conserve | exhausted | unknown
	Deciding string   `json:"deciding,omitempty"`
	// Pool: the allowance the session draws from when the account keeps more than one. Codex
	// meters some models from their own allowance under another limit id (GPT Reserve is a weekly
	// pool of its own, limit "reserve"); "" is the main one. Headroom and Deciding are the pool's.
	Pool string `json:"pool,omitempty"`
}

// InPool: the window meters the account's pool. An account without a window of its pool keeps
// every window.
func (a *Account) InPool(w *Window) bool {
	if w.Limit == a.Pool {
		return true
	}
	for i := range a.Windows {
		if a.Windows[i].Limit == a.Pool {
			return false
		}
	}
	return true
}

type SourceStatus struct {
	Source string `json:"source"`
	Status string `json:"status"` // ok | missing | empty | invalid | unreadable | unsafe_path | too_large | unsupported_schema; CodexBar also: stale | estimated | unavailable
	Reason string `json:"reason,omitempty"`
}

type Report struct {
	SchemaVersion int            `json:"schemaVersion"`
	EvaluatedAt   time.Time      `json:"evaluatedAt"`
	Accounts      []Account      `json:"accounts"`
	Sources       []SourceStatus `json:"sources"`
	Note          string         `json:"note"`
}

const note = "Local observations only, read from files on this machine; never sent anywhere. Percentages are the harness's own usage meters, not token or task counts. Pace and headroom are estimates that assume the recent rate of use continues."

// staleAfter: a harness meter older than this may have moved; advice should say so.
const staleAfter = 60 * time.Minute

var defaultMinutes = map[string]int{"five_hour": 300, "weekly": 10080, "monthly": 43200}

// Paths lets tests point every reader at a temporary tree.
type Paths struct {
	Cache, CodexHome, LocalFile string
	CodexBarFile                string // ~/.config/modelplan/codexbar.json: providers read through CodexBar
	ConnectionsFile             string // ~/.config/modelplan/connections.json: which backend reads each provider
	CodexThread                 string // the calling Codex thread, when known (CODEX_THREAD_ID)
	ClaudeSession               string // the calling Claude Code session, when known
}

// Read gathers every available source and evaluates it at now.
func Read(p Paths, now time.Time) Report {
	r := Report{SchemaVersion: 1, EvaluatedAt: now.UTC(), Note: note, Accounts: []Account{}}
	add := func(a []Account, st SourceStatus) {
		r.Accounts = append(r.Accounts, a...)
		r.Sources = append(r.Sources, st)
	}
	add(readClaudeCode(p.Cache, p.ClaudeSession))
	add(readCodex(p.CodexHome, p.CodexThread))
	add(readLocal(p.LocalFile, now))
	if p.CodexHome != "" {
		applyAccount(&r, p.Cache, now)
	}
	applyCodexBar(&r, p, now)
	applyNative(&r, p, now)
	for i := range r.Accounts {
		Evaluate(&r.Accounts[i], now)
	}
	return r
}

// Evaluate fills the derived fields and the account's headroom.
func Evaluate(a *Account, now time.Time) {
	a.Stale = !a.ObservedAt.IsZero() && now.Sub(a.ObservedAt) > staleAfter
	for i := range a.Windows {
		evalWindow(&a.Windows[i], now)
	}
	var pool []Window
	for i := range a.Windows {
		if a.InPool(&a.Windows[i]) {
			pool = append(pool, a.Windows[i])
		}
	}
	a.Headroom, a.Deciding = headroom(pool)
	if c := a.Credits; c != nil {
		age := int(math.Max(0, now.Sub(c.ObservedAt).Minutes()))
		c.AgeMinutes = &age
	}
}

// Boundaries: the instants at which Evaluate gives the account other verdicts from the same
// readings, only because the clock passed them: it goes stale, a window resets, its recent rate
// lapses, or its elapsed share crosses a pace threshold (a tenth, a fifth, a half, the last
// quarter, or where the projection passes 100% or 60%). Past instants are included; callers filter.
func Boundaries(a *Account) []time.Time {
	var out []time.Time
	if !a.ObservedAt.IsZero() {
		out = append(out, a.ObservedAt.Add(staleAfter))
	}
	if c := a.Credits; c != nil {
		out = append(out, c.ObservedAt.Add(CreditsFresh))
	}
	for i := range a.Windows {
		w := &a.Windows[i]
		if w.UsedPercent == nil || w.ResetsAt == nil {
			continue
		}
		out = append(out, *w.ResetsAt)
		if !w.ObservedAt.IsZero() {
			out = append(out, w.ObservedAt.Add(recentFresh))
		}
		length := w.WindowMinutes
		if length == 0 {
			length = defaultMinutes[w.Kind]
		}
		if length == 0 || w.ResetMode == "rolling" {
			continue
		}
		used := *w.UsedPercent
		for _, e := range []float64{0.1, 0.2, 0.5, 0.75, used / 100, used / 60} {
			if e > 0 && e < 1 {
				out = append(out, w.ResetsAt.Add(-time.Duration((1-e)*float64(length)*float64(time.Minute))))
			}
		}
	}
	return out
}

func round1(v float64) *float64 { x := math.Round(v*10) / 10; return &x }

func evalWindow(w *Window, now time.Time) {
	w.RemainingPercent, w.ResetsInMinutes, w.ElapsedPercent, w.ProjectedPercent, w.AgeMinutes = nil, nil, nil, nil, nil
	w.RecentPercentPerHour, w.RunsOutInMinutes = nil, nil
	if !w.ObservedAt.IsZero() {
		age := int(math.Max(0, now.Sub(w.ObservedAt).Minutes()))
		w.AgeMinutes = &age
	}
	if w.WindowMinutes == 0 {
		w.WindowMinutes = defaultMinutes[w.Kind]
	}
	w.Pace = "unknown"
	if w.UsedPercent == nil {
		return
	}
	used := *w.UsedPercent
	w.RemainingPercent = round1(math.Max(0, 100-used))
	if w.ResetsAt != nil {
		in := w.ResetsAt.Sub(now)
		if in <= 0 {
			// The meter was read before this reset; current usage is unknown (usually low again).
			w.Pace = "reset_passed"
			w.RemainingPercent = nil
			return
		}
		m := int(math.Ceil(in.Minutes()))
		w.ResetsInMinutes = &m
	}
	if used >= 100 {
		w.Pace = "exhausted"
		return
	}
	if w.ResetsAt == nil || w.WindowMinutes == 0 || w.ResetMode == "rolling" {
		if used >= 90 {
			w.Pace = "tight"
		}
		return
	}
	length := float64(w.WindowMinutes)
	left := float64(*w.ResetsInMinutes)
	elapsed := math.Max(0, math.Min(1, 1-left/length))
	w.ElapsedPercent = round1(elapsed * 100)
	if elapsed >= 0.1 {
		w.ProjectedPercent = round1(used / elapsed)
	}
	recentRate(w, now)
	switch {
	// Early in a window the projection is noisy, so it alone decides only after a fifth of it; a
	// window already half used that is on pace to run out is tight however early it is. A recent
	// burst that runs it out within three hours, before the reset, is tight whatever the average.
	case used >= 90 || (w.ProjectedPercent != nil && *w.ProjectedPercent > 100 && (elapsed >= 0.2 || used >= 50)) ||
		(w.RunsOutInMinutes != nil && *w.RunsOutInMinutes <= RunsOutTight):
		w.Pace = "tight"
	case 100-used >= 30 && (left <= length*0.25 || (w.ProjectedPercent != nil && *w.ProjectedPercent <= 60 && elapsed >= 0.5)):
		w.Pace = "surplus"
	default:
		w.Pace = "on_track"
	}
}

// recentRate: the rate between the oldest reading within recentLook of the latest one and the
// latest, for readings of the same cycle (a reset in between starts the count again).
func recentRate(w *Window, now time.Time) {
	if w.UsedPercent == nil || w.ResetsAt == nil || w.ObservedAt.IsZero() || now.Sub(w.ObservedAt) > recentFresh {
		return
	}
	base := Sample{At: w.ObservedAt, Used: *w.UsedPercent}
	for _, s := range w.recent {
		if sameCycle(s.ResetsAt, w.ResetsAt) && !s.At.After(w.ObservedAt) && w.ObservedAt.Sub(s.At) <= recentLook && s.At.Before(base.At) {
			base = s
		}
	}
	span := w.ObservedAt.Sub(base.At)
	rise := *w.UsedPercent - base.Used
	if span < recentMinSpan || rise < 0 {
		return
	}
	rate := rise / span.Hours()
	w.RecentPercentPerHour = round1(rate)
	if rise < recentMinRise || *w.UsedPercent >= 100 || w.ResetsInMinutes == nil {
		return
	}
	// Counted from the latest reading, which may be a few minutes old.
	out := int(math.Ceil((100-*w.UsedPercent)/rate*60 - now.Sub(w.ObservedAt).Minutes()))
	if out < 1 {
		out = 1
	}
	if out < *w.ResetsInMinutes {
		w.RunsOutInMinutes = &out
	}
}

// sameCycle: two readings name the same reset, within the jitter of a computed reset time.
func sameCycle(a, b *time.Time) bool {
	if a == nil || b == nil {
		return false
	}
	d := a.Sub(*b)
	return d < 2*time.Minute && d > -2*time.Minute
}

// History is kept for recentKeep, one sample per sampleEvery at most.
const (
	recentKeep  = time.Hour
	sampleEvery = 2 * time.Minute
)

// withHistory is w, which replaces older, keeping older's readings (and older itself) as samples.
func withHistory(w, older Window) Window {
	rec := append(append([]Sample(nil), older.recent...), w.recent...)
	if s, ok := older.sampleOf(); ok {
		rec = append(rec, s)
	}
	w.recent = thin(rec, w)
	return w
}

// thin: the samples of w's cycle within recentKeep before its reading, oldest first, at most one
// per sampleEvery.
func thin(ss []Sample, w Window) []Sample {
	var in []Sample
	for _, s := range ss {
		if sameCycle(s.ResetsAt, w.ResetsAt) && s.At.Before(w.ObservedAt) && w.ObservedAt.Sub(s.At) <= recentKeep {
			in = append(in, s)
		}
	}
	sort.SliceStable(in, func(i, j int) bool { return in[i].At.Before(in[j].At) })
	var out []Sample
	for _, s := range in {
		if len(out) == 0 || s.At.Sub(out[len(out)-1].At) >= sampleEvery {
			out = append(out, s)
		}
	}
	return out
}

// addSample appends a reading to a window's history: the readers attach what they kept.
func (w *Window) addSample(s Sample) { w.recent = append(w.recent, s) }

// sampleOf is the window's own reading as a sample.
func (w Window) sampleOf() (Sample, bool) {
	if w.UsedPercent == nil || w.ObservedAt.IsZero() {
		return Sample{}, false
	}
	return Sample{At: w.ObservedAt, Used: *w.UsedPercent, ResetsAt: w.ResetsAt}, true
}

// headroom: an exhausted or tight window decides (longest window first). Spending more is
// suggested only when a window will end with allowance left and no window is near its limit.
func headroom(ws []Window) (string, string) {
	sorted := append([]Window(nil), ws...)
	sort.SliceStable(sorted, func(i, j int) bool { return sorted[i].WindowMinutes > sorted[j].WindowMinutes })
	for _, p := range [][2]string{{"exhausted", "exhausted"}, {"tight", "conserve"}} {
		for _, w := range sorted {
			if w.Pace == p[0] {
				return p[1], w.Kind
			}
		}
	}
	spend, known := "", false
	for _, w := range sorted {
		switch w.Pace {
		case "surplus":
			known = true
			if spend == "" {
				spend = w.Kind
			}
		case "on_track":
			known = true
			if w.ProjectedPercent == nil || *w.ProjectedPercent > 80 {
				return "normal", w.Kind
			}
		}
	}
	switch {
	case spend != "":
		return "spend", spend
	case known:
		return "normal", ""
	}
	return "unknown", ""
}

func unixTime(v *int64) *time.Time {
	if v == nil || *v <= 0 {
		return nil
	}
	t := time.Unix(*v, 0).UTC()
	return &t
}

func finite(v *float64, lo, hi float64) *float64 {
	if v == nil || math.IsNaN(*v) || math.IsInf(*v, 0) || *v < lo || *v > hi {
		return nil
	}
	return v
}

func marshal(v any) []byte {
	b, _ := json.MarshalIndent(v, "", "  ")
	return append(b, '\n')
}
