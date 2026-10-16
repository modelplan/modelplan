// Package quota reads the user's own usage windows from files the harnesses already write
// on this machine: Codex session logs, the Claude Code status-line snapshot that
// `modelplan statusline` records, and the user-maintained local.json. It never opens
// credential files or calls an account endpoint, and nothing it reads leaves the machine.
package quota

import (
	"encoding/json"
	"math"
	"sort"
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
	Pace             string   `json:"pace"` // exhausted | tight | on_track | surplus | reset_passed | unknown
}

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
}

type Card struct {
	Kind      string     `json:"kind"`
	Count     *int       `json:"count"`
	ExpiresAt *time.Time `json:"expiresAt"`
}

// Account groups the windows one subscription reports; Claude Code and Codex are separate accounts.
type Account struct {
	Source     string    `json:"source"` // claude-code | codex | user
	Plan       string    `json:"plan,omitempty"`
	ObservedAt time.Time `json:"observedAt"`
	Stale      bool      `json:"stale"`
	Harness    *Harness  `json:"harness,omitempty"`
	Windows    []Window  `json:"windows"`
	Cards      []Card    `json:"cards,omitempty"`
	Via        string    `json:"via,omitempty"` // codex-account: windows from Codex's account reading, not only the logs
	Headroom   string    `json:"headroom"`      // spend | normal | conserve | exhausted | unknown
	Deciding   string    `json:"deciding,omitempty"`
}

type SourceStatus struct {
	Source string `json:"source"`
	Status string `json:"status"` // ok | missing | empty | invalid | unreadable | unsafe_path | too_large | unsupported_schema
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
	a.Headroom, a.Deciding = headroom(a.Windows)
}

func round1(v float64) *float64 { x := math.Round(v*10) / 10; return &x }

func evalWindow(w *Window, now time.Time) {
	w.RemainingPercent, w.ResetsInMinutes, w.ElapsedPercent, w.ProjectedPercent, w.AgeMinutes = nil, nil, nil, nil, nil
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
	switch {
	// Early in a window the projection is noisy, so it alone decides only after a fifth of it; a
	// window already half used that is on pace to run out is tight however early it is.
	case used >= 90 || (w.ProjectedPercent != nil && *w.ProjectedPercent > 100 && (elapsed >= 0.2 || used >= 50)):
		w.Pace = "tight"
	case 100-used >= 30 && (left <= length*0.25 || (w.ProjectedPercent != nil && *w.ProjectedPercent <= 60 && elapsed >= 0.5)):
		w.Pace = "surplus"
	default:
		w.Pace = "on_track"
	}
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
