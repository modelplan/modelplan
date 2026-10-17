package advise

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// State is what the advisor remembers between runs, in <cache>/observed/advice.json:
// which hints were already given, and which windows we advised on, so that after their
// reset the user hears once that the ★ effort is fine again. No quota values are stored.
type State struct {
	SchemaVersion int                  `json:"schemaVersion"`
	Seen          map[string]time.Time `json:"seen"`
	Armed         []Armed              `json:"armed"`
	// Briefs: per thread, what the last task-start brief was judged against.
	Briefs  map[string]BriefMark `json:"briefs,omitempty"`
	changed bool
}

// BriefMark is what a thread's briefs described: every model it was briefed on and the model in
// use. (Efforts' values and Headroom are from clients before 0.5.17, which briefed again on
// those changes; they are kept as read.)
type BriefMark struct {
	Efforts  map[string]string `json:"efforts,omitempty"` // models briefed on
	Model    string            `json:"model,omitempty"`
	Headroom string            `json:"headroom,omitempty"`
	At       time.Time         `json:"at"`
}

// Armed is an advised window waiting for its reset.
type Armed struct {
	Key     string    `json:"key"` // the advice event key
	Type    string    `json:"type"`
	Source  string    `json:"source"`
	Plan    string    `json:"plan,omitempty"`
	Window  string    `json:"window"`
	ResetAt time.Time `json:"resetAt"`
	// WindowResetAt: for an announced reset, the window's own reset when we advised. Only a
	// reading taken after the announced time with a later window reset shows it reached us.
	WindowResetAt *time.Time `json:"windowResetAt,omitempty"`
}

const seenFor = 8 * 24 * time.Hour

func path(cache string) string { return filepath.Join(cache, "observed", "advice.json") }

// Load never fails: a missing or unreadable file is an empty state.
func Load(cache string) *State {
	s := &State{SchemaVersion: 1, Seen: map[string]time.Time{}}
	b, err := os.ReadFile(path(cache))
	if err != nil || len(b) > 256<<10 {
		return s
	}
	var on State
	if json.Unmarshal(b, &on) == nil && on.SchemaVersion == 1 {
		if on.Seen != nil {
			s.Seen = on.Seen
		}
		s.Briefs = on.Briefs
		s.Armed = on.Armed
	}
	return s
}

// Save writes only when something changed, merging with what another process (the status
// line and the hook run side by side) wrote in the meantime.
func (s *State) Save(cache string, now time.Time) error {
	if !s.changed {
		return nil
	}
	disk := Load(cache)
	for k, t := range disk.Seen {
		if _, ok := s.Seen[k]; !ok {
			s.Seen[k] = t
		}
	}
	for k, b := range disk.Briefs {
		if _, ok := s.Briefs[k]; !ok {
			if s.Briefs == nil {
				s.Briefs = map[string]BriefMark{}
			}
			s.Briefs[k] = b
		}
	}
	keys := map[string]bool{}
	for _, a := range s.Armed {
		keys[a.Key] = true
	}
	for _, a := range disk.Armed {
		if !keys[a.Key] {
			s.Armed = append(s.Armed, a)
		}
	}
	s.prune(now)
	b, _ := json.MarshalIndent(s, "", "  ")
	p := path(cache)
	if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
		return err
	}
	f, err := os.CreateTemp(filepath.Dir(p), ".advice-*")
	if err != nil {
		return err
	}
	_, err = f.Write(append(b, '\n'))
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err == nil {
		err = os.Rename(f.Name(), p)
	}
	if err != nil {
		os.Remove(f.Name())
	}
	return err
}

func (s *State) prune(now time.Time) {
	for k, t := range s.Seen {
		if now.Sub(t) > seenFor {
			delete(s.Seen, k)
		}
	}
	for k, b := range s.Briefs {
		if now.Sub(b.At) > seenFor {
			delete(s.Briefs, k)
		}
	}
	kept := s.Armed[:0]
	for _, a := range s.Armed {
		if now.Sub(a.ResetAt) <= a.lasts() {
			kept = append(kept, a)
		}
	}
	s.Armed = kept
}

// ConfigKey is the key a prompt hook remembers an event under. Advice about the configuration
// (tight, surplus before a reset, an announced reset) is about the model and effort in use: it is
// shown once per model and effort, whichever thread that is in, so ten threads on the same one
// do not repeat it; and once more when a tight window gets critical (10% or less left). Everything else (exhausted, switch
// back, peak hours, cards, public resets) is about the account or the world and is said once.
func ConfigKey(e Event) string {
	switch e.Type {
	case WindowTight, ResetSoonSurplus, AnnouncedSurplus:
	default:
		return e.Key
	}
	risk := ""
	if e.Type == WindowTight && e.RemainingPercent != nil && *e.RemainingPercent <= 10 {
		risk = "critical"
	}
	return strings.Join([]string{e.Key, e.Model, e.Effort, risk}, "|")
}

// Task-start briefs a thread can be due.
const (
	BriefFull   = "full"  // the thread's first prompt
	BriefSwitch = "model" // a model the thread has no brief for: that model's ladder only
)

// BriefDue says which task-start brief a thread needs ("" none) and records it: the full brief
// on its first prompt, and one line for a model it was not briefed on (read only on a later
// prompt, or switched to). A model it was briefed on earlier is still in context. Effort and
// quota changes are the user's to see (status line, hook notices), not a reason to brief again.
func (s *State) BriefDue(thread, model string, now time.Time) string {
	if thread == "" {
		return ""
	}
	if s.Briefs == nil {
		s.Briefs = map[string]BriefMark{}
	}
	last, seen := s.Briefs[thread]
	_, briefedOn := last.Efforts[model]
	due := ""
	switch {
	case !seen:
		due = BriefFull
	case model != "" && !briefedOn:
		due = BriefSwitch
	}
	if due == "" && (model == "" || model == last.Model) && now.Sub(last.At) <= 24*time.Hour {
		return ""
	}
	next := BriefMark{Efforts: map[string]string{}, Model: last.Model, At: now.UTC()}
	for k, v := range last.Efforts {
		next.Efforts[k] = v
	}
	if model != "" {
		next.Model = model
		if !briefedOn {
			next.Efforts[model] = ""
		}
	}
	s.Briefs[thread] = next
	s.changed = true
	return due
}

// Unseen keeps the events not yet shown.
func (s *State) Unseen(es []Event) []Event {
	var out []Event
	for _, e := range es {
		if _, ok := s.Seen[e.Key]; !ok {
			out = append(out, e)
		}
	}
	return out
}

func (s *State) MarkSeen(es []Event, now time.Time) {
	for _, e := range es {
		if _, ok := s.Seen[e.Key]; !ok {
			s.Seen[e.Key] = now.UTC()
			s.changed = true
		}
	}
}

// arm remembers windows we advised on (surplus, tight, exhausted) until their reset.
func (s *State) arm(es []Event) {
	for _, e := range es {
		if e.At == nil || (e.Type != ResetSoonSurplus && e.Type != WindowTight && e.Type != WindowExhausted && e.Type != AnnouncedSurplus) {
			continue
		}
		found := false
		for _, a := range s.Armed {
			found = found || a.Key == e.Key
		}
		if !found {
			s.Armed = append(s.Armed, Armed{Key: e.Key, Type: e.Type, Source: e.Source, Plan: e.Plan, Window: e.Window, ResetAt: *e.At, WindowResetAt: e.windowReset})
			s.changed = true
		}
	}
}

// switchBack: an advised window has reset. Suggest the ★ effort again when the harness is
// elsewhere, or say the allowance is back after an exhausted window.
func (s *State) switchBack(r quota.Report, d *digest.Digest, now time.Time) []Event {
	// One hint per window: a window advised more than once (surplus, then tight) or over
	// several resets reports only its latest passed reset; exhausted wins at that reset.
	latest := map[string]Armed{}
	var order []string
	for _, a := range s.Armed {
		if now.Before(a.ResetAt) || now.Sub(a.ResetAt) > a.lasts() {
			continue
		}
		k := strings.Join([]string{a.Source, a.Plan, a.Window}, "|")
		prev, seen := latest[k]
		switch {
		case !seen:
			order = append(order, k)
			latest[k] = a
		case a.ResetAt.After(prev.ResetAt), a.ResetAt.Equal(prev.ResetAt) && a.Type == WindowExhausted:
			latest[k] = a
		}
	}
	var out []Event
	for _, k := range order {
		a := latest[k]
		var acct *quota.Account
		for i := range r.Accounts {
			if r.Accounts[i].Source == a.Source && r.Accounts[i].Plan == a.Plan {
				acct = &r.Accounts[i]
			}
		}
		if acct == nil {
			continue
		}
		// A newer reading that still shows this window used up has not really reset.
		if still := windowNow(acct, a.Window); still != nil && still.Pace == "exhausted" {
			continue
		}
		if a.Type == AnnouncedSurplus && !restarted(acct, a) {
			continue
		}
		cfg := current(acct, d)
		e := Event{Type: SwitchBack, Key: strings.Join([]string{SwitchBack, k, a.ResetAt.UTC().Format(time.RFC3339)}, "|"), Severity: "info", Source: a.Source, Plan: a.Plan, Window: a.Window}
		t := a.ResetAt.UTC()
		e.At = &t
		if h := acct.Harness; h != nil {
			e.Model, e.Effort = h.Model, h.Effort
		}
		switch {
		case cfg.model != nil && cfg.rec != nil && cfg.cur != cfg.rec:
			e.Suggest = cfg.step("switch_back", cfg.rec)
		case a.Type == WindowExhausted:
			e.Suggest = &Step{Action: "none"}
		case cfg.model == nil && a.Type == ResetSoonSurplus:
			e.Suggest = &Step{Action: "switch_back"} // effort unknown: remind in general terms
		default:
			continue // already at ★, nothing to say
		}
		out = append(out, e)
	}
	return out
}

// restarted: a reading taken after the announced time shows the window with a later reset than
// when we advised, so the announced reset did reach this account.
func restarted(acct *quota.Account, a Armed) bool {
	w := windowNow(acct, a.Window)
	return a.WindowResetAt != nil && w != nil && w.ResetsAt != nil && w.ResetsAt.After(*a.WindowResetAt) && !w.ObservedAt.Before(a.ResetAt)
}

// lasts: how long after its reset an armed window may still say "switch back". An announced
// reset needs a new reading as proof, which comes with the user's next turn, so it waits longer.
func (a Armed) lasts() time.Duration {
	if a.Type == AnnouncedSurplus {
		return harnessQuiet
	}
	return switchBackFor
}

func windowNow(a *quota.Account, kind string) *quota.Window {
	for i := range a.Windows {
		if a.Windows[i].Kind == kind {
			return &a.Windows[i]
		}
	}
	return nil
}
