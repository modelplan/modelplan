// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
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
