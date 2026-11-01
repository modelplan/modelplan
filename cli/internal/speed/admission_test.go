// SPDX-License-Identifier: MIT
package speed

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestAdmittedPerfNeverRevivesOldOrUnstampedRecords(t *testing.T) {
	state := consent.Empty()
	state.StoreEpoch = "0123456789abcdef0123456789abcdef"
	state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
	state.Scopes[consent.ScopeClaudeLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
	admitted := consent.NewAdmission(state, consent.Automatic)
	codex := currentEpoch(admitted, "codex")
	claude := currentEpoch(admitted, "claude-code")
	now := time.Now()
	l := PerfLedger{Rows: []PerfRow{{Source: "codex", GrantEpoch: codex}, {Source: "codex"}, {Source: "claude-code", GrantEpoch: claude}}, Live: []LiveRecord{{Source: "codex", GrantEpoch: codex, LastAt: now}, {Source: "claude-code", GrantEpoch: claude, LastAt: now}}, Sessions: []PerfSession{{Source: "codex", GrantEpoch: codex}, {Source: "claude-code", GrantEpoch: claude}}, Hourly: []Hourly{{Source: "codex", GrantEpoch: codex}, {Source: "claude-code", GrantEpoch: claude}}}
	view := PerfView{OK: true, Recording: true, Now: now, Ledger: l}
	if got := view.Admitted(admitted); len(got.Ledger.Rows) != 2 || len(got.Ledger.Live) != 2 {
		t.Fatalf("initial: %#v", got.Ledger)
	}
	state.Generation = 1
	state.Revoked[consent.ScopeCodexLocalHistory] = 1
	state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
	if got := view.Admitted(consent.NewAdmission(state, consent.Automatic)); len(got.Ledger.Rows) != 1 || got.Ledger.Rows[0].Source != "claude-code" || len(got.Ledger.Live) != 1 || len(got.Ledger.Sessions) != 1 || len(got.Ledger.Hourly) != 1 {
		t.Fatalf("revoke: %#v", got.Ledger)
	}
	state.Generation = 2
	state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion, At: now}
	regrant := consent.NewAdmission(state, consent.Automatic)
	if got := view.Admitted(regrant); len(got.Ledger.Rows) != 1 || len(got.Ledger.Live) != 1 {
		t.Fatalf("old data revived: %#v", got.Ledger)
	}
	fresh := currentEpoch(regrant, "codex")
	view.Ledger.Rows = append(view.Ledger.Rows, PerfRow{Source: "codex", GrantEpoch: fresh})
	view.Ledger.Live = append(view.Ledger.Live, LiveRecord{Source: "codex", GrantEpoch: fresh, LastAt: now})
	if got := view.Admitted(regrant); len(got.Ledger.Rows) != 2 || len(got.Ledger.Live) != 2 {
		t.Fatalf("new data missing: %#v", got.Ledger)
	}
	state.StoreEpoch = "fedcba9876543210fedcba9876543210"
	if got := view.Admitted(consent.NewAdmission(state, consent.Automatic)); len(got.Ledger.Rows) != 0 || len(got.Ledger.Live) != 0 {
		t.Fatalf("store reset revived data: %#v", got.Ledger)
	}
}

func TestPerfRowsDoNotMergeAcrossGrantEpochs(t *testing.T) {
	state := consent.Empty()
	state.StoreEpoch = "0123456789abcdef0123456789abcdef"
	state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
	l := PerfLedger{admission: consent.NewAdmission(state, consent.Automatic)}
	l.row("2026-11-01", "codex", ParserCodex, config{model: "m"}).ObservedOutputTokens = 20
	state.Generation = 2
	state.Revoked[consent.ScopeCodexLocalHistory] = 1
	state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion, At: time.Now()}
	l.admission = consent.NewAdmission(state, consent.Automatic)
	l.row("2026-11-01", "codex", ParserCodex, config{model: "m"}).ObservedOutputTokens = 30
	if len(l.Rows) != 2 || l.Rows[0].ObservedOutputTokens != 20 || l.Rows[1].ObservedOutputTokens != 30 {
		t.Fatalf("epochs merged: %#v", l.Rows)
	}
}

func TestNewGrantDoesNotRelabelPreGrantObservations(t *testing.T) {
	now := time.Now().UTC()
	state := consent.Empty()
	state.StoreEpoch = "0123456789abcdef0123456789abcdef"
	state.Generation = 2
	state.Revoked[consent.ScopeCodexLocalHistory] = 1
	state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion, At: now}
	l := PerfLedger{Since: now.Add(-time.Hour), admission: consent.NewAdmission(state, consent.Automatic)}
	cfg := config{model: "synthetic-model"}
	old := turn{at: now.Add(-time.Second), cfg: cfg, all: []request{{cfg: cfg, out: 50, end: now.Add(-time.Second)}}}
	l.add("codex", ParserCodex, old)
	l.addSession("opaque", "codex", old)
	if len(l.Rows) != 0 || len(l.Sessions) != 0 {
		t.Fatal("pre-grant turn was relabeled")
	}
	fresh := turn{at: now.Add(time.Second), cfg: cfg, all: []request{{cfg: cfg, out: 50, end: now.Add(time.Second)}}}
	l.add("codex", ParserCodex, fresh)
	l.addSession("opaque", "codex", fresh)
	if len(l.Rows) != 1 || l.Rows[0].GrantEpoch == nil || len(l.Sessions) != 1 || l.Sessions[0].GrantEpoch == nil {
		t.Fatal("new authorized turn missing provenance")
	}
}
