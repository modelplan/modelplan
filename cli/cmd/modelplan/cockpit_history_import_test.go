// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"encoding/json"
	"os"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/queries"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

func writeImportedLedger(t *testing.T, cache string, rows []speed.PerfRow) {
	t.Helper()
	if err := os.MkdirAll(speed.ImportPath(cache)[:len(speed.ImportPath(cache))-len("/imported.json")], 0o700); err != nil {
		t.Fatal(err)
	}
	b, err := json.Marshal(speed.ImportLedger{SchemaVersion: 1, Rows: rows})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(speed.ImportPath(cache), b, 0o600); err != nil {
		t.Fatal(err)
	}
}

func importedRow(epoch, day, source, model string, out int64) speed.PerfRow {
	return speed.PerfRow{GrantEpoch: &speed.GrantEpoch{StoreEpoch: epoch}, Origin: speed.OriginImport, Day: day, Source: source, Model: model,
		EffortStatus: "unreported", Parser: "x", Eligibility: "eligible", ObservedRequests: 2, ObservedOutputTokens: out,
		EligibleRequests: 2, EligibleOutputTokens: out, GenMs: 1000, Turns: 1}
}

func historyImportFixture(t *testing.T) (cache string, now time.Time, state consent.State, view appserver.View, groups map[string][]wire.CockpitAccount) {
	oldLocal, oldNow := time.Local, cockpitHistoryNow
	time.Local, cockpitHistoryNow = time.UTC, func() time.Time { return time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC) }
	t.Cleanup(func() { time.Local, cockpitHistoryNow = oldLocal, oldNow })
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_HISTORY", "")
	state, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	now = cockpitHistoryNow()
	refA := "0123456789abcdef"
	view = appserver.View{PublicModels: []digest.Model{{ID: "gpt-5.3"}, {ID: "sonnet"}}, QuotaReport: quota.Report{Accounts: []quota.Account{
		{Source: "codex", Subscription: &quota.Binding{Ref: refA, Status: "verified", ObservedAt: now.Add(-30 * time.Minute)}}}}}
	return t.TempDir(), now, state, view, map[string][]wire.CockpitAccount{refA: {}}
}

// HIST-IMP: imported days draw next to live ones, tagged by origin, and the earliest data date moves back.
func TestCockpitHistoryMergesImportedRowsWithoutDoubleCounting(t *testing.T) {
	cache, now, state, view, groups := historyImportFixture(t)
	live := historyLedger(t, state.StoreEpoch, now) // codex live rows on 11-04 and 10-20
	live.Since = now.Add(-2 * 24 * time.Hour)       // recording began 11-03; 10-20 row is an old long-form leftover
	live.Rows = live.Rows[:1]                        // codex, 11-04
	writeHistoryLedger(t, cache, live)
	e := state.StoreEpoch
	writeImportedLedger(t, cache, []speed.PerfRow{
		importedRow(e, "2026-10-20", "codex", "gpt-5.3", 700),
		importedRow(e, "2026-10-21", "codex", "gpt-5.3", 300),
		importedRow(e, "2026-11-04", "codex", "gpt-5.3", 9999), // a day live covers: never counted
		importedRow(e, "2026-10-22", "zcode", "glm", 5000),    // not admitted
	})
	stamp := appserver.Stamp{Epoch: state.StoreEpoch, Generation: state.Generation}
	adm := queries.CockpitAdmission{Stamp: stamp, Scopes: []string{consent.ScopeCodexLocalHistory}}
	data, err := (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), view, adm, groups)
	if err != nil {
		t.Fatal(err)
	}
	got := map[string]int64{}
	for _, b := range data.Daily {
		got[b.At+"/"+b.Source+"/"+b.Origin] = b.ObservedOutputTokens
	}
	want := map[string]int64{"2026-10-20/codex/import": 700, "2026-10-21/codex/import": 300, "2026-11-04/codex/live": 2000}
	if len(got) != len(want) {
		t.Fatalf("daily = %+v", data.Daily)
	}
	for k, v := range want {
		if got[k] != v {
			t.Fatalf("daily %s = %d, all %+v", k, got[k], data.Daily)
		}
	}
	if data.DailyFrom == nil || *data.DailyFrom != "2026-10-20" {
		t.Fatalf("dailyFrom = %v", data.DailyFrom)
	}
	for _, b := range data.Hourly {
		if b.Origin != "live" {
			t.Fatalf("hourly origin = %q", b.Origin)
		}
	}
	// 30-day windows add the imported tokens once; the 7-day window has only the live day.
	w7, w30 := data.Subscriptions[0].Sources[0].Recent7d, data.Subscriptions[0].Sources[0].Recent30d
	if w7.OutputTokens != 2000 || w30.OutputTokens != 3000 {
		t.Fatalf("windows 7d=%d 30d=%d", w7.OutputTokens, w30.OutputTokens)
	}
	if w30.ObservedRequests != 14 || w30.EligibleRequests != 6 {
		t.Fatalf("requests %+v: imported rows add counts, not timing", w30)
	}
	if data.Tools.Recent30d.TotalObservedOutputTokens != 3000 || data.Models.Recent30d.TotalObservedOutputTokens != 3000 {
		t.Fatalf("rankings %+v %+v", data.Tools.Recent30d, data.Models.Recent30d)
	}
	// Reading twice gives the same answer: nothing is written back or accumulated.
	again, _ := (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), view, adm, groups)
	if a, b := mustJSON(t, data), mustJSON(t, again); a != b {
		t.Fatalf("second read differs:\n%s\n%s", a, b)
	}
}

func mustJSON(t *testing.T, v any) string {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

// Revoking a source's history consent removes its imported days from the views at once, with no
// file change: rows stamped with the old grant epoch no longer count.
func TestCockpitHistoryDropsImportedRowsOfARevokedSourceAndOfAnOldGrant(t *testing.T) {
	cache, now, state, view, groups := historyImportFixture(t)
	writeHistoryLedger(t, cache, historyLedger(t, state.StoreEpoch, now))
	writeImportedLedger(t, cache, []speed.PerfRow{
		importedRow(state.StoreEpoch, "2026-10-20", "codex", "gpt-5.3", 700),
		importedRow("another-store-epoch", "2026-10-21", "codex", "gpt-5.3", 300),
	})
	stamp := appserver.Stamp{Epoch: state.StoreEpoch, Generation: state.Generation}
	// The scope is not granted for this read: nothing of the source shows, imported or live.
	none, err := (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), view, queries.CockpitAdmission{Stamp: stamp, Scopes: []string{consent.ScopeClaudeLocalHistory}}, groups)
	if err != nil {
		t.Fatal(err)
	}
	for _, b := range none.Daily {
		if b.Source == "codex" {
			t.Fatalf("revoked source's day leaked: %+v", b)
		}
	}
	adm := queries.CockpitAdmission{Stamp: stamp, Scopes: []string{consent.ScopeCodexLocalHistory}}
	data, err := (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), view, adm, groups)
	if err != nil {
		t.Fatal(err)
	}
	for _, b := range data.Daily {
		if b.Origin == "import" && b.At != "2026-10-20" {
			t.Fatalf("a row of another grant counted: %+v", b)
		}
	}
	// Removing the imported history leaves the live views exactly as they were before any import.
	if err := speed.RemoveImported(cache); err != nil {
		t.Fatal(err)
	}
	after, _ := (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), view, adm, groups)
	for _, b := range after.Daily {
		if b.Origin != "live" {
			t.Fatalf("imported bucket after remove: %+v", b)
		}
	}
	if after.DailyFrom == nil || *after.DailyFrom == "2026-10-20" {
		t.Fatalf("dailyFrom after remove = %v", after.DailyFrom)
	}
}

// Before the live recorder has written, imported days alone make the record.
func TestCockpitHistoryShowsImportedDaysBeforeTheLiveLedgerStarts(t *testing.T) {
	cache, _, state, view, groups := historyImportFixture(t)
	writeImportedLedger(t, cache, []speed.PerfRow{importedRow(state.StoreEpoch, "2026-10-28", "codex", "gpt-5.3", 400)})
	stamp := appserver.Stamp{Epoch: state.StoreEpoch, Generation: state.Generation}
	data, err := (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), view, queries.CockpitAdmission{Stamp: stamp, Scopes: []string{consent.ScopeCodexLocalHistory}}, groups)
	if err != nil {
		t.Fatal(err)
	}
	if data.Coverage != "local-history" || len(data.Daily) != 1 || data.Daily[0].Origin != "import" || data.DailyFrom == nil || *data.DailyFrom != "2026-10-28" {
		t.Fatalf("history = %+v", data)
	}
	// No imported file and no live ledger: still unavailable, as before.
	empty, _ := (sharedCockpit{cache: t.TempDir()}).cockpitHistory(context.Background(), view, queries.CockpitAdmission{Stamp: stamp, Scopes: []string{consent.ScopeCodexLocalHistory}}, groups)
	if empty.Coverage != "unavailable" {
		t.Fatalf("coverage = %q", empty.Coverage)
	}
}

// MODELPLAN_HISTORY=off counts nothing imported.
func TestCockpitHistoryIgnoresImportedRowsWhileRecordingIsOff(t *testing.T) {
	cache, now, state, view, groups := historyImportFixture(t)
	writeHistoryLedger(t, cache, historyLedger(t, state.StoreEpoch, now))
	writeImportedLedger(t, cache, []speed.PerfRow{importedRow(state.StoreEpoch, "2026-10-20", "codex", "gpt-5.3", 700)})
	t.Setenv("MODELPLAN_HISTORY", "off")
	stamp := appserver.Stamp{Epoch: state.StoreEpoch, Generation: state.Generation}
	data, err := (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), view, queries.CockpitAdmission{Stamp: stamp, Scopes: []string{consent.ScopeCodexLocalHistory}}, groups)
	if err != nil {
		t.Fatal(err)
	}
	if len(data.Daily) != 0 || data.Coverage != "recording-off" {
		t.Fatalf("history = %+v", data)
	}
}
