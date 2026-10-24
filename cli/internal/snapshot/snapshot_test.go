package snapshot

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/advise"
	"github.com/modelplan/modelplan/cli/internal/connections"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
)

var now = time.Date(2026, 10, 18, 9, 0, 0, 0, time.UTC)

func f(v float64) *float64 { return &v }

func fixture() (*digest.Digest, quota.Report) {
	e := func(k, l string, a, c float64) digest.Effort {
		return digest.Effort{Effort: k, Label: l, Ability: f(a), Cost: f(c), CostBasisID: "ref"}
	}
	d := &digest.Digest{Models: []digest.Model{{ID: "opus", Name: "Claude Opus 5.5", DeveloperID: "anthropic", Recommended: "medium",
		HarnessIDs: map[string][]string{"claude-code": {"claude-opus-5-5"}}, Efforts: []digest.Effort{e("medium", "Med", 55.4, 2.91), e("high", "High", 60.2, 3.98)}}}}
	seen := now.Add(-2 * time.Minute)
	fast := true
	r := quota.Report{SchemaVersion: 1, EvaluatedAt: now, Accounts: []quota.Account{
		{Source: "claude-code", ObservedAt: seen, Headroom: "normal", Deciding: "five_hour", Harness: &quota.Harness{Model: "claude-opus-5-5", Effort: "high", FastMode: &fast, ObservedAt: &seen, Attribution: "current-thread"}},
		{Source: "codex", ObservedAt: seen, Headroom: "conserve", Pool: "reserve", Harness: &quota.Harness{Model: "gpt-9-unknown", ServiceTier: "fast", ObservedAt: &seen}},
		{Source: "codexbar:zai", ObservedAt: seen, Headroom: "normal"},
	}, Sources: []quota.SourceStatus{{Source: "claude-code", Status: "ok"}}}
	return d, r
}

func TestSnapshot(t *testing.T) {
	d, r := fixture()
	ev := advise.Event{Type: advise.WindowTight, Key: "window_tight|claude-code||five_hour||x", Severity: "warn", Source: "claude-code", Window: "five_hour",
		RemainingPercent: f(12), Model: "claude-opus-5-5", Effort: "high", Suggest: &advise.Step{Action: "step_down", Label: "Med", Recommended: true, AbilityDelta: f(-4.8), CostRatio: f(0.73)}}
	s := Build(Input{Report: r, Digest: d, State: store.State{PublicationID: "p1", PublishedAt: "2026-10-18T08:00:00Z", CheckedAt: now.Add(-time.Hour)},
		Events: []advise.Event{ev}, Measured: []speed.Stat{{Source: "claude-code", Model: "claude-opus-5-5", Effort: "high", Turns: 7}}, Recording: true, CLIVersion: "0.5.25", Now: now})
	if s.Kind != Kind || s.SchemaVersion != 1 || s.Publication == nil || s.Publication.Stale || len(s.Accounts) != 3 || len(s.Measured) != 1 {
		t.Fatalf("snapshot = %+v", s)
	}
	if len(s.Sessions) != 2 {
		t.Fatalf("CodexBar accounts are not sessions: %+v", s.Sessions)
	}
	cc := s.Sessions[0]
	if cc.Model.ID != "opus" || cc.Effort == nil || cc.Effort.Label != "High" || cc.Effort.Star || cc.Recommended.Label != "Med" || cc.Speed != "fast" ||
		*cc.VsRecommended.AbilityDelta != 4.8 || *cc.VsRecommended.CostRatio != 1.37 || cc.Attribution != "current-thread" {
		t.Errorf("claude-code session = %+v", cc)
	}
	cx := s.Sessions[1]
	if cx.Model.ID != "" || cx.Model.HarnessID != "gpt-9-unknown" || cx.Effort != nil || cx.Speed != "fast" || cx.Pool != "reserve" || cx.Headroom != "conserve" {
		t.Errorf("an unlisted model keeps what the harness said: %+v", cx)
	}
	e := s.Events[0]
	if e.Key != advise.ConfigKey(ev) || !strings.Contains(e.Text["zh"], "降到 ★Med") || e.Short["zh"] != "↓★Med ×0.73" || e.Short["en"] != "↓★Med ×0.73" || !e.InMenuBar {
		t.Errorf("event = %+v", e)
	}
	b, _ := json.Marshal(s)
	for _, want := range []string{`"kind":"modelplan.personal-snapshot"`, `"type":"window_tight"`, `"short":{`, `"inMenuBar":true`, `"vsRecommended":{"abilityDelta":4.8,"costRatio":1.37}`} {
		if !strings.Contains(string(b), want) {
			t.Errorf("missing %s in %s", want, b)
		}
	}
	if strings.Contains(string(b), "\x1b[") {
		t.Error("no terminal colours in the snapshot")
	}
}

func TestEmptySnapshotHasNoNulls(t *testing.T) {
	s := Build(Input{Now: now})
	b, _ := json.Marshal(s)
	for _, k := range []string{`"sessions":[]`, `"accounts":[]`, `"sources":[]`, `"events":[]`, `"measured":[]`, `"publication":null`} {
		if !strings.Contains(string(b), k) {
			t.Errorf("missing %s in %s", k, b)
		}
	}
	old := Build(Input{Digest: &digest.Digest{}, State: store.State{PublicationID: "p0", CheckedAt: now.Add(-49 * time.Hour)}, Now: now})
	if old.Publication == nil || !old.Publication.Stale {
		t.Errorf("a publication unchecked for two days is stale: %+v", old.Publication)
	}
}

// clocked builds the snapshot of one fixed set of readings at another clock time, as the CLI
// does: the accounts' verdicts, the advice and the boundaries all from that time.
func clocked(at time.Time, used float64) Snapshot {
	d, _ := fixture()
	seen, reset := now.Add(-2*time.Minute), now.Add(30*time.Minute)
	r := quota.Report{SchemaVersion: 1, EvaluatedAt: at, Accounts: []quota.Account{{Source: "claude-code", ObservedAt: seen,
		Harness: &quota.Harness{Model: "claude-opus-5-5", ObservedAt: &seen},
		Windows: []quota.Window{{Kind: "five_hour", UsedPercent: f(used), WindowMinutes: 300, ResetsAt: &reset, ResetMode: "fixed", ObservedAt: seen}}}},
		Sources: []quota.SourceStatus{{Source: "claude-code", Status: "ok"}}}
	for i := range r.Accounts {
		quota.Evaluate(&r.Accounts[i], at)
	}
	in := advise.Input{Report: r, Digest: d, State: advise.Load(""), Now: at}
	return Build(Input{Report: r, Digest: d, State: store.State{PublicationID: "p1", CheckedAt: now.Add(-time.Hour)}, Events: advise.Derive(in),
		Boundaries: advise.Boundaries(in), Ledger: []speed.Row{{Day: "2026-10-18", Source: "claude-code", Model: "claude-opus-5-5", Requests: 6}}, Recording: true, Now: at})
}

func TestRevisionAndValidUntil(t *testing.T) {
	a := clocked(now, 40)
	if a.Sessions[0].EffortStatus != "unreported" || a.Sessions[0].Effort == nil || !a.Sessions[0].Effort.Star {
		t.Errorf("no reported effort: unreported, with the ★ fallback kept: %+v", a.Sessions[0])
	}
	// The recent rate of the reading taken two minutes ago lapses first, ten minutes after it.
	if a.ValidUntil == nil || !a.ValidUntil.Equal(now.Add(8*time.Minute)) {
		t.Fatalf("validUntil = %v", a.ValidUntil)
	}
	b := clocked(now.Add(5*time.Minute), 40)
	if b.DataRevision != a.DataRevision || !b.ValidUntil.Equal(*a.ValidUntil) {
		t.Errorf("five minutes later, no boundary crossed: %s %v, was %s %v", b.DataRevision, b.ValidUntil, a.DataRevision, a.ValidUntil)
	}
	c := clocked(now.Add(31*time.Minute), 40)
	w := c.Accounts[0].Windows[0]
	if c.DataRevision != a.DataRevision || w.Pace != "reset_passed" || w.RemainingPercent != nil || w.UsedPercent != nil || w.UnknownReason != "reset_passed" {
		t.Errorf("past the reset: same revision, allowance unknown until read again: %s %+v", c.DataRevision, w)
	}
	if c.ValidUntil == nil || !c.ValidUntil.Equal(now.Add(58*time.Minute)) {
		t.Errorf("past the reset the next boundary is the reading going stale: %v", c.ValidUntil)
	}
	types := func(s Snapshot) (out []string) {
		for _, e := range s.Events {
			out = append(out, e.Type)
		}
		return
	}
	if strings.Join(types(a), ",") == strings.Join(types(c), ",") {
		t.Errorf("the events follow the clock: %v and %v", types(a), types(c))
	}
	if d := clocked(now, 41); d.DataRevision == a.DataRevision {
		t.Error("a changed reading changes the revision")
	}
}

func TestActivity(t *testing.T) {
	_, r := fixture()
	done := now.Add(-30 * time.Minute)
	p := &speed.PerfView{OK: true, Recording: true, Now: now, Ledger: speed.PerfLedger{Since: now.Add(-time.Hour), Rows: []speed.PerfRow{{Day: "2026-10-18", Source: "claude-code", Model: "claude-opus-5-5", LastAt: &done}}}}
	s := Build(Input{Report: r, Perf: p, Now: now})
	cc, cx := s.Sessions[0].Activity, s.Sessions[1].Activity
	// Claude Code's status line time (two minutes ago) is no sign of activity; its last completed
	// request is half an hour old. Codex's turn started two minutes ago.
	if cc.Status != "quiet" || cc.Basis != "completed-request" || !cc.LastSignalAt.Equal(done) || cx.Status != "recent" || cx.Basis != "turn-started" || cx.WithinMinutes != 10 {
		t.Errorf("activity = %+v, %+v", cc, cx)
	}
	if s.ValidUntil == nil || s.ValidUntil.After(now.Add(8*time.Minute)) {
		t.Errorf("validUntil = %v: the Codex signal lapses at +8 min", s.ValidUntil)
	}
	empty := Build(Input{Report: quota.Report{Accounts: []quota.Account{{Source: "claude-code", Harness: &quota.Harness{Model: "x"}}}}, Perf: &speed.PerfView{OK: true, Now: now}, Now: now})
	if a := empty.Sessions[0].Activity; a.Status != "unknown" || a.LastSignalAt != nil {
		t.Errorf("no timestamp: %+v", a)
	}
}

func TestLocalUsageSnapshotRevision(t *testing.T) {
	u := localusage.Report{Source: "gemini", Enabled: true, Status: "ok", EvaluatedAt: now, Rows: []localusage.Row{{Day: "2026-10-18", Model: "gemini-test", Messages: 1}}}
	build := func(u localusage.Report, at time.Time) Snapshot {
		return Build(Input{LocalUsage: []localusage.Report{u}, Connections: []connections.Connection{{ID: "gemini", LocalUsage: &u}}, Now: at})
	}
	a := build(u, now)
	u.EvaluatedAt = now.Add(time.Minute)
	b := build(u, now.Add(time.Minute))
	if a.DataRevision != b.DataRevision || len(b.LocalUsage) != 1 {
		t.Fatal("evaluation clock changed observation revision")
	}
	if a.ValidUntil == nil || a.ValidUntil.Day() != now.AddDate(0, 0, 1).Day() {
		t.Fatalf("midnight refresh missing: %v", a.ValidUntil)
	}
	u.Rows = []localusage.Row{{Day: "2026-10-18", Model: "gemini-test", Messages: 2}}
	if build(u, now).DataRevision == a.DataRevision {
		t.Fatal("new Gemini usage did not change revision")
	}
}
