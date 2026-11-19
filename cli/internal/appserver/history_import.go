// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

// ImportEngine is what the history-import methods need from the engine; the command wires the
// real one (speed.Import under the consent fence) and tests wire a synthetic one. Run reads
// logs and may take minutes: it must stop when ctx is cancelled and write nothing then.
type ImportEngine interface {
	Run(ctx context.Context, days int, firstRun bool, progress func(done, total int)) ([]wire.HistoryImportSource, error)
	// State is read-only: it never touches the logs.
	State() wire.HistoryImportStatus
	Remove() error
}

// ImportController runs at most one import in the background and reports it. A run is not tied
// to the request that started it, so Settings can poll history/import_status and cancel it.
type ImportController struct {
	engine ImportEngine
	mu     sync.Mutex
	phase  wire.HistoryImportPhase
	days   int
	done   int
	total  int
	last   []wire.HistoryImportSource
	// revision counts settled runs and removals; see wire.HistoryImportStatus.Revision.
	revision int
	cancel   context.CancelFunc
	wg       sync.WaitGroup
	// owedPending: days of an owed import asked for while another ran; it starts when that one
	// ends (macrevd-967-2). closed: Close was called; nothing new starts.
	owedPending int
	closed      bool
	// cancelAsked: the user cancelled the current run; no queued follow-up starts after it,
	// whatever the run's own result (macrevd-967-3). Reset when a run starts.
	cancelAsked bool
	// timers: retries waiting for their delay; Cancel and Close stop them. retryGen: bumped by
	// Cancel and Close, so a timer already firing from before does nothing (macrevd-967-4).
	timers   []*time.Timer
	retryGen int
}

func NewImportController(e ImportEngine) *ImportController {
	return &ImportController{engine: e, phase: wire.ImportIdle}
}

// Close cancels a running import and waits for it.
func (c *ImportController) Close() {
	c.mu.Lock()
	c.closed = true
	c.stopRetriesLocked()
	cancel := c.cancel
	c.mu.Unlock()
	if cancel != nil {
		cancel()
	}
	c.wg.Wait()
}

func (c *ImportController) status() wire.HistoryImportStatus {
	st := c.engine.State()
	c.mu.Lock()
	defer c.mu.Unlock()
	st.SchemaVersion, st.Phase, st.Days, st.FilesDone, st.FilesTotal = 1, c.phase, c.days, c.done, c.total
	st.Sources = append([]wire.HistoryImportSource{}, c.last...)
	rev := c.revision
	st.Revision = &rev
	if st.Coverage == nil {
		st.Coverage = []wire.HistoryImportCoverage{}
	}
	return st
}

func (c *ImportController) start(p wire.HistoryImportStartParams) error {
	// A first-run start joins a running import (the engine may have started an owed one at
	// launch) and changes nothing once the first run is done, so the finished run's report
	// stays (G3-112). The engine itself would answer such a run with nothing to do.
	if p.FirstRun && c.engine.State().FirstRunDone {
		return nil
	}
	err := c.startRun(p.Days, func(ctx context.Context, progress func(int, int)) ([]wire.HistoryImportSource, error) {
		return c.engine.Run(ctx, p.Days, p.FirstRun, progress)
	})
	if err != nil && p.FirstRun {
		return nil // joins the running import
	}
	return err
}

// OwedRunner is the optional engine side of the launch and grant retry (G3-112).
type OwedRunner interface {
	// Owed reports, from the ledger and the consent in force, whether an import is owed.
	Owed() bool
	RunOwed(ctx context.Context, days int, progress func(done, total int)) ([]wire.HistoryImportSource, error)
}

// OwedScheduler is the optional engine side of the retry schedule: when the next owed retry is
// due (after its backoff), and the user's Cancel that stops automatic imports under the current
// grants (macrevd-967-4/-5).
type OwedScheduler interface {
	NextOwedAt(now time.Time) (time.Time, bool)
	CancelOwed()
}

// StartOwedAfter checks for an owed import after delay, off the launch or grant path (owner
// condition: the retry never disturbs). Cancel and Close stop a retry still waiting.
func (c *ImportController) StartOwedAfter(delay time.Duration, days int) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed {
		return
	}
	gen := c.retryGen
	c.timers = append(c.timers, time.AfterFunc(delay, func() {
		c.mu.Lock()
		stale := c.closed || gen != c.retryGen
		c.mu.Unlock()
		if !stale {
			c.StartOwed(days)
		}
	}))
}

// stopRetriesLocked stops every scheduled retry and invalidates one already firing.
func (c *ImportController) stopRetriesLocked() {
	for _, t := range c.timers {
		t.Stop()
	}
	c.timers, c.owedPending = nil, 0
	c.retryGen++
}

// scheduleNext wakes for the next owed retry once its backoff ends (macrevd-967-5).
func (c *ImportController) scheduleNext(days int) {
	s, ok := c.engine.(OwedScheduler)
	if !ok {
		return
	}
	now := time.Now()
	if at, due := s.NextOwedAt(now); due {
		c.StartOwedAfter(at.Sub(now), days)
	}
}

// StartOwed starts the owed import in the background when one is owed and none is running. It is
// quiet: a failure leaves the reported state as it was (the ledger keeps the attempt).
func (c *ImportController) StartOwed(days int) {
	r, ok := c.engine.(OwedRunner)
	if !ok {
		return
	}
	if !r.Owed() {
		c.scheduleNext(days) // owed later: wake when its backoff ends
		return
	}
	_ = c.startRunQuiet(days, func(ctx context.Context, progress func(int, int)) ([]wire.HistoryImportSource, error) {
		return r.RunOwed(ctx, days, progress)
	}, func() { c.owedPending = days }, true)
}

func (c *ImportController) startRun(days int, run func(context.Context, func(int, int)) ([]wire.HistoryImportSource, error)) error {
	return c.startRunOr(days, run, nil)
}

// startRunOr is startRun; when an import is running it calls busy (under the lock) instead.
func (c *ImportController) startRunOr(days int, run func(context.Context, func(int, int)) ([]wire.HistoryImportSource, error), busy func()) error {
	return c.startRunQuiet(days, run, busy, false)
}

// startRunQuiet is startRunOr; a quiet run that fails restores the state reported before it.
func (c *ImportController) startRunQuiet(days int, run func(context.Context, func(int, int)) ([]wire.HistoryImportSource, error), busy func(), quiet bool) error {
	c.mu.Lock()
	if c.closed {
		c.mu.Unlock()
		return ProtocolError{wire.CodeBusy}
	}
	if c.phase == wire.ImportRunning {
		if busy != nil {
			busy()
		}
		c.mu.Unlock()
		return ProtocolError{wire.CodeBusy}
	}
	before := struct {
		phase       wire.HistoryImportPhase
		days        int
		done, total int
		last        []wire.HistoryImportSource
	}{c.phase, c.days, c.done, c.total, c.last}
	ctx, cancel := context.WithCancel(context.Background())
	c.phase, c.days, c.done, c.total, c.last, c.cancel, c.cancelAsked = wire.ImportRunning, days, 0, 0, nil, cancel, false
	c.wg.Add(1)
	c.mu.Unlock()
	go func() {
		defer c.wg.Done()
		defer cancel()
		res, err := run(ctx, func(done, total int) {
			c.mu.Lock()
			c.done, c.total = done, total
			c.mu.Unlock()
		})
		c.mu.Lock()
		switch {
		case errors.Is(err, context.Canceled):
			c.phase = wire.ImportCancelled
		case err != nil && quiet:
			// An automatic retry never shows a failure; the ledger keeps its attempt.
			c.phase, c.days, c.done, c.total, c.last = before.phase, before.days, before.done, before.total, before.last
		case err != nil:
			c.phase = wire.ImportFailed
		default:
			c.phase, c.last = wire.ImportDone, res
		}
		c.revision++
		// An owed import asked for meanwhile starts now (a cancel leaves it for the next launch
		// or grant; the ledger still owes it).
		again := c.owedPending
		c.owedPending = 0
		stopped := errors.Is(err, context.Canceled) || c.closed || c.cancelAsked
		if stopped {
			again = 0
		}
		c.mu.Unlock()
		switch {
		case again > 0:
			c.StartOwed(again)
		case quiet && !stopped:
			c.scheduleNext(days) // the next attempt after this one's backoff
		}
	}()
	return nil
}

// HistoryImportHandlers: history/import_start answers at once with the running status;
// history/import_status polls it (read-only); history/import_cancel stops a running import
// without writing; history/import_remove deletes exactly the imported history.
func HistoryImportHandlers(c *ImportController) map[string]Handler {
	const capability = "history_import_v1"
	reply := func(stamp Stamp) (Reply, error) { return Reply{Stamp: stamp, Data: c.status()}, nil }
	return map[string]Handler{
		"history/import_start": {Capability: capability, Handle: func(_ context.Context, raw json.RawMessage, stamp Stamp) (Reply, error) {
			p, err := params[wire.HistoryImportStartParams](raw)
			if err != nil || p.Days < 1 || p.Days > 371 {
				return Reply{}, ProtocolError{wire.CodeInvalidParams}
			}
			if err := c.start(p); err != nil {
				return Reply{}, err
			}
			return reply(stamp)
		}},
		"history/import_status": {Capability: capability, Query: true, Handle: func(_ context.Context, raw json.RawMessage, stamp Stamp) (Reply, error) {
			if _, err := params[wire.Empty](raw); err != nil {
				return Reply{}, ProtocolError{wire.CodeInvalidParams}
			}
			return reply(stamp)
		}},
		"history/import_cancel": {Capability: capability, Handle: func(_ context.Context, raw json.RawMessage, stamp Stamp) (Reply, error) {
			if _, err := params[wire.Empty](raw); err != nil {
				return Reply{}, ProtocolError{wire.CodeInvalidParams}
			}
			c.mu.Lock()
			cancel := c.cancel
			running := c.phase == wire.ImportRunning
			if running {
				c.cancelAsked = true // recorded with the run, before its result settles
			}
			// The user stopped importing, whether or not a run is active (a retry may be waiting
			// for its delay or backoff, or the run settled just before this request): no scheduled
			// retry starts afterwards, and none under the current grants until a new one
			// (macrevd-967-4).
			c.stopRetriesLocked()
			c.mu.Unlock()
			// Stop the run first and wait for it to settle: an importer past its context check
			// can still commit, and that commit must not land after (and erase) the suppression.
			if running && cancel != nil {
				cancel()
			}
			c.wg.Wait() // the run has stopped and written nothing when this answers
			if s, ok := c.engine.(OwedScheduler); ok {
				s.CancelOwed()
			}
			return reply(stamp)
		}},
		"history/import_remove": {Capability: capability, Handle: func(_ context.Context, raw json.RawMessage, stamp Stamp) (Reply, error) {
			if _, err := params[wire.Empty](raw); err != nil {
				return Reply{}, ProtocolError{wire.CodeInvalidParams}
			}
			c.mu.Lock()
			running := c.phase == wire.ImportRunning
			c.mu.Unlock()
			if running {
				return Reply{}, ProtocolError{wire.CodeBusy}
			}
			if err := c.engine.Remove(); err != nil {
				return Reply{}, ProtocolError{wire.CodeInternal}
			}
			c.mu.Lock()
			c.phase, c.last, c.done, c.total = wire.ImportIdle, nil, 0, 0
			c.revision++
			c.mu.Unlock()
			r, _ := reply(stamp)
			r.Receipt = true
			return r, nil
		}},
	}
}
