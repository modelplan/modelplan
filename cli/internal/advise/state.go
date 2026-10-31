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
// which hints were already given, and which windows we advised on with the configuration in use
// then, so that after their reset the user hears once to go back to it. No quota values are stored.
type State struct {
	SchemaVersion int                  `json:"schemaVersion"`
	Seen          map[string]time.Time `json:"seen"`
	Armed         []Armed              `json:"armed"`
	// Briefs: per thread, what the last task-start brief was judged against.
	Briefs  map[string]BriefMark    `json:"briefs,omitempty"`
	Quotas  map[string]QuotaSession `json:"quotas,omitempty"`
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
	// Remaining: for an announced reset, the window's remaining percent when we advised. More
	// left later also shows the reset reached us (a fixed window only fills up between resets).
	Remaining *float64 `json:"remaining,omitempty"`
	// From: the configuration in use when this window was first advised on in this cycle; after
	// the reset the user is pointed back to it. Nil in state written before 0.5.18 (then ★).
	From *Config `json:"from,omitempty"`
	// Noted: when the switch-back was first derived; the status line shows it for a while after.
	Noted *time.Time `json:"noted,omitempty"`
}

// Config is a harness configuration as the harness reports it.
type Config struct {
	Model  string `json:"model,omitempty"`
	Effort string `json:"effort,omitempty"` // "" = the harness default (★)
	Fast   bool   `json:"fast,omitempty"`   // Codex Fast, which draws plan quota
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
		s.Quotas = on.Quotas
		s.Armed = on.Armed
	}
	return s
}

// stateLockWait bounds how long Save waits for another process's save.
const stateLockWait = time.Second

// Save writes only when something changed, merging with what another process (the status
// line and the hook run side by side) wrote in the meantime. The read, merge and rename hold
// the state lock, so two writers keep each other's marks.
func (s *State) Save(cache string, now time.Time) error {
	if !s.changed {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(path(cache)), 0o700); err != nil {
		return err
	}
	unlock, err := lockState(path(cache))
	if err != nil {
		return err
	}
	defer unlock()
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
	for k, q := range disk.Quotas {
		if s.Quotas == nil {
			s.Quotas = map[string]QuotaSession{}
		}
		local, ok := s.Quotas[k]
		if !ok {
			s.Quotas[k] = q
			continue
		}
		if local.Windows == nil {
			local.Windows = map[string]QuotaMark{}
		}
		for window, mark := range q.Windows {
			local.Windows[window] = mergeMark(local.Windows[window], mark)
		}
		if q.At.After(local.At) {
			local.At = q.At
		}
		s.Quotas[k] = local
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
		// Monthly windows must not repeat a pace notice after the usual 8-day
		// state retention. Its key ends with the exact window reset.
		if strings.HasPrefix(k, WindowPace+"|") {
			if reset, err := time.Parse(time.RFC3339, k[strings.LastIndex(k, "|")+1:]); err == nil && reset.After(now) {
				continue
			}
		}
		keep := seenFor
		if strings.HasPrefix(k, "better|") || strings.HasPrefix(k, shownPrefix+"better|") {
			keep = betterFor
		}
		if now.Sub(t) > keep {
			delete(s.Seen, k)
		}
	}
	for k, b := range s.Briefs {
		if now.Sub(b.At) > seenFor {
			delete(s.Briefs, k)
		}
	}
	for k, q := range s.Quotas {
		if now.Sub(q.At) > seenFor {
			delete(s.Quotas, k)
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
// do not repeat it; and once more when a tight window gets critical (10% or less left, or used up
// within half an hour at the recent rate). Everything else (exhausted, switch back, peak hours,
// cards, public resets) is about the account or the world and is said once.
func ConfigKey(e Event) string {
	switch e.Type {
	case WindowTight, ResetSoonSurplus, AnnouncedSurplus:
	default:
		return e.Key
	}
	risk := ""
	if e.Type == WindowTight && (e.RemainingPercent != nil && *e.RemainingPercent <= 10 || e.RunsOutInMinutes != nil && *e.RunsOutInMinutes <= 30) {
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
// quota changes do not repeat the brief; QuotaNotices handles the model's factual thresholds.
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

// arm remembers windows we advised on (surplus, tight, exhausted) until their reset, with the
// configuration in use when the window was first advised on in this cycle: a later hint on the
// same window (surplus, then tight) may come after the user already followed the first.
func (s *State) arm(es []Event) {
	for _, e := range es {
		if e.At == nil || (e.Type != ResetSoonSurplus && e.Type != WindowTight && e.Type != WindowExhausted && e.Type != AnnouncedSurplus) {
			continue
		}
		found := false
		var from *Config
		for _, a := range s.Armed {
			found = found || a.Key == e.Key
			if from == nil && a.From != nil && a.Source == e.Source && a.Plan == e.Plan && a.Window == e.Window && a.ResetAt.Equal(*e.At) {
				from = a.From
			}
		}
		if found {
			continue
		}
		if from == nil && e.Model != "" {
			from = &Config{Model: e.Model, Effort: e.Effort, Fast: e.Fast != nil}
		}
		var left *float64
		if e.Type == AnnouncedSurplus && e.RemainingPercent != nil {
			v := *e.RemainingPercent
			left = &v
		}
		s.Armed = append(s.Armed, Armed{Key: e.Key, Type: e.Type, Source: e.Source, Plan: e.Plan, Window: e.Window, ResetAt: *e.At, WindowResetAt: e.windowReset, Remaining: left, From: from})
		s.changed = true
	}
}

// switchBack: an advised window has reset. Point the user back to the configuration in use when
// it was advised on (and Codex Fast off if it was turned on since), or say the allowance is back
// after an exhausted window. Nothing when the user is on that configuration already: a hint they
// did not follow left nothing to undo.
func (s *State) switchBack(r quota.Report, d *digest.Digest, now time.Time) []Event {
	// An announced reset can land before its stated time: then it reset at the reading that shows it.
	for i := range s.Armed {
		a := &s.Armed[i]
		if a.Type != AnnouncedSurplus || !now.Before(a.ResetAt) {
			continue
		}
		if acct := accountFor(r, a); acct != nil && reached(acct, a) {
			if w := windowNow(acct, a.Window); w.ObservedAt.Before(a.ResetAt) {
				a.ResetAt = w.ObservedAt
				s.changed = true
			}
		}
	}
	// One hint per window: a window advised more than once (surplus, then tight) or over
	// several resets reports only its latest passed reset; exhausted wins at that reset.
	latest := map[string]int{}
	var order []string
	for i, a := range s.Armed {
		if now.Before(a.ResetAt) || now.Sub(a.ResetAt) > a.lasts() {
			continue
		}
		k := strings.Join([]string{a.Source, a.Plan, a.Window}, "|")
		prev, seen := latest[k]
		switch {
		case !seen:
			order = append(order, k)
			latest[k] = i
		case a.ResetAt.After(s.Armed[prev].ResetAt), a.ResetAt.Equal(s.Armed[prev].ResetAt) && a.Type == WindowExhausted:
			latest[k] = i
		}
	}
	var out []Event
	for _, k := range order {
		a := &s.Armed[latest[k]]
		acct := accountFor(r, a)
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
		back, known := backTo(a.From, acct, cfg, d)
		if known {
			// Fast in Codex draws plan quota: turned on for the surplus, it should go off with it.
			if fast := fastNow(acct, cfg, d); fast != nil && !a.From.Fast {
				e.Fast, e.FastOff = fast, true
			}
		}
		switch {
		case back != nil:
			e.Suggest = back
		case !known && cfg.model != nil && cfg.rec != nil && cfg.cur != cfg.rec:
			e.Suggest = cfg.step("switch_back", cfg.rec) // advised before 0.5.18: no record of what came before
		case a.Type == WindowExhausted, e.FastOff:
			e.Suggest = &Step{Action: "none"}
		case !known && cfg.model == nil && a.Type == ResetSoonSurplus:
			e.Suggest = &Step{Action: "switch_back"} // effort unknown: remind in general terms
		default:
			continue // on the configuration from before the advice: nothing to say
		}
		if a.Noted == nil {
			n := now.UTC()
			a.Noted = &n
			s.changed = true
		}
		e.noted = a.Noted
		out = append(out, e)
	}
	return out
}

// backTo: the step back to the configuration from before the advice, nil when the harness is on
// it. known is false when that configuration was not recorded or no longer resolves.
func backTo(from *Config, acct *quota.Account, cfg config, d *digest.Digest) (*Step, bool) {
	if from == nil || cfg.model == nil || acct.Harness == nil {
		return nil, false
	}
	was := current(&quota.Account{Source: acct.Source, Harness: &quota.Harness{Model: from.Model, Effort: from.Effort, Endpoint: acct.Harness.Endpoint}}, d)
	if was.model == nil || was.cur == nil {
		return nil, false
	}
	if was.model == cfg.model && was.cur == cfg.cur {
		return nil, true
	}
	st := &Step{Action: "switch_back", Model: was.model.ID, ModelName: was.model.Name, Effort: was.cur.Effort, Label: was.cur.Label, Recommended: was.cur == was.rec, ModelChange: was.model != cfg.model}
	st.AbilityDelta, st.CostRatio = cfg.ratioTo(was.model, was.cur)
	return st, true
}

// InStatusLine: whether the status line still shows this event. A switch-back is shown for a
// while after it first appeared, a better model for a week; the prompt hook says each once.
func (e Event) InStatusLine(now time.Time) bool {
	if e.Type == BetterModel {
		return e.noted == nil || now.Sub(*e.noted) <= betterShown
	}
	return e.Type != SwitchBack || e.noted == nil || now.Sub(*e.noted) <= switchBackShown
}

// restarted: a reading taken at or after the announced time (or the time the reset was seen to
// land) shows the announced reset reached this account.
func restarted(acct *quota.Account, a *Armed) bool {
	w := windowNow(acct, a.Window)
	return reached(acct, a) && !w.ObservedAt.Before(a.ResetAt)
}

// reached: the window shows a later reset than when we advised (by more than reading jitter), or
// announcedRise points more left: the announced reset reached this account.
func reached(acct *quota.Account, a *Armed) bool {
	w := windowNow(acct, a.Window)
	if w == nil || w.ResetsAt == nil || a.WindowResetAt == nil {
		return false
	}
	return w.ResetsAt.After(a.WindowResetAt.Add(time.Hour)) ||
		a.Remaining != nil && w.RemainingPercent != nil && *w.RemainingPercent >= *a.Remaining+announcedRise
}

// reachedKey: whether the announced reset advised on under this key already reached the account.
func (s *State) reachedKey(acct *quota.Account, key string) bool {
	if s == nil {
		return false
	}
	for i := range s.Armed {
		if s.Armed[i].Key == key {
			return reached(acct, &s.Armed[i])
		}
	}
	return false
}

func accountFor(r quota.Report, a *Armed) *quota.Account {
	var acct *quota.Account
	for i := range r.Accounts {
		if r.Accounts[i].Source == a.Source && r.Accounts[i].Plan == a.Plan {
			acct = &r.Accounts[i]
		}
	}
	return acct
}

// shownPrefix marks an event the status line has shown, apart from the hook having told it.
const shownPrefix = "shown|"

// firstNoted: when the user first saw an event, in the hook or the status line.
func (s *State) firstNoted(key string) *time.Time {
	var first *time.Time
	for _, k := range []string{key, shownPrefix + key} {
		if t, ok := s.Seen[k]; ok && (first == nil || t.Before(*first)) {
			t := t
			first = &t
		}
	}
	return first
}

// NoteShown records that the status line showed a better-model hint, so it stops after
// betterShown even when no hook tells it.
func (s *State) NoteShown(e Event, now time.Time) {
	if e.Type == WindowPace {
		s.MarkSeen([]Event{e}, now)
	}
	if e.Type == BetterModel {
		s.Once(shownPrefix+e.Key, now)
	}
}

// lasts: how long after its reset an armed window may still say "switch back".
func (a Armed) lasts() time.Duration { return switchBackFor }

// mergeMark: the later cycle's mark; within one cycle, everything either writer sent.
func mergeMark(own, disk QuotaMark) QuotaMark {
	own, disk = own.current(), disk.current()
	switch {
	case own.ResetAt.IsZero() || disk.ResetAt.After(own.ResetAt.Add(cycleJitter)):
		return disk
	case own.ResetAt.After(disk.ResetAt.Add(cycleJitter)):
		return own
	}
	if disk.Level > 0 && (own.Level == 0 || disk.Level < own.Level) {
		own.Level = disk.Level
	}
	own.Pace, own.Surplus = own.Pace || disk.Pace, own.Surplus || disk.Surplus
	own.WasLow, own.Recovered = own.WasLow || disk.WasLow, own.Recovered || disk.Recovered
	return own
}

func windowNow(a *quota.Account, kind string) *quota.Window {
	for i := range a.Windows {
		if a.Windows[i].Kind == kind && a.InPool(&a.Windows[i]) {
			return &a.Windows[i]
		}
	}
	return nil
}
