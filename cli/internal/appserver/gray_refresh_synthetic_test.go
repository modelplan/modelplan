// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// grayRequestBackend records the view that Request reads before scheduling.
type grayRequestBackend struct {
	*SharedBackend
	views chan View
}

func (b *grayRequestBackend) Get(ctx context.Context) (View, error) {
	view, err := b.SharedBackend.Get(ctx)
	if err == nil { b.views <- view }
	return view, err
}

// The observation clock and reader callback are synthetic. Changes and Request
// use the production watcher and scheduler clocks; neither has a clock seam.
func TestGrayRefreshUnwatchedSessionAndCallback(t *testing.T) {
	mode := os.Getenv("MODELPLAN_TEST_GRAY_CHILD")
	if mode == "" {
		for _, name := range []string{"success", "failed-no-new-fact"} {
			t.Run(name, func(t *testing.T) {
				home := t.TempDir()
				ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
				defer cancel()
				exe, err := os.Executable()
				if err != nil { t.Fatal(err) }
				cmd := exec.CommandContext(ctx, exe, "-test.run=^TestGrayRefreshUnwatchedSessionAndCallback$")
				cmd.Env = append(os.Environ(), "MODELPLAN_TEST_GRAY_CHILD="+name, "HOME="+home, "USERPROFILE="+home)
				output, err := cmd.CombinedOutput()
				if err != nil { t.Fatalf("isolated child: %v\n%s", err, output) }
			})
		}
		return
	}
	if mode != "success" && mode != "failed-no-new-fact" { t.Fatal("unknown child mode") }
	failRead := mode == "failed-no-new-fact"
	// A child process confines the uncoupled watcher lifetime and restored HOME.
	func() {
			testenv.IsolateHome(t)
			t.Setenv("MODELPLAN_READERS", "passive")
			t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
			t.Setenv("MODELPLAN_CODEXBAR", "off")
			root := t.TempDir()
			cache, codex := filepath.Join(root, "cache"), filepath.Join(root, "codex")
			if err := os.MkdirAll(filepath.Join(cache, "observed", "readers"), 0700); err != nil { t.Fatal(err) }
			if err := os.MkdirAll(filepath.Join(codex, "sessions", "2026", "11", "02"), 0700); err != nil { t.Fatal(err) }
			now := time.Now().UTC().Truncate(time.Second)
			first, newer := now.Add(-61*time.Minute), now.Add(-time.Minute)
			rollout := filepath.Join(codex, "sessions", "2026", "11", "02", "rollout-2026-11-02T10-00-00-synthetic.jsonl")
			line := func(at time.Time, used int) string {
				return fmt.Sprintf(`{"timestamp":%q,"type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":%d,"window_minutes":300,"resets_at":%d},"plan_type":"plus"}}}`+"\n", at.Format(time.RFC3339), used, now.Add(2*time.Hour).Unix())
			}
			if err := os.WriteFile(rollout, []byte(line(first, 20)), 0600); err != nil { t.Fatal(err) }
			state, err := consent.EnsureStore(consent.Path())
			if err != nil { t.Fatal(err) }
			_, err = consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "synthetic-local", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeCodexLocalHistory}}, consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) { return consent.Record{}, nil }})
			if err != nil { t.Fatal(err) }
			paths := func(a consent.Admission) quota.Paths { return quota.Paths{Admission: &a, Cache: cache, CodexHome: codex} }
			b, err := NewSharedBackend(SharedConfig{Detect: func() detect.Report {
				return detect.Report{Tools: []detect.Tool{{Entry: detect.Entry{ProviderID: "codex"}, Detected: true}}}
			}, Paths: paths, Cleanup: func(string, bool) error { return nil }})
			if err != nil { t.Fatal(err) }
			observed := func(v View) time.Time {
				t.Helper()
				for _, row := range v.Projection.Rows {
					if row.ID == "codex" {
						for _, account := range row.Accounts {
							if account.ObservedAt != nil { return *account.ObservedAt }
						}
					}
				}
				t.Fatal("missing synthetic Codex observation")
				return time.Time{}
			}
			initial, err := b.Get(context.Background())
			if err != nil || !observed(initial).Equal(first) { t.Fatalf("initial synthetic read: %v", err) }
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			changes := b.Changes(ctx)
			select { case <-changes: case <-time.After(3*time.Second): t.Fatal("initial watcher sample missing") }
			watchStamp := func() [5]fileStamp {
				files := []string{consent.Path(), filepath.Join(cache, "state.json"), "", filepath.Join(cache, "observed"), filepath.Join(cache, "observed", "readers")}
				var result [5]fileStamp
				for i, file := range files {
					if info, err := os.Stat(file); err == nil {
						result[i] = fileStamp{size: info.Size(), modified: info.ModTime().UnixNano(), exists: true}
					}
				}
				return result
			}
			before := watchStamp()
			f, err := os.OpenFile(rollout, os.O_APPEND|os.O_WRONLY, 0)
			if err != nil { t.Fatal(err) }
			_, err = f.WriteString(line(newer, 30))
			if closeErr := f.Close(); err != nil || closeErr != nil { t.Fatalf("append: %v %v", err, closeErr) }
			if after := watchStamp(); after != before { t.Fatal("synthetic append changed a watched stamp") }
			select { case <-changes: t.Fatal("watcher unexpectedly noticed the session append"); case <-time.After(600*time.Millisecond): }
			// No watcher notification means the subscriber still holds its initial view.
			if !observed(initial).Equal(first) { t.Fatal("held snapshot changed") }
			type attempt struct { err error; observed time.Time }
			attempted := make(chan attempt, 1)
			started := make(chan struct{}, 1)
			release := make(chan struct{})
			preRequest := &grayRequestBackend{SharedBackend: b, views: make(chan View, 1)}
			fakeNow := now.Add(time.Minute)
			s := NewRefreshScheduler(ctx, RefreshConfig{Backend: preRequest, Paths: paths, Changed: b.Notify, Run: func(ctx context.Context, p quota.Paths, scope string, _ time.Time) error {
				started <- struct{}{}
				select { case <-release: case <-ctx.Done(): return ctx.Err() }
				if failRead { attempted <- attempt{err: errors.New("synthetic reader failure")}; return errors.New("synthetic reader failure") }
				err := quota.ExecuteScopeRefresh(ctx, p, scope, fakeNow)
				report := quota.ReadPermitted(p, fakeNow)
				var at time.Time
				for _, a := range report.Accounts { if a.Source == "codex" { at = a.ObservedAt } }
				attempted <- attempt{err: err, observed: at}
				return err
			}})
			defer s.Close()
			// Constructing the scheduler alone does not queue an automatic read.
			select { case <-started: t.Fatal("unsolicited callback before request"); case <-time.After(300*time.Millisecond): }
			receipt, _, err := s.Request(ctx, wire.RefreshRequestParams{Scopes: []string{consent.ScopeCodexLocalHistory}})
			if err != nil || len(receipt) != 1 || receipt[0].DisabledReason != nil { t.Fatalf("refresh not scheduled: %+v %v", receipt, err) }
			var beforeCallback View
			select { case beforeCallback = <-preRequest.views: case <-time.After(3*time.Second): t.Fatal("Request did not read backend") }
			if !observed(beforeCallback).Equal(newer) { t.Fatal("Request did not see the appended observation before its callback") }
			select { case <-started: case <-time.After(3*time.Second): t.Fatal("scheduled callback did not start") }
			select { case <-attempted: t.Fatal("callback completed before release"); default: }
			close(release)
			var got attempt
			select { case got = <-attempted: case <-time.After(3*time.Second): t.Fatal("reader callback was not invoked") }
			if failRead {
				if got.err == nil || !got.observed.IsZero() { t.Fatal("failure counted as a successful reader observation") }
			} else if got.err != nil || !got.observed.Equal(newer) { t.Fatalf("successful reader: %+v", got) }
			select { case <-changes: case <-time.After(3*time.Second): t.Fatal("refresh completion did not notify") }
			after, err := b.Get(ctx)
			if err != nil || !observed(after).Equal(newer) { t.Fatalf("reprojection did not pick up appended observation: %v", err) }
			// Even a failed callback notifies and a later Get rereads the independent
			// session file. That newer projection is not evidence the callback read it.
	}()
}

// The projector accepts an explicit clock, unlike the watcher and scheduler.
func TestGrayProjectionExpiresAtFreshnessDeadline(t *testing.T) {
	now := time.Date(2026, 11, 2, 10, 0, 0, 0, time.UTC)
	fresh := now.Add(time.Hour)
	reset := now.Add(3*time.Hour)
	remaining := 80.0
	in := rows.Input{Now: now, ConsentGeneration: 7,
		Catalogue: []rows.CatalogueEntry{{ToolID: "codex", Detected: true, ReaderExists: true}},
		Consents: []rows.ConsentRecord{{ToolID: "codex", Generation: 7, State: rows.ConsentAllowed}},
		Profiles: []rows.ProfileState{{ToolID: "codex", ProfileKey: "synthetic", LatestAttempt: rows.AttemptResultSucceeded, ObservedAt: &now, WithinFreshness: true, FreshUntil: &fresh}},
		Accounts: []rows.AccountInput{{ToolID: "codex", ProfileKey: "synthetic", Windows: []rows.WindowInput{{Kind: "five_hour", RemainingPercent: &remaining, ObservedAt: &now, ResetsAt: &reset}}}},
	}
	before := rows.Build(in)
	if len(before.Rows) != 1 || len(before.Rows[0].Accounts) != 1 { t.Fatal("missing synthetic account") }
	a := before.Rows[0].Accounts[0]
	if a.ValueState != rows.ValueStateCurrent || len(a.Windows) != 1 || !a.Windows[0].Current { t.Fatal("reading was not initially current") }
	if before.Rows[0].ExpiresAt == nil || !before.Rows[0].ExpiresAt.Equal(fresh) || before.Rows[0].StateAfterExpiry == nil || before.Rows[0].StateAfterExpiry.State != rows.StateStale { t.Fatal("missing stale expiry latch") }
	in.Now = fresh
	after := rows.Build(in)
	a = after.Rows[0].Accounts[0]
	if a.ValueState != rows.ValueStateRetained || a.Windows[0].Current { t.Fatal("reading stayed current at its deadline") }
	if a.ObservedAt == nil || !a.ObservedAt.Equal(now) { t.Fatal("expiry invented a new observation") }
}
