// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// gatedEngine is the real import engine (ledger, consent, logs) whose automatic runs can be held
// open ("running") and settled as a success or a failure, and whose explicit import can fail.
type gatedEngine struct {
	importEngine
	hold       atomic.Bool
	release    chan bool // true: settle by importing; false: fail the attempt
	manualFail atomic.Bool
	autoRuns   atomic.Int32
}

func (g *gatedEngine) RunOwed(ctx context.Context, days int, progress func(int, int)) ([]wire.HistoryImportSource, error) {
	g.autoRuns.Add(1)
	ok := true
	if g.hold.Load() {
		select {
		case ok = <-g.release:
		case <-ctx.Done():
			return nil, ctx.Err()
		}
	}
	if !ok {
		_ = speed.MarkOwedAttempt(g.st.Dir, []string{"codex"}, consent.Capture(), time.Now())
		return nil, errors.New("synthetic read failure")
	}
	return g.importEngine.RunOwed(ctx, days, progress)
}

func (g *gatedEngine) Run(ctx context.Context, days int, firstRun bool, progress func(int, int)) ([]wire.HistoryImportSource, error) {
	if g.manualFail.Load() {
		return nil, errors.New("synthetic read failure")
	}
	return g.importEngine.Run(ctx, days, firstRun, progress)
}

type retryHarness struct {
	t     *testing.T
	cache string
	e     *gatedEngine
	c     *appserver.ImportController
	h     map[string]appserver.Handler
	hooks consent.GrantHooks
}

func newRetryHarness(t *testing.T) *retryHarness {
	home := consentFixtureHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	codex := filepath.Join(home, ".codex")
	t.Setenv("CODEX_HOME", codex)
	dir := filepath.Join(codex, "sessions", "2026", "11", "01")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	at := func(d time.Duration) string {
		return time.Now().Add(-48*time.Hour + d).UTC().Format("2006-01-02T15:04:05.000Z")
	}
	cx := func(d time.Duration, kind, payload string) string {
		return fmt.Sprintf(`{"timestamp":%q,"type":%q,"payload":%s}`, at(d), kind, payload)
	}
	lines := []string{cx(0, "event_msg", `{"type":"task_started"}`), cx(0, "turn_context", `{"model":"m","effort":"high"}`),
		cx(2*time.Second, "event_msg", `{"type":"token_count","info":{"last_token_usage":{"output_tokens":300}}}`),
		cx(3*time.Second, "event_msg", `{"type":"task_complete","duration_ms":3000}`)}
	if err := os.WriteFile(filepath.Join(dir, "rollout-a.jsonl"), []byte(strings.Join(lines, "\n")+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	cache := filepath.Join(home, "modelplan-cache")
	r := &retryHarness{t: t, cache: cache}
	r.hooks = consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) { return consent.Record{}, nil }, Cleanup: func(scope string, forget bool) error {
		return quota.EraseScope(quota.Paths{Cache: cache}, scope, forget)
	}}
	r.consent([]string{consent.ScopeCodexLocalHistory}, []string{consent.ScopeClaudeLocalHistory})
	if err := speed.MarkAutoRequested(cache, time.Now()); err != nil {
		t.Fatal(err)
	}
	r.e = &gatedEngine{importEngine: importEngine{st: &store.Store{Dir: cache}}, release: make(chan bool, 1)}
	r.launch()
	return r
}

func (r *retryHarness) consent(allow, deny []string) {
	s, err := consent.EnsureStore(consent.Path())
	if err != nil {
		r.t.Fatal(err)
	}
	if _, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: fmt.Sprint(time.Now().UnixNano()), ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion, Allow: allow, Deny: deny}, r.hooks); err != nil {
		r.t.Fatal(err)
	}
}

// launch: a new engine on the same cache (the previous one, if any, shuts down).
func (r *retryHarness) launch() {
	if r.c != nil {
		r.c.Close()
	}
	r.c = appserver.NewImportController(r.e)
	r.h = appserver.HistoryImportHandlers(r.c)
	r.t.Cleanup(r.c.Close)
}

func (r *retryHarness) call(method, body string) error {
	_, err := r.h[method].Handle(context.Background(), json.RawMessage(body), appserver.Stamp{})
	return err
}

func (r *retryHarness) phase() wire.HistoryImportPhase {
	res, _ := r.h["history/import_status"].Handle(context.Background(), json.RawMessage(`{}`), appserver.Stamp{})
	return res.Data.(wire.HistoryImportStatus).Phase
}

// settle waits until no import runs and none is about to start.
func (r *retryHarness) settle() {
	quiet := 0
	for i := 0; i < 400 && quiet < 4; i++ {
		time.Sleep(15 * time.Millisecond)
		if r.phase() == wire.ImportRunning {
			quiet = 0
		} else {
			quiet++
		}
	}
}

func (r *retryHarness) covered() bool {
	l, _ := speed.LoadImported(r.cache)
	c, ok := l.Coverage["codex"]
	return ok && !c.From.IsZero()
}

// advance: every backoff has passed.
func (r *retryHarness) advance() {
	l, ok := speed.LoadImported(r.cache)
	if !ok {
		r.t.Fatal("ledger unreadable")
	}
	for k, a := range l.Attempts {
		a.Next = time.Now().Add(-time.Minute)
		l.Attempts[k] = a
	}
	b, _ := json.Marshal(l)
	if err := os.WriteFile(speed.ImportPath(r.cache), b, 0o600); err != nil {
		r.t.Fatal(err)
	}
}

// timer: what any scheduled retry does when it fires.
func (r *retryHarness) timer() { r.c.StartOwedAfter(time.Millisecond, 30) }

// The retry state machine for one source (Codex), with the real ledger, consent store and logs.
// States: idle (imported), owed (due now), scheduled (backing off after a failed attempt, a
// wake-up pending), running (an automatic import in progress). Events: grant (a committed consent
// change re-allowing the source; the engine checks after it), revoke, cancel, remove, success and
// failure (of the running automatic import; elsewhere of an explicit Import), launch (engine
// restart), timer (a scheduled retry fires; in "scheduled" after its backoff). Each cell checks the
// automatic runs the event starts, the coverage after it, and the coverage once every backoff has
// passed and a retry fires again: a Cancel, Remove or revoke is never undone by a timer.
func TestImportRetryStateMachine(t *testing.T) {
	type cell struct {
		state, event        string
		runs                int32
		coveredNow, covered bool
	}
	cells := []cell{
		{"idle", "grant", 0, true, true}, {"idle", "revoke", 0, false, false}, {"idle", "cancel", 0, true, true}, {"idle", "remove", 0, false, false},
		{"idle", "success", 0, true, true}, {"idle", "failure", 0, true, true}, {"idle", "launch", 0, true, true}, {"idle", "timer", 0, true, true},
		{"owed", "grant", 1, true, true}, {"owed", "revoke", 0, false, false}, {"owed", "cancel", 0, false, false}, {"owed", "remove", 0, false, false},
		{"owed", "success", 0, true, true}, {"owed", "failure", 0, false, true}, {"owed", "launch", 1, true, true}, {"owed", "timer", 1, true, true},
		{"scheduled", "grant", 0, false, true}, {"scheduled", "revoke", 0, false, false}, {"scheduled", "cancel", 0, false, false}, {"scheduled", "remove", 0, false, false},
		{"scheduled", "success", 0, true, true}, {"scheduled", "failure", 0, false, true}, {"scheduled", "launch", 0, false, true}, {"scheduled", "timer", 1, true, true},
		{"running", "grant", 0, true, true}, {"running", "revoke", 0, false, false}, {"running", "cancel", 0, false, false}, {"running", "remove", 0, true, true},
		{"running", "success", 0, true, true}, {"running", "failure", 0, false, true}, {"running", "launch", 1, true, true}, {"running", "timer", 0, true, true},
	}
	for _, tc := range cells {
		t.Run(tc.state+"/"+tc.event, func(t *testing.T) {
			r := newRetryHarness(t)
			switch tc.state { // set the state up
			case "idle":
				r.timer()
				r.settle()
				if !r.covered() {
					t.Fatal("setup: not imported")
				}
			case "scheduled":
				if err := speed.MarkOwedAttempt(r.cache, []string{"codex"}, consent.Capture(), time.Now()); err != nil {
					t.Fatal(err)
				}
				r.c.StartOwedAfter(time.Hour, 30)
			case "running":
				r.e.hold.Store(true)
				r.c.StartOwed(30)
				for i := 0; i < 200 && r.e.autoRuns.Load() == 0; i++ {
					time.Sleep(5 * time.Millisecond)
				}
				if r.phase() != wire.ImportRunning {
					t.Fatal("setup: no automatic import running")
				}
			}
			r.e.autoRuns.Store(0)
			running := tc.state == "running"
			finish := func(ok bool) { // settle a held run
				if running {
					r.e.release <- ok
					running = false
				}
			}
			switch tc.event {
			case "grant":
				r.consent([]string{consent.ScopeCodexLocalHistory}, nil)
				r.timer() // the engine's after-grant check
				finish(true)
			case "revoke":
				r.consent(nil, []string{consent.ScopeCodexLocalHistory})
				r.timer()
				finish(true)
			case "cancel":
				if err := r.call("history/import_cancel", `{}`); err != nil {
					t.Fatal(err)
				}
				running = false
			case "remove":
				err := r.call("history/import_remove", `{}`)
				if tc.state == "running" && err == nil {
					t.Fatal("remove while running was accepted")
				}
				finish(true)
			case "success":
				if running {
					finish(true)
				} else if err := r.call("history/import_start", `{"days":30,"firstRun":false}`); err != nil {
					t.Fatal(err)
				}
			case "failure":
				if running {
					finish(false)
				} else {
					r.e.manualFail.Store(true)
					if err := r.call("history/import_start", `{"days":30,"firstRun":false}`); err != nil {
						t.Fatal(err)
					}
				}
			case "launch":
				r.e.hold.Store(false)
				r.launch()
				running = false
				r.c.StartOwedAfter(time.Millisecond, 30) // the launch check
			case "timer":
				if tc.state == "scheduled" {
					r.advance()
				}
				r.timer()
				finish(true)
			}
			r.e.hold.Store(false)
			r.settle()
			if got := r.e.autoRuns.Load(); got != tc.runs {
				t.Fatalf("automatic runs %d, want %d", got, tc.runs)
			}
			if r.covered() != tc.coveredNow {
				t.Fatalf("imported now %v, want %v", r.covered(), tc.coveredNow)
			}
			r.e.manualFail.Store(false)
			r.advance()
			r.timer()
			r.settle()
			if r.covered() != tc.covered {
				t.Fatalf("imported after every backoff and a retry %v, want %v", r.covered(), tc.covered)
			}
		})
	}
}
