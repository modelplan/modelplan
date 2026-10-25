// SPDX-License-Identifier: MIT
// Package contracttest builds independent synthetic command outputs for wire tests.
// It is imported by tests only and contains no account, benchmark or design fixture.
package contracttest

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/history"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/snapshot"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
)

type Case struct {
	ID, Description, Coverage string
	Desktop                   snapshot.Snapshot
	Publication               digest.Publication
}

var Now = time.Date(2026, 10, 20, 21, 5, 0, 0, time.UTC)

func ptr[T any](v T) *T { return &v }

// Client is deliberately authored here rather than copied from a producer fixture.
const Client = `{
"schemaVersion":1,"kind":"client","data":{
"units":{"ability":"websiteAbility","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"},
"models":[
{"id":"synthetic-z","name":"Synthetic Z","developerId":"synthetic-dev","recommended":"medium","harnessIds":{"codex":["native-z"],"claude-code":["native-z"]},"efforts":[
{"effort":"medium","label":"Med","ability":50,"abilityBasis":"measured","cost":2,"costBasisId":"synthetic-reference","time":1,"timeBasis":{"source":"synthetic","cohort":"contract","boundary":"trial_wall","referenceSeconds":10},"timeEstimated":false},
{"effort":"high","label":"High","ability":55,"cost":3,"costBasisId":"synthetic-reference","time":null,"timeBasis":null}]},
{"id":"synthetic-one","name":"Synthetic Single","developerId":"other-dev","recommended":"native","harnessIds":{"codex":["native-one"]},"efforts":[{"effort":"native","label":"Native","ability":null,"abilityBasis":"assumed-highest","cost":null,"time":null}]}],
"lineups":[{"developerId":"synthetic-dev","costBasisId":"synthetic-reference","method":"lineup-v1","tie":1,"baseline":"synthetic-z","frontier":["synthetic-z"],"steps":[],"members":[{"id":"synthetic-z","status":"frontier","ability":50,"cost":2,"costRelative":1,"tags":["strongest","best_value","cheapest"],"dominatedBy":null}]}],
"speedTiers":[{"id":"synthetic-fast","harness":"codex","tier":"fast","label":"Fast","toggle":"/fast","eligibility":{"plans":["synthetic-plan"],"note":"published scenario, not user entitlement"},"models":[{"vendorModelId":"native-z","modelId":"synthetic-z","speed":{"ratio":2,"qualifier":"up-to"}}],"billing":[{"account":"subscription","billsTo":"plan-quota","basis":"included-usage","ratio":2}],"caveats":["not-task-time"],"sources":["https://example.test/fast"]}],
"resets":[{"id":"synthetic-announced","provider":"synthetic-provider","eventType":"quota_reset_announced","status":"announced","schedule":{"from":"2026-10-21T01:00:00Z","through":"2026-10-21T03:00:00Z"},"post":{"url":"https://example.test/reset"}},
{"id":"synthetic-confirmed","provider":"synthetic-provider","eventType":"quota_reset_completed","status":"confirmed","confirmedAt":"2026-10-20T21:00:00Z","post":{"url":"https://example.test/confirmed"}}],
"windows":[{"id":"synthetic-window","startsAt":"2026-10-21T00:00:00Z","endsAt":"2026-10-21T02:00:00Z","planIds":["synthetic-plan"],"clients":["codex"],"status":"announced"}],
"multipliers":[{"ruleId":"synthetic-rule","provider":"synthetic-provider","kind":"offpeak","models":["synthetic-z"],"clients":["codex"],"planIds":["synthetic-plan"],"generations":[],"region":"synthetic","timezone":"UTC","multiplier":0.5,"startsAt":"2026-10-21T00:00:00Z","endsAt":"2026-10-21T02:00:00Z","priority":1,"status":"published","minClientVersions":{},"requiresQuotaAvailable":true,"conditions":["published-scenario"],"url":"https://example.test/window"}],
"multiplierHorizon":{"from":"2026-10-20T21:05:00Z","to":"2026-10-22T21:05:00Z","selection":"highest-priority-no-stacking"}
}}`

func Public() (*digest.Digest, error) {
	d, err := digest.Parse(digest.ComponentClient, []byte(Client))
	if err != nil {
		return nil, err
	}
	d.PublicationID = "synthetic-contract-publication"
	d.PublishedAt = "2026-10-20T20:00:00Z"
	return d, nil
}
func account(i int) quota.Account {
	source := fmt.Sprintf("synthetic-source-%02d", i)
	if i == 0 {
		source = "codex"
	}
	if i == 1 {
		source = "claude-code"
	}
	seen := Now.Add(-time.Minute)
	a := quota.Account{Source: source, Plan: "synthetic-plan", ObservedAt: seen, Headroom: "normal",
		Subscription: &quota.Binding{Ref: fmt.Sprintf("synthetic-sub-%02d", i), Status: "verified", Basis: "synthetic-binding", ObservedAt: seen}}
	for _, w := range []struct {
		k string
		n int
	}{{"five_hour", 300}, {"weekly", 10080}} {
		a.Windows = append(a.Windows, quota.Window{Kind: w.k, UsedPercent: ptr(60.0), RemainingPercent: ptr(40.0), WindowMinutes: w.n,
			ResetsAt: ptr(Now.Add(time.Duration(w.n/2) * time.Minute)), ObservedAt: seen, ResetMode: "fixed", ElapsedPercent: ptr(50.0), AgeMinutes: ptr(1), Pace: "on_track"})
	}
	if i < 2 {
		a.Harness = &quota.Harness{Model: "native-z", Effort: "medium", ObservedAt: &seen, Attribution: "recent-thread"}
	}
	return a
}
func input(d *digest.Digest, n, working int) snapshot.Input {
	in := snapshot.Input{Digest: d, Now: Now, Recording: true, ProjectLabels: true, CLIVersion: "synthetic-v1",
		State: store.State{PublicationID: d.PublicationID, PublishedAt: d.PublishedAt, CheckedAt: Now.Add(-time.Minute), VerifiedAt: Now.Add(-time.Minute)}}
	for i := 0; i < n; i++ {
		a := account(i)
		in.Report.Accounts = append(in.Report.Accounts, a)
		in.Report.Sources = append(in.Report.Sources, quota.SourceStatus{Source: a.Source, Status: "ok"})
	}
	p := &speed.PerfView{OK: true, LongOK: true, Recording: true, Now: Now,
		Ledger: speed.PerfLedger{SchemaVersion: 1, Since: Now.Add(-30 * 24 * time.Hour)}, Long: speed.LongLedger{SchemaVersion: 1, Since: Now.Add(-370 * 24 * time.Hour)}}
	if n > 0 {
		for j, v := range []struct{ tokens, ms int64 }{{100, 1000}, {900, 90000}} {
			p.Ledger.Rows = append(p.Ledger.Rows, speed.PerfRow{Day: "2026-10-20", Source: "codex", Model: "native-z", Effort: "medium", EffortStatus: "reported", Parser: speed.ParserCodex, Eligibility: speed.EligibilityV1,
				ObservedRequests: 5, ObservedOutputTokens: v.tokens, EligibleRequests: 5, EligibleOutputTokens: v.tokens, GenMs: v.ms, LastAt: ptr(Now.Add(time.Duration(-j-1) * time.Minute))})
		}
		p.Ledger.Hourly = []speed.Hourly{{Hour: "2026-10-20T19:00:00Z", Source: "codex", Model: "native-z", ObservedOutputTokens: 0, ObservedRequests: 0}, {Hour: "2026-10-20T20:00:00Z", Source: "codex", Model: "native-z", ObservedOutputTokens: 1000, ObservedRequests: 10}}
		p.Ledger.Sessions = []speed.PerfSession{{Ref: "synthetic-completed", Key: "synthetic-internal", Source: "codex", SubscriptionRef: "synthetic-sub-00", ProjectRef: "synthetic-project", ProjectLabel: "Synthetic project", FirstAt: Now.Add(-time.Hour), LastAt: Now.Add(-10 * time.Minute), Days: []speed.SessionDay{{Day: "2026-10-20", Model: "native-z", Effort: "medium", EffortStatus: "reported", ObservedRequests: 10, ObservedOutputTokens: 1000}}}}
		p.Long.Rows = []speed.Daily{{Day: "2026-10-19", Source: "codex", Model: "native-z", ObservedRequests: 2, ObservedOutputTokens: 200}}
	}
	for i := 0; i < working && i < n; i++ {
		samples := []map[string]any{}
		for j := 0; j < 5; j++ {
			samples = append(samples, map[string]any{"at": Now.Add(time.Duration(-j-1) * time.Second), "out": int64(100), "genMs": int64(1000), "eligible": true})
		}
		raw, _ := json.Marshal(map[string]any{"key": fmt.Sprintf("synthetic-internal-%d", i), "ref": fmt.Sprintf("synthetic-live-%d", i), "source": in.Report.Accounts[i].Source, "model": "native-z", "effort": "medium", "projectRef": "synthetic-project", "subscriptionRef": fmt.Sprintf("synthetic-sub-%02d", i), "startedAt": Now.Add(-time.Minute), "lastAt": Now.Add(-time.Second), "running": true, "samples": samples})
		var live speed.LiveRecord
		if err := json.Unmarshal(raw, &live); err != nil {
			panic(err)
		}
		p.Ledger.Live = append(p.Ledger.Live, live)
	}
	in.Perf = p
	return in
}

func Cases() ([]Case, error) {
	base, err := Public()
	if err != nil {
		return nil, err
	}
	var out []Case
	add := func(id, desc, coverage string, n, working int, edit func(*snapshot.Input, *digest.Digest)) {
		d, e := Public()
		if e != nil {
			panic(e)
		}
		in := input(base, n, working)
		in.Digest = d
		if edit != nil {
			edit(&in, d)
		}
		if !in.Now.Equal(Now) {
			shift := in.Now.Sub(Now)
			for i := range in.Report.Accounts {
				a := &in.Report.Accounts[i]
				a.ObservedAt = a.ObservedAt.Add(shift)
				if a.Subscription != nil {
					a.Subscription.ObservedAt = a.Subscription.ObservedAt.Add(shift)
				}
				if a.Harness != nil && a.Harness.ObservedAt != nil {
					at := a.Harness.ObservedAt.Add(shift)
					a.Harness.ObservedAt = &at
				}
				for j := range a.Windows {
					w := &a.Windows[j]
					w.ObservedAt = w.ObservedAt.Add(shift)
					if w.ResetsAt != nil {
						at := w.ResetsAt.Add(shift)
						w.ResetsAt = &at
					}
				}
			}
			in.State.CheckedAt = in.State.CheckedAt.Add(shift)
			in.State.VerifiedAt = in.State.VerifiedAt.Add(shift)
			d.PublishedAt = in.Now.Add(-time.Hour).Format(time.RFC3339)
			in.State.PublishedAt = d.PublishedAt
			in.Perf.Ledger.Rows = nil
			in.Perf.Ledger.Sessions = nil
			in.Perf.Long.Rows = nil
			in.Perf.Ledger.Since = in.Now.Add(-48 * time.Hour)
			in.Perf.Long.Since = in.Now.Add(-48 * time.Hour)
		}
		out = append(out, Case{id, desc, coverage, snapshot.Build(in), d.Publication()})
	}
	add("F01", "four subscriptions, two attributed working sessions", "data", 4, 2, nil)
	add("F01-idle", "four subscriptions, no working sessions", "data", 4, 0, nil)
	add("F01-one-working", "four subscriptions, one working session", "data", 4, 1, nil)
	add("F01-six-working", "six distinct subscriptions, six working sessions", "data", 6, 6, nil)
	add("F02", "critical known zero with observed credits and threshold boundaries", "data", 5, 0, func(in *snapshot.Input, d *digest.Digest) {
		for i, v := range []float64{0, 15, 16, 40, 41} {
			in.Report.Accounts[i].Windows[0].RemainingPercent = ptr(v)
		}
		in.Report.Accounts[0].Headroom = "exhausted"
		in.Report.Accounts[0].Credits = &quota.Credits{Balance: ptr(12.0), ObservedAt: Now}
	})
	add("F03", "unknown/stale values and passed reset; no invented fresh quota", "data", 4, 1, func(in *snapshot.Input, d *digest.Digest) {
		w := &in.Report.Accounts[0].Windows[0]
		w.RemainingPercent = nil
		w.UsedPercent = nil
		w.ResetsAt = nil
		w.WindowMinutes = 0
		w.Pace = "unknown"
		in.Report.Accounts[1].Stale = true
		in.Report.Sources[1].Status = "unreadable"
		in.Report.Accounts[2].Windows[0].ResetsAt = ptr(Now.Add(-time.Minute))
		in.Report.Accounts[2].Windows[0].RemainingPercent = nil
		in.Report.Accounts[2].Windows[0].Pace = "reset_passed"
		in.Perf.Ledger.Live[0].LastAt = Now.Add(-10 * time.Minute)
	})
	add("F03-recording-off", "recording off with empty local history", "data", 1, 0, func(in *snapshot.Input, d *digest.Digest) {
		in.Recording = false
		in.Perf = nil
		in.Pace = nil
		in.Report.Accounts[0].Harness.Effort = ""
	})
	for _, n := range []int{0, 1, 2, 4, 6, 7, 10, 13} {
		add(fmt.Sprintf("F04-%02d", n), "stable subscription IDs for pagination; layout remains UI-owned", "data-prerequisites", n, 0, nil)
	}
	add("F05", "duplicate source bindings do not prove historical account ownership", "data", 2, 1, func(in *snapshot.Input, d *digest.Digest) {
		in.Report.Accounts[1].Source = "codex"
		in.Perf.Ledger.Live[0].SubscriptionRef = ""
	})
	add("F06", "current differs from star; single setting and nullable scores", "data", 2, 0, func(in *snapshot.Input, d *digest.Digest) { in.Report.Accounts[0].Harness.Effort = "high" })
	add("F06-many-efforts", "more than five published native efforts", "data", 1, 0, func(in *snapshot.Input, d *digest.Digest) {
		var c map[string]any
		_ = json.Unmarshal([]byte(Client), &c)
		data := c["data"].(map[string]any)
		models := data["models"].([]any)
		m := models[0].(map[string]any)
		efforts := m["efforts"].([]any)
		for i := 0; i < 5; i++ {
			efforts = append(efforts, map[string]any{"effort": fmt.Sprintf("extra-%d", i), "label": "Synthetic", "ability": nil, "cost": nil, "time": nil})
		}
		m["efforts"] = efforts
		raw, _ := json.Marshal(c)
		newD, e := digest.Parse(digest.ComponentClient, raw)
		if e != nil {
			panic(e)
		}
		newD.PublicationID = d.PublicationID
		newD.PublishedAt = d.PublishedAt
		*d = *newD
	})
	add("F07", "fast compatibility and up-to qualifier; trial is UI-owned", "data-prerequisites", 2, 0, func(in *snapshot.Input, d *digest.Digest) { in.Report.Accounts[0].Harness.ServiceTier = "fast" })
	add("F08", "0/1/2/6/unknown reserve counts, 30h/48h expiry and MCP extra", "data", 5, 0, func(in *snapshot.Input, d *digest.Digest) {
		for i, count := range []int{0, 1, 2, 6} {
			in.Report.Accounts[i].Cards = []quota.Card{{Kind: "reset", Count: ptr(count), ExpiresAt: ptr(Now.Add(time.Duration(30+i*6) * time.Hour))}}
		}
		in.Report.Accounts[4].Cards = []quota.Card{{Kind: "reset", Count: nil, ExpiresAt: nil}}
		in.Report.Accounts[0].Credits = &quota.Credits{Balance: ptr(0.0), ObservedAt: Now}
		w := in.Report.Accounts[2].Windows[1]
		w.Kind = "monthly"
		w.Limit = "MCP"
		w.WindowMinutes = 43200
		in.Report.Accounts[2].Windows = []quota.Window{w}
	})
	add("F09", "unequal generation durations, observed zero and missing hour", "data", 2, 0, nil)
	add("F10", "371 daily rows, observed retention coverage", "data", 1, 0, func(in *snapshot.Input, d *digest.Digest) {
		in.Perf.Long.Rows = nil
		for i := 370; i >= 0; i-- {
			in.Perf.Long.Rows = append(in.Perf.Long.Rows, speed.Daily{Day: Now.AddDate(0, 0, -i).Format("2006-01-02"), Source: "codex", Model: "native-z", ObservedOutputTokens: int64(i), ObservedRequests: 1})
		}
	})
	add("F10-short", "short coverage does not invent older heatmap values", "data", 1, 0, func(in *snapshot.Input, d *digest.Digest) { in.Perf.Long.Since = Now.Add(-24 * time.Hour) })
	add("F11", "ten observed quota cycles; ambiguous meter drop is not redemption", "data", 1, 0, func(in *snapshot.Input, d *digest.Digest) {
		in.Pace = &history.PaceView{OK: true, Recording: true, Now: Now, Ledger: history.PaceLedger{SchemaVersion: 1, Since: Now.Add(-72 * time.Hour)}}
		for i := 0; i < 10; i++ {
			end := Now.Add(time.Duration(-i*5-1) * time.Hour)
			in.Pace.Ledger.Cycles = append(in.Pace.Ledger.Cycles, history.PaceCycle{Source: "codex", Kind: "five_hour", WindowMinutes: 300, LengthBasis: "reported", ResetsAt: end, FirstObservedAt: end.Add(-4 * time.Hour), LastObservedAt: end.Add(-time.Hour), FirstUsed: 10, LastUsed: 40, Readings: 12, Drops: i % 2, Points: 30, Spent: []history.Share{{Model: "native-z", Effort: "medium", Fast: true, Points: 30}}})
		}
	})
	add("F12", "six live sessions with project attribution and completed ranking", "data", 6, 6, nil)
	add("F12-labels-off", "opaque project refs retained; project labels hidden", "data", 2, 1, func(in *snapshot.Input, d *digest.Digest) { in.ProjectLabels = false })
	for _, id := range []string{"F13", "F14", "F15", "F16", "F17", "F20"} {
		add(id, "native UI/lifecycle scenario: command data prerequisites only", "data-prerequisites", 4, 2, nil)
	}
	add("F18", "mismatching publication IDs; personal quotas stay independent", "data", 2, 0, func(in *snapshot.Input, d *digest.Digest) {
		in.State.PublicationID = "synthetic-previous-publication"
		d.PublishedAt = ""
	})
	add("F19", "offset-distinct repeated hour and spring transition", "data", 1, 0, func(in *snapshot.Input, d *digest.Digest) {
		in.Now = time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
		in.Perf.Now = in.Now
		in.Perf.Ledger.Hourly = []speed.Hourly{{Hour: "2026-11-01T01:00:00-07:00", Source: "codex", Model: "native-z", ObservedOutputTokens: 1, ObservedRequests: 1}, {Hour: "2026-11-01T01:00:00-08:00", Source: "codex", Model: "native-z", ObservedOutputTokens: 2, ObservedRequests: 1}, {Hour: "2026-03-08T01:00:00-08:00", Source: "codex", Model: "native-z", ObservedOutputTokens: 0, ObservedRequests: 0}, {Hour: "2026-03-08T03:00:00-07:00", Source: "codex", Model: "native-z", ObservedOutputTokens: 3, ObservedRequests: 1}}
	})
	add("F19-spring", "23-hour local day and omitted nonexistent hour", "data", 1, 0, func(in *snapshot.Input, d *digest.Digest) {
		in.Now = time.Date(2026, 3, 8, 12, 0, 0, 0, time.UTC)
		in.Perf.Now = in.Now
		in.Perf.Ledger.Hourly = []speed.Hourly{{Hour: "2026-03-08T01:00:00-08:00", Source: "codex", Model: "native-z", ObservedOutputTokens: 0, ObservedRequests: 0}, {Hour: "2026-03-08T03:00:00-07:00", Source: "codex", Model: "native-z", ObservedOutputTokens: 3, ObservedRequests: 1}}
	})
	add("F07-unsupported-fast", "a published fast tier does not apply to an unmatched model", "data", 1, 0, func(in *snapshot.Input, d *digest.Digest) {
		in.Report.Accounts[0].Harness.Model = "native-one"
		in.Report.Accounts[0].Harness.ServiceTier = "fast"
	})
	add("F03-insufficient-rate", "four observed requests do not produce a session generation rate", "data", 1, 1, func(in *snapshot.Input, d *digest.Digest) {
		in.Perf.Ledger.Live[0].Samples = in.Perf.Ledger.Live[0].Samples[:4]
	})
	add("F08-fable", "reported extra model quota remains a labelled window, not an inferred entitlement", "data", 1, 0, func(in *snapshot.Input, d *digest.Digest) {
		w := in.Report.Accounts[0].Windows[1]
		w.Limit = "Fable"
		w.RemainingPercent = ptr(9.0)
		in.Report.Accounts[0].Windows = append(in.Report.Accounts[0].Windows, w)
	})
	add("F19-quarter-hour", "offset-bearing completion hour in a quarter-hour zone", "data", 1, 0, func(in *snapshot.Input, d *digest.Digest) {
		in.Perf.Ledger.Hourly = []speed.Hourly{{Hour: "2026-10-21T02:00:00+05:45", Source: "codex", Model: "native-z", ObservedOutputTokens: 7, ObservedRequests: 1}}
	})
	return out, nil
}
