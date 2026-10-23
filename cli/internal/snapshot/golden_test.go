package snapshot

import (
	"encoding/json"
	"flag"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/advise"
	"github.com/modelplan/modelplan/cli/internal/connections"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/history"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
)

var update = flag.Bool("update", false, "rewrite testdata/snapshot.json")

func n(v int) *int { return &v }

// golden is a full snapshot: two harness sessions (one on a tight window, one on Codex Fast with a
// Reserve allowance), a CodexBar account, the advice a desktop client notifies about and measured
// speed from both ledgers. desktop/ reads testdata/snapshot.json, so the shell and the CLI share one contract.
func golden() Snapshot {
	e := func(k, l string, a, c, t float64) digest.Effort {
		return digest.Effort{Effort: k, Label: l, Ability: f(a), Cost: f(c), Time: f(t), CostBasisID: "ref"}
	}
	d := &digest.Digest{Models: []digest.Model{
		{ID: "opus", Name: "Claude Opus 5.5", DeveloperID: "anthropic", Recommended: "medium", HarnessIDs: map[string][]string{"claude-code": {"claude-opus-5-5"}},
			Efforts: []digest.Effort{e("low", "Low", 48.1, 1.62, 0.55), e("medium", "Med", 55.4, 2.91, 0.8), e("high", "High", 60.2, 3.98, 1), e("max", "Max", 61, 6.4, 1.6)}},
		{ID: "astra", Name: "GPT-6 Astra", DeveloperID: "openai", Recommended: "medium", HarnessIDs: map[string][]string{"codex": {"gpt-6-astra"}},
			Efforts: []digest.Effort{e("low", "Low", 45, 2.21, 0.4), e("medium", "Med", 51.4, 3.4, 0.45), e("high", "High", 53.9, 3.97, 0.6)}},
	}}
	at := func(m int) *time.Time { t := now.Add(time.Duration(m) * time.Minute); return &t }
	seen := now.Add(-2 * time.Minute)
	off, fast := false, 1.5
	r := quota.Report{SchemaVersion: 1, EvaluatedAt: now, Accounts: []quota.Account{
		{Source: "claude-code", ObservedAt: seen, Headroom: "conserve", Deciding: "five_hour",
			Subscription: &quota.Binding{Ref: "9b1e44d07a2c3f58", Status: "verified", Basis: "claude-config", ObservedAt: seen},
			Harness:      &quota.Harness{Model: "claude-opus-5-5", Effort: "high", FastMode: &off, Version: "2.3.1", ObservedAt: &seen, Attribution: "current-thread"},
			Windows: []quota.Window{
				{Kind: "five_hour", UsedPercent: f(88), WindowMinutes: 300, ResetsAt: at(95), ResetMode: "fixed", ObservedAt: seen, RemainingPercent: f(12), ResetsInMinutes: n(95),
					ElapsedPercent: f(68), ProjectedPercent: f(129), AgeMinutes: n(2), RecentPercentPerHour: f(20.6), RunsOutInMinutes: n(35), Pace: "tight"},
				{Kind: "weekly", UsedPercent: f(30), WindowMinutes: 10080, ResetsAt: at(4320), ResetMode: "fixed", ObservedAt: seen, RemainingPercent: f(70), ResetsInMinutes: n(4320),
					ElapsedPercent: f(57), ProjectedPercent: f(53), AgeMinutes: n(2), Pace: "on_track"},
			}},
		{Source: "codex", ObservedAt: seen, Headroom: "spend", Via: "codex-account",
			Harness: &quota.Harness{Model: "gpt-6-astra", Effort: "medium", ServiceTier: "fast", Version: "0.130.0", ObservedAt: &seen, Attribution: "recent-thread", Origin: "cli"},
			Windows: []quota.Window{
				{Kind: "five_hour", UsedPercent: f(20), WindowMinutes: 300, ResetsAt: at(40), ResetMode: "fixed", ObservedAt: seen, RemainingPercent: f(80), ResetsInMinutes: n(40),
					ElapsedPercent: f(87), ProjectedPercent: f(23), AgeMinutes: n(2), Pace: "surplus"},
				{Kind: "weekly", UsedPercent: f(45), WindowMinutes: 10080, ResetsAt: at(2880), ResetMode: "fixed", ObservedAt: seen, RemainingPercent: f(55), ResetsInMinutes: n(2880),
					ElapsedPercent: f(71), ProjectedPercent: f(63), AgeMinutes: n(2), Pace: "on_track"},
				{Kind: "weekly", Limit: "reserve", UsedPercent: f(10), WindowMinutes: 10080, ResetsAt: at(2880), ResetMode: "fixed", ObservedAt: seen, RemainingPercent: f(90),
					ResetsInMinutes: n(2880), AgeMinutes: n(2), Pace: "on_track"},
			}},
		{Source: "codexbar:zai", Plan: "GLM Coding Plan", ObservedAt: seen, Headroom: "normal", Via: "codexbar",
			Windows: []quota.Window{{Kind: "monthly", UsedPercent: f(40), ResetsAt: at(12 * 1440), ObservedAt: seen, RemainingPercent: f(60), ResetsInMinutes: n(12 * 1440), Pace: "on_track"}}},
	}, Sources: []quota.SourceStatus{{Source: "claude-code", Status: "ok"}, {Source: "codex", Status: "ok"}, {Source: "user", Status: "missing"}, {Source: "codexbar:zai", Status: "ok"}}}

	tight := advise.Event{Type: advise.WindowTight, Key: "window_tight|claude-code||five_hour|" + at(95).Format(time.RFC3339), Severity: "warn", Source: "claude-code",
		Window: "five_hour", At: at(95), InMinutes: n(95), RemainingPercent: f(12), RunsOutInMinutes: n(35), Model: "claude-opus-5-5", Effort: "high",
		Suggest: &advise.Step{Action: "step_down", Model: "opus", ModelName: "Claude Opus 5.5", Effort: "medium", Label: "Med", Recommended: true, AbilityDelta: f(-4.8), CostRatio: f(0.73)}}
	better := advise.Event{Type: advise.BetterModel, Key: "better|codex|astra|medium|sol-6.1|medium", Severity: "info", Source: "codex", Model: "gpt-6-astra", Effort: "medium",
		Suggest: &advise.Step{Action: "better_model", Model: "sol-6.1", ModelName: "GPT-6.1 Sol", Effort: "medium", Label: "Med", Recommended: true, Kind: "equivalent", AbilityDelta: f(-0.2), CostRatio: f(0.55)},
		Current: &advise.Step{Action: "current", Model: "astra", ModelName: "GPT-6 Astra", Effort: "medium", Label: "Med", Recommended: true}}
	surplus := advise.Event{Type: advise.ResetSoonSurplus, Key: "reset_soon_with_surplus|codex||five_hour|" + at(40).Format(time.RFC3339), Severity: "info", Source: "codex",
		Window: "five_hour", At: at(40), InMinutes: n(40), RemainingPercent: f(80), Model: "gpt-6-astra", Effort: "medium",
		Suggest: &advise.Step{Action: "step_up", Model: "astra", ModelName: "GPT-6 Astra", Effort: "high", Label: "High", AbilityDelta: f(2.5), CostRatio: f(1.17)},
		Fast:    &advise.Speed{Tier: "fast", Label: "Fast", QuotaRatio: 2, SpeedRatio: &fast, Qualifier: "approximate"}}
	back := advise.Event{Type: advise.SwitchBack, Key: "reset_passed_switch_back|claude-code|five_hour|" + now.Add(-30*time.Minute).Format(time.RFC3339), Severity: "info",
		Source: "claude-code", Window: "five_hour", At: at(-30), Model: "claude-opus-5-5", Effort: "low",
		Suggest: &advise.Step{Action: "switch_back", Model: "opus", ModelName: "Claude Opus 5.5", Effort: "medium", Label: "Med", Recommended: true}}

	rate := func(v float64) *float64 { return &v }
	measured := []speed.Stat{
		{Source: "claude-code", Model: "claude-opus-5-5", Effort: "high", Days: 6, Requests: 412, Turns: 38, OutputTokensPerSecond: rate(116), TTFTSeconds: rate(1.9), TurnSeconds: rate(142), TurnOutputTokens: rate(3800)},
		{Source: "claude-code", Model: "claude-opus-5-5", Effort: "medium", Days: 3, Requests: 120, Turns: 14, OutputTokensPerSecond: rate(121), TTFTSeconds: rate(1.6), TurnSeconds: rate(98), TurnOutputTokens: rate(2600)},
		{Source: "codex", Model: "gpt-6-astra", Effort: "medium", Speed: "fast", Days: 2, Requests: 3, Turns: 2},
	}
	// The performance ledger: Opus at High with enough samples over two days, Codex Fast with too few.
	// The long-term daily ledger keeps two older days, and a figure for 17 October that perf.json
	// has since grown past.
	last := now.Add(-40 * time.Minute)
	ttft := speed.Hist{"75": 3, "77": 6, "79": 2}
	long := speed.LongLedger{SchemaVersion: 1, Since: time.Date(2026, 4, 20, 7, 30, 0, 0, time.UTC), Rows: []speed.Daily{
		{Day: "2026-05-04", Source: "claude-code", Model: "claude-opus-5-5", ObservedOutputTokens: 52000, ObservedRequests: 61},
		{Day: "2026-09-15", Source: "codex", Model: "gpt-6-astra", ObservedOutputTokens: 8000, ObservedRequests: 12},
		{Day: "2026-10-17", Source: "claude-code", Model: "claude-opus-5-5", ObservedOutputTokens: 20000, ObservedRequests: 28},
	}}
	perf := &speed.PerfView{OK: true, Recording: true, Now: now, Long: long, LongOK: true, Ledger: speed.PerfLedger{SchemaVersion: 1, Since: now.Add(-3 * 24 * time.Hour), Rows: []speed.PerfRow{
		{Day: "2026-10-17", Source: "claude-code", Model: "claude-opus-5-5", EffortStatus: "reported", Effort: "high", Parser: speed.ParserClaude, Eligibility: speed.EligibilityV1,
			ObservedRequests: 30, ObservedOutputTokens: 21000, EligibleRequests: 6, EligibleOutputTokens: 4800, GenMs: 40000, Turns: 4, TurnMs: 380000, TurnOutputTokens: 15000,
			TTFTMs: ttft, TurnMsHist: speed.Hist{"133": 2, "135": 2}, TurnTokensHist: speed.Hist{"86": 2, "88": 2}, LastAt: &last},
		{Day: "2026-10-18", Source: "claude-code", Model: "claude-opus-5-5", EffortStatus: "reported", Effort: "high", Parser: speed.ParserClaude, Eligibility: speed.EligibilityV1,
			InputTokens: ptrTokens(3000), CacheReadTokens: ptrTokens(9000), CacheWriteTokens: ptrTokens(100), ObservedRequests: 12, ObservedOutputTokens: 9000, EligibleRequests: 3, EligibleOutputTokens: 2600, GenMs: 22000, Turns: 2, TurnMs: 200000, TurnOutputTokens: 6400,
			MixedConfigTurnsExcluded: 1, TurnMsHist: speed.Hist{"134": 2}, TurnTokensHist: speed.Hist{"87": 2}, LastAt: &last},
		{Day: "2026-10-18", Source: "codex", Model: "gpt-6-astra", EffortStatus: "reported", Effort: "medium", Speed: "fast", Parser: speed.ParserCodex, Eligibility: speed.EligibilityV1,
			ObservedRequests: 3, ObservedOutputTokens: 1800, EligibleRequests: 3, EligibleOutputTokens: 1800, GenMs: 9000, Turns: 1, TurnMs: 60000, TurnOutputTokens: 1800,
			TTFTMs: speed.Hist{"76": 3}, TurnMsHist: speed.Hist{"115": 1}, TurnTokensHist: speed.Hist{"78": 1}, LastAt: &last},
	}, Hourly: []speed.Hourly{{Hour: "2026-10-18T08:00:00Z", Source: "claude-code", Model: "claude-opus-5-5", ObservedRequests: 12, ObservedOutputTokens: 9000, InputTokens: ptrTokens(3000), CacheReadTokens: ptrTokens(9000), CacheWriteTokens: ptrTokens(100)}}, Live: []speed.LiveRecord{{Ref: "5c1e0d2a9b7f4e31", Key: "k1", Source: "claude-code", Model: "claude-opus-5-5", Effort: "high", ProjectRef: "3f0c9a7d51e24b68a0c4e9d2b7f1a385", SubscriptionRef: "9b1e44d07a2c3f58", StartedAt: now.Add(-time.Minute), LastAt: now.Add(-10 * time.Second), Running: true, Samples: []speed.LiveSample{{Key: "local-offset", End: now.Add(-10 * time.Second), Model: "claude-opus-5-5", Effort: "high", Out: 600, GenMs: 5000, Eligible: true}}}}, Sessions: []speed.PerfSession{
		{Ref: "5c1e0d2a9b7f4e31", Key: "k1", Source: "claude-code", SubscriptionRef: "9b1e44d07a2c3f58", ProjectRef: "3f0c9a7d51e24b68a0c4e9d2b7f1a385", ProjectLabel: "label-while-off", FirstAt: now.Add(-26 * time.Hour), LastAt: last, Days: []speed.SessionDay{
			{Day: "2026-10-17", Model: "claude-opus-5-5", EffortStatus: "reported", Effort: "high", ObservedRequests: 30, ObservedOutputTokens: 21000},
			{Day: "2026-10-18", Model: "claude-opus-5-5", EffortStatus: "reported", Effort: "high", ObservedRequests: 12, ObservedOutputTokens: 9000}}},
		{Ref: "a83f6c0e12d94b70", Key: "k2", Source: "codex", ProjectRef: "3f0c9a7d51e24b68a0c4e9d2b7f1a385", FirstAt: now.Add(-2 * time.Hour), LastAt: last, Days: []speed.SessionDay{
			{Day: "2026-10-18", Model: "gpt-6-astra", EffortStatus: "reported", Effort: "medium", Speed: "fast", ObservedRequests: 3, ObservedOutputTokens: 1800}}},
	}}}
	// The pace ledger: two closed Claude Code five-hour cycles and the open one.
	cyc := func(reset time.Duration, from, to float64, span time.Duration, drops int) history.PaceCycle {
		r := now.Add(reset)
		first := r.Add(-4 * time.Hour)
		return history.PaceCycle{Source: "claude-code", Kind: "five_hour", WindowMinutes: 300, LengthBasis: "field-name", ResetsAt: r, FirstObservedAt: first, FirstUsed: from,
			LastObservedAt: first.Add(span), LastUsed: to, Readings: 12, Drops: drops, Points: to - from, Spent: []history.Share{{Model: "claude-opus-5-5", Effort: "high", Points: to - from}}}
	}
	pace := &history.PaceView{OK: true, Recording: true, Now: now, Ledger: history.PaceLedger{SchemaVersion: 1, Since: now.Add(-3 * 24 * time.Hour), Cycles: []history.PaceCycle{
		cyc(-10*time.Hour, 5, 65, 3*time.Hour, 0), cyc(-5*time.Hour+5*time.Minute, 0, 70, 3*time.Hour+30*time.Minute, 0), cyc(95*time.Minute, 30, 88, 2*time.Hour, 0)}}}
	// Connections: Codex and Claude Code installed, Kiro's CLI on the path, CodexBar on for Z.ai.
	cb := filepath.Join(os.TempDir(), "modelplan-golden-codexbar.json")
	_ = os.WriteFile(cb, []byte(`{"schemaVersion":1,"providers":["zai"]}`), 0o600)
	found := map[string]bool{"/home/u/.codex": true, "/home/u/.claude": true, "/home/u/.local/bin/kiro-cli": true}
	conns := connections.Diagnose(connections.Env{Home: "/home/u", CodexHome: "/home/u/.codex", CodexBarFile: cb, Exists: func(p string) bool { return found[p] }}, r)
	return Build(Input{Report: r, Digest: d, Events: []advise.Event{tight, back, better, surplus}, Measured: measured, Perf: perf, Pace: pace, Connections: conns, Recording: true, CLIVersion: "0.5.25", Now: now,
		State: store.State{PublicationID: "0d726f2402d395a043fb170e", PublishedAt: "2026-10-18T01:50:38Z", CheckedAt: now.Add(-20 * time.Minute), VerifiedAt: now.Add(-20 * time.Minute)}})
}

func TestGoldenSnapshot(t *testing.T) {
	for _, k := range []string{"MODELPLAN_CODEXBAR", "MODELPLAN_CODEX_ACCOUNT", "XDG_DATA_HOME"} {
		t.Setenv(k, "")
	}
	// The text gives clock times in the machine's zone; the golden file is in UTC.
	defer func(l *time.Location) { time.Local = l }(time.Local)
	time.Local = time.UTC
	got, err := json.MarshalIndent(golden(), "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	got = append(got, '\n')
	if *update {
		if err := os.WriteFile("testdata/snapshot.json", got, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	want, err := os.ReadFile("testdata/snapshot.json")
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(want) {
		t.Errorf("testdata/snapshot.json is out of date (go test ./internal/snapshot -update):\n%s", got)
	}
}

func ptrTokens(n int64) *int64 { return &n }
