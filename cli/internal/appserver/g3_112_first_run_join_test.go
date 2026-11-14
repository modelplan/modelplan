// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"testing"

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
