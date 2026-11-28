// SPDX-License-Identifier: MIT
package appserver

import (
	"testing"
	"time"
)

// cancelMidway is owed until CancelOwed returns; CancelOwed reports that it was entered and
// waits to be let go, holding a Cancel after its generation bump and before the engine-side
// suppression.
type cancelMidway struct {
	countingOwed
	entered, release chan struct{}
}

func (c *cancelMidway) Owed() bool { return true }
func (c *cancelMidway) CancelOwed() {
	close(c.entered)
	<-c.release
}
func (c *cancelMidway) NextOwedAt(now time.Time) (time.Time, bool) { return time.Time{}, false }

// G3-112 / macrevd-967-4: a Cancel that lands between a due retry's generation check and its
// start stops that start. Deterministic: the hook holds the timer in exactly that window until
// Cancel has bumped the generation and waited for runs, and the engine still reports owed.
func TestCancelBetweenRetryCheckAndStartStartsNothing(t *testing.T) {
	e := &cancelMidway{entered: make(chan struct{}), release: make(chan struct{})}
	c := NewImportController(e)
	defer c.Close()
	h := HistoryImportHandlers(c)
	cancelled := make(chan error, 1)
	started := make(chan struct{})
	testHookRetryDue = func(start func()) {
		go func() { _, err := call(t, h, "history/import_cancel", `{}`); cancelled <- err }()
		<-e.entered // Cancel bumped the generation and found no run to wait for
		start()
		close(started)
	}
	defer func() { testHookRetryDue = nil }()
	c.StartOwedAfter(0, 30)
	<-started
	close(e.release)
	if err := <-cancelled; err != nil {
		t.Fatal(err)
	}
	c.Close() // waits for any run the retry started
	if n := e.runs.Load(); n != 0 {
		t.Fatalf("a retry checked before Cancel still started %d imports", n)
	}
}
