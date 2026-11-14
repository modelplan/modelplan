// SPDX-License-Identifier: MIT
package detect

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"sync"
)

// Change is one presence flip between two detection reports (D238). It carries a
// logical tool id only, never a path or signal.
type Change struct {
	ProviderID string `json:"providerId"`
	Kind       string `json:"kind"`
}

const (
	ChangeAppeared    = "appeared"
	ChangeDisappeared = "disappeared"
)

// Diff lists tools that became detected (in next's order), then tools that stopped being
// detected (in prev's order).
func Diff(prev, next Report) []Change {
	was, now := map[string]bool{}, map[string]bool{}
	for _, t := range prev.Tools {
		was[t.ProviderID] = was[t.ProviderID] || t.Detected
	}
	var out []Change
	for _, t := range next.Tools {
		if !t.Detected || now[t.ProviderID] {
			continue
		}
		now[t.ProviderID] = true
		if !was[t.ProviderID] {
			out = append(out, Change{ProviderID: t.ProviderID, Kind: ChangeAppeared})
		}
	}
	for _, t := range prev.Tools {
		if was[t.ProviderID] && !now[t.ProviderID] {
			out = append(out, Change{ProviderID: t.ProviderID, Kind: ChangeDisappeared})
			was[t.ProviderID] = false
		}
	}
	return out
}

type seenFile struct {
	SchemaVersion int      `json:"schemaVersion"`
	Baseline      []string `json:"baseline"`
	Later         []string `json:"later"`
}

// SeenLedger remembers which tools were present the first time this Mac's engine looked (the
// first-run baseline, which the first-run chooser already offered) and which appeared later
// (D238). It stores logical tool ids only and reads nothing from any tool.
type SeenLedger struct {
	path     string
	readOnly bool
	mu       sync.Mutex
	loaded   bool
	state    seenFile
	last     Report
}

func NewSeenLedger(path string, readOnly bool) *SeenLedger {
	return &SeenLedger{path: path, readOnly: readOnly}
}

// Observe records one detection report and returns the tools that are detected now and were
// installed after the baseline. The first report on a machine without a ledger (or with a
// corrupt one) becomes the baseline, so an existing install never sees its tools as new.
func (l *SeenLedger) Observe(r Report) map[string]bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	changed := false
	if !l.loaded {
		l.loaded = true
		data, err := os.ReadFile(l.path)
		if err != nil || json.Unmarshal(data, &l.state) != nil || l.state.SchemaVersion != 1 {
			l.state = seenFile{SchemaVersion: 1, Baseline: []string{}, Later: []string{}}
			for _, t := range r.Tools {
				if t.Detected && !contains(l.state.Baseline, t.ProviderID) {
					l.state.Baseline = append(l.state.Baseline, t.ProviderID)
				}
			}
			changed = true
		}
	}
	for _, c := range Diff(l.last, r) {
		if c.Kind == ChangeAppeared && !contains(l.state.Baseline, c.ProviderID) && !contains(l.state.Later, c.ProviderID) {
			l.state.Later = append(l.state.Later, c.ProviderID)
			changed = true
		}
	}
	l.last = r
	if changed && !l.readOnly {
		l.save()
	}
	later := map[string]bool{}
	for _, t := range r.Tools {
		if t.Detected && contains(l.state.Later, t.ProviderID) {
			later[t.ProviderID] = true
		}
	}
	return later
}

// save is best effort: a failed write only means the next process rebuilds the baseline.
func (l *SeenLedger) save() {
	state := l.state
	state.Baseline = append([]string{}, state.Baseline...)
	state.Later = append([]string{}, state.Later...)
	sort.Strings(state.Baseline)
	sort.Strings(state.Later)
	data, err := json.Marshal(state)
	if err != nil {
		return
	}
	if err := os.MkdirAll(filepath.Dir(l.path), 0o700); err != nil {
		return
	}
	tmp, err := os.CreateTemp(filepath.Dir(l.path), ".detected-tools-*")
	if err != nil {
		return
	}
	name := tmp.Name()
	_, werr := tmp.Write(data)
	cerr := tmp.Close()
	if werr != nil || cerr != nil || os.Chmod(name, 0o600) != nil || os.Rename(name, l.path) != nil {
		_ = os.Remove(name)
	}
}

func contains(list []string, id string) bool {
	for _, v := range list {
		if v == id {
			return true
		}
	}
	return false
}
