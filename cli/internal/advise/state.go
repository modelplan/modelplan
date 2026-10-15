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
	changed       bool
}

// Armed is an advised window waiting for its reset.
type Armed struct {
	Key     string    `json:"key"` // the advice event key
	Type    string    `json:"type"`
	Source  string    `json:"source"`
	Plan    string    `json:"plan,omitempty"`
	Window  string    `json:"window"`
	ResetAt time.Time `json:"resetAt"`
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
	kept := s.Armed[:0]
	for _, a := range s.Armed {
		if now.Sub(a.ResetAt) <= switchBackFor {
			kept = append(kept, a)
		}
	}
	s.Armed = kept
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
		if e.At == nil || (e.Type != ResetSoonSurplus && e.Type != WindowTight && e.Type != WindowExhausted) {
			continue
		}
		found := false
		for _, a := range s.Armed {
			found = found || a.Key == e.Key
		}
		if !found {
			s.Armed = append(s.Armed, Armed{Key: e.Key, Type: e.Type, Source: e.Source, Plan: e.Plan, Window: e.Window, ResetAt: *e.At})
			s.changed = true
		}
	}
}

// switchBack: an advised window has reset. Suggest the ★ effort again when the harness is
// elsewhere, or say the allowance is back after an exhausted window.
func (s *State) switchBack(r quota.Report, d *digest.Digest, now time.Time) []Event {
	var out []Event
	for _, a := range s.Armed {
		if now.Before(a.ResetAt) || now.Sub(a.ResetAt) > switchBackFor {
			continue
		}
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
		cfg := current(acct, d)
		e := Event{Type: SwitchBack, Key: strings.Join([]string{SwitchBack, a.Key}, "|"), Severity: "info", Source: a.Source, Plan: a.Plan, Window: a.Window}
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

func windowNow(a *quota.Account, kind string) *quota.Window {
	for i := range a.Windows {
		if a.Windows[i].Kind == kind {
			return &a.Windows[i]
		}
	}
	return nil
}
