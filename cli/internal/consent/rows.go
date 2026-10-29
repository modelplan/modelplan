// SPDX-License-Identifier: MIT
package consent

import (
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/rows"
)

// RowsInput is the consent-owned portion of the shared projection input. Other
// adapters add catalogue, per-profile readings and declarations to this value;
// they must not infer reader consent from a source status or recapture consent.
func (a Admission) RowsInput(now time.Time) rows.Input {
	in := rows.Input{Now: now, ConsentGeneration: a.Generation(), ReadersOff: a.Mode() == Off}
	ids := make([]string, 0, len(a.state.Tools))
	for id := range a.state.Tools {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	for _, id := range ids {
		record := a.state.Tools[id]
		decision := rows.ConsentDenied
		if record.Allowed {
			decision = rows.ConsentAllowed
		}
		in.Consents = append(in.Consents, rows.ConsentRecord{ToolID: id, Generation: a.Generation(), State: decision,
			Outdated: record.ConsentTextVersion != TextVersion, CleanupPending: a.CleanupPending(id)})
	}
	// Only these established credential-free readers have automatic implicit
	// permission. A newly shipped credential reader never gains an implicit grant.
	for _, id := range []string{"claude", "codex"} {
		if _, decided := a.state.Tools[id]; !decided && a.Allows(id, Local) {
			in.Consents = append(in.Consents, rows.ConsentRecord{ToolID: id, Generation: a.Generation(), State: rows.ConsentImplicit})
		}
	}
	return in
}

// ChangedRowsInput is the publication-failure input for a declared-only retry
// result. Callers may add declarations; no tool membership or reading survives.
// The shared rows builder owns the pending/consent_changed wire projection.
func (a Admission) ChangedRowsInput(now time.Time) rows.Input {
	return rows.Input{Now: now, ConsentGeneration: a.Generation(), ConsentChanged: true}
}
