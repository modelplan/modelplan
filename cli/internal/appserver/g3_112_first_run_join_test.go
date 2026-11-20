// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

// G3-112: the engine may start an owed import at launch or after a grant. The app's own first-run start
// then joins it instead of failing busy, and a first-run start after it finished changes nothing
// (the finished run's sources stay reported). An ordinary start while running is still busy.
func TestFirstRunStartJoinsTheLaunchImport(t *testing.T) {
	f := &fakeImport{started: make(chan struct{}), release: make(chan struct{})}
	c := NewImportController(owedFake{f, true})
	h := HistoryImportHandlers(c)
	c.StartOwed(30)
	<-f.started
	st, err := call(t, h, "history/import_start", `{"days":30,"firstRun":true}`)
	if err != nil || st.Phase != wire.ImportRunning {
		t.Fatalf("first-run start during the launch import: %+v %v", st, err)
	}
	if _, err := call(t, h, "history/import_start", `{"days":30,"firstRun":false}`); err == nil {
		t.Fatal("an ordinary start while running must stay busy")
	}
	close(f.release)
	done := waitPhase(t, h, wire.ImportDone)
	st, err = call(t, h, "history/import_start", `{"days":30,"firstRun":true}`)
	if err != nil || st.Phase != wire.ImportDone || len(st.Sources) != 2 || st.Sources[0].Turns != 3 || *st.Revision != *done.Revision {
		t.Fatalf("repeat first-run start after completion: %+v %v", st, err)
	}
	c.Close()
}

type owedFake struct {
	*fakeImport
	owed bool
}

func (o owedFake) Owed() bool { return o.owed }
func (o owedFake) RunOwed(ctx context.Context, days int, progress func(int, int)) ([]wire.HistoryImportSource, error) {
	return o.Run(ctx, days, true, progress)
}

// Nothing owed: no run starts and the status stays idle.
func TestStartOwedWithNothingOwedStaysIdle(t *testing.T) {
	c := NewImportController(owedFake{&fakeImport{started: make(chan struct{}), release: make(chan struct{})}, false})
	c.StartOwed(30)
	if st, _ := call(t, HistoryImportHandlers(c), "history/import_status", `{}`); st.Phase != wire.ImportIdle {
		t.Fatalf("%+v", st)
	}
}

// countingOwed runs every owed import to completion at once and counts the runs.
type countingOwed struct {
	block chan struct{} // the ordinary run waits on it
	owed  atomic.Bool
	runs  atomic.Int32
}

func (c *countingOwed) Run(ctx context.Context, days int, firstRun bool, progress func(int, int)) ([]wire.HistoryImportSource, error) {
	<-c.block
	return []wire.HistoryImportSource{}, nil
}
func (c *countingOwed) State() wire.HistoryImportStatus {
	return wire.HistoryImportStatus{Coverage: []wire.HistoryImportCoverage{}}
}
func (c *countingOwed) Remove() error { return nil }
func (c *countingOwed) Owed() bool    { return c.owed.Load() }
func (c *countingOwed) RunOwed(ctx context.Context, days int, progress func(int, int)) ([]wire.HistoryImportSource, error) {
	c.runs.Add(1)
	c.owed.Store(false)
	return []wire.HistoryImportSource{}, nil
}

// macrevd-967-2: a grant that makes an import owed while another import runs is not lost: the
// owed import starts when the running one ends.
func TestOwedImportAskedWhileBusyRunsAfterwards(t *testing.T) {
	e := &countingOwed{block: make(chan struct{})}
	c := NewImportController(e)
	h := HistoryImportHandlers(c)
	if _, err := call(t, h, "history/import_start", `{"days":30,"firstRun":false}`); err != nil {
		t.Fatal(err)
	}
	e.owed.Store(true)
	c.StartOwed(30) // busy: must be remembered
	if e.runs.Load() != 0 {
		t.Fatal("owed run started while busy")
	}
	close(e.block)
	for i := 0; i < 400 && e.runs.Load() == 0; i++ {
		time.Sleep(5 * time.Millisecond)
	}
	if e.runs.Load() != 1 {
		t.Fatalf("owed import asked while busy ran %d times, want 1", e.runs.Load())
	}
	c.Close()
}

// settlesOK finishes successfully once cancelled (its commit already happened), and counts owed runs.
type settlesOK struct{ countingOwed }

func (s *settlesOK) Run(ctx context.Context, days int, firstRun bool, progress func(int, int)) ([]wire.HistoryImportSource, error) {
	<-ctx.Done()
	return []wire.HistoryImportSource{}, nil
}

// macrevd-967-3: after the user pressed Cancel, no queued automatic import starts, even when the
// cancelled run itself settles successfully; that run's result stays successful.
func TestCancelSuppressesTheQueuedOwedImport(t *testing.T) {
	e := &settlesOK{}
	c := NewImportController(e)
	h := HistoryImportHandlers(c)
	if _, err := call(t, h, "history/import_start", `{"days":30,"firstRun":false}`); err != nil {
		t.Fatal(err)
	}
	e.owed.Store(true)
	c.StartOwed(30) // queued behind the running import
	st, err := call(t, h, "history/import_cancel", `{}`)
	if err != nil {
		t.Fatal(err)
	}
	time.Sleep(50 * time.Millisecond)
	if n := e.runs.Load(); n != 0 {
		t.Fatalf("queued owed import started after Cancel (%d runs)", n)
	}
	if st.Phase != wire.ImportDone {
		t.Fatalf("a run that settled successfully reports %s", st.Phase)
	}
	c.Close()
}

// failingOwed fails every owed run.
type failingOwed struct{ countingOwed }

func (f *failingOwed) RunOwed(ctx context.Context, days int, progress func(int, int)) ([]wire.HistoryImportSource, error) {
	f.runs.Add(1)
	return nil, errors.New("synthetic read failure")
}

// Owner condition: an automatic retry never shows anything. It waits its delay, and a failure is
// not reported as the import's state (Settings keeps what it showed before).
func TestOwedRetryIsDelayedAndFailsQuietly(t *testing.T) {
	e := &failingOwed{}
	e.owed.Store(true)
	c := NewImportController(e)
	h := HistoryImportHandlers(c)
	c.StartOwedAfter(80*time.Millisecond, 30)
	time.Sleep(20 * time.Millisecond)
	if e.runs.Load() != 0 {
		t.Fatal("the retry started without its delay")
	}
	for i := 0; i < 200 && e.runs.Load() == 0; i++ {
		time.Sleep(5 * time.Millisecond)
	}
	time.Sleep(20 * time.Millisecond)
	if e.runs.Load() != 1 {
		t.Fatalf("delayed retry ran %d times", e.runs.Load())
	}
	if st, _ := call(t, h, "history/import_status", `{}`); st.Phase != wire.ImportIdle {
		t.Fatalf("a failed automatic retry is visible: %s", st.Phase)
	}
	c.Close()
	// Close also stops a retry still waiting for its delay.
	e2 := &failingOwed{}
	e2.owed.Store(true)
	c2 := NewImportController(e2)
	c2.StartOwedAfter(30*time.Millisecond, 30)
	c2.Close()
	time.Sleep(60 * time.Millisecond)
	if e2.runs.Load() != 0 {
		t.Fatal("a retry started after Close")
	}
}

// scheduledOwed is an engine whose owed source fails every attempt and backs off like the ledger
// (base doubling, capped), on a short synthetic base.
type scheduledOwed struct {
	settlesOK
	mu        sync.Mutex
	base      time.Duration
	n         int
	next      time.Time
	at        []time.Time
	cancelled bool
}

func (s *scheduledOwed) owedAt() (time.Time, bool) {
	if s.cancelled || s.n >= 5 {
		return time.Time{}, false
	}
	return s.next, true
}
func (s *scheduledOwed) Owed() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	at, ok := s.owedAt()
	return ok && !time.Now().Before(at)
}
func (s *scheduledOwed) NextOwedAt(now time.Time) (time.Time, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	at, ok := s.owedAt()
	if ok && at.Before(now) {
		at = now
	}
	return at, ok
}
func (s *scheduledOwed) CancelOwed() {
	s.mu.Lock()
	s.cancelled = true
	s.mu.Unlock()
}
func (s *scheduledOwed) RunOwed(ctx context.Context, days int, progress func(int, int)) ([]wire.HistoryImportSource, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.n++
	s.at = append(s.at, time.Now())
	s.next = time.Now().Add(s.base << (s.n - 1))
	return nil, errors.New("synthetic failure")
}
func (s *scheduledOwed) runs() []time.Time {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]time.Time(nil), s.at...)
}

// macrevd-967-5: with no restart and no new grant, a failing owed source is retried when each
// backoff ends (doubling), and not after the cap.
func TestOwedRetryWakesForEachBackoffUntilTheCap(t *testing.T) {
	e := &scheduledOwed{base: 30 * time.Millisecond}
	c := NewImportController(e)
	defer c.Close()
	c.StartOwed(30)
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) && len(e.runs()) < 5 {
		time.Sleep(10 * time.Millisecond)
	}
	time.Sleep(600 * time.Millisecond) // past where a sixth attempt would come
	at := e.runs()
	if len(at) != 5 {
		t.Fatalf("attempts %d, want exactly 5 (the cap)", len(at))
	}
	for i := 1; i < len(at); i++ {
		if gap, want := at[i].Sub(at[i-1]), e.base<<(i-1); gap < want {
			t.Fatalf("attempt %d came %v after the previous, before its %v backoff", i+1, gap, want)
		}
	}
}

// macrevd-967-4: Cancel stops retries already scheduled (launch, grant or backoff), including one
// whose timer is due, and none starts afterwards under the same grant.
func TestCancelStopsScheduledRetries(t *testing.T) {
	e := &scheduledOwed{base: time.Hour}
	e.owed.Store(true)
	c := NewImportController(e)
	defer c.Close()
	h := HistoryImportHandlers(c)
	if _, err := call(t, h, "history/import_start", `{"days":30,"firstRun":false}`); err != nil {
		t.Fatal(err)
	}
	c.StartOwedAfter(80*time.Millisecond, 30) // a launch retry due soon
	c.StartOwedAfter(0, 30)                   // and one whose timer fires at once
	if _, err := call(t, h, "history/import_cancel", `{}`); err != nil {
		t.Fatal(err)
	}
	time.Sleep(200 * time.Millisecond)
	if n := len(e.runs()); n != 0 {
		t.Fatalf("Cancel was followed by %d automatic imports", n)
	}
}

// macrevd-967-4 (no active run): Cancel during a retry's delay or backoff stops it and records
// the cancel.
func TestCancelWithoutARunStopsAPendingRetry(t *testing.T) {
	e := &scheduledOwed{base: time.Hour}
	c := NewImportController(e)
	defer c.Close()
	c.StartOwedAfter(80*time.Millisecond, 30)
	if _, err := call(t, HistoryImportHandlers(c), "history/import_cancel", `{}`); err != nil {
		t.Fatal(err)
	}
	time.Sleep(160 * time.Millisecond)
	if n := len(e.runs()); n != 0 {
		t.Fatalf("Cancel during the delay still started %d automatic imports", n)
	}
	e.mu.Lock()
	defer e.mu.Unlock()
	if !e.cancelled {
		t.Fatal("Cancel without a run was not recorded")
	}
}

// slowStop settles only some time after it is cancelled, as an importer finishing its commit does,
// and records whether the run had settled when the suppression was persisted.
type slowStop struct {
	countingOwed
	settled       atomic.Bool
	settledAtMark atomic.Bool
}

func (s *slowStop) Run(ctx context.Context, days int, firstRun bool, progress func(int, int)) ([]wire.HistoryImportSource, error) {
	<-ctx.Done()
	time.Sleep(50 * time.Millisecond)
	s.settled.Store(true)
	return nil, ctx.Err()
}
func (s *slowStop) NextOwedAt(now time.Time) (time.Time, bool) { return time.Time{}, false }
func (s *slowStop) CancelOwed() { s.settledAtMark.Store(s.settled.Load()) }

// Post-merge sampling 11-15: Cancel stops the run and waits for it before it persists the
// suppression, so a commit past its context check cannot land after (and erase) the mark.
func TestCancelPersistsSuppressionOnlyAfterTheRunSettled(t *testing.T) {
	e := &slowStop{}
	c := NewImportController(e)
	h := HistoryImportHandlers(c)
	if _, err := call(t, h, "history/import_start", `{"days":30,"firstRun":false}`); err != nil {
		t.Fatal(err)
	}
	if _, err := call(t, h, "history/import_cancel", `{}`); err != nil {
		t.Fatal(err)
	}
	if !e.settledAtMark.Load() {
		t.Fatal("suppression was persisted while the run could still commit")
	}
	c.Close()
}
