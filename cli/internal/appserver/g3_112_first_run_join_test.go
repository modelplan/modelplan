// SPDX-License-Identifier: MIT
package appserver

import (
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

// G3-112: the engine may start an owed first-run import at launch. The app's own first-run start
// then joins it instead of failing busy, and a first-run start after it finished changes nothing
// (the finished run's sources stay reported). An ordinary start while running is still busy.
func TestFirstRunStartJoinsTheLaunchImport(t *testing.T) {
	f := &fakeImport{started: make(chan struct{}), release: make(chan struct{})}
	c := NewImportController(f)
	h := HistoryImportHandlers(c)
	c.StartFirstRun(30)
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
