// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func TestActivityObserverNotifiesOnTransitionAndExpiry(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "")
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	phase := make(chan string, 3)
	phase <- "tool"
	phase <- "tool"
	phase <- "finished"
	at := time.Now().UTC()
	b := &SharedBackend{changes: make(chan struct{}, 1)}
	b.config.Activity = func(context.Context, consent.Admission, time.Time) []rows.ActivityInput {
		return []rows.ActivityInput{{ToolID: "codex", SubscriptionRef: "aaaaaaaaaaaaaaaa", SessionRef: "bbbbbbbbbbbbbbbb", BindingVerified: true, Phase: rows.ActivityPhase(<-phase), RecordAt: at, ExpiresAt: at.Add(5 * time.Minute)}}
	}
	b.observeActivity(ctx, at)
	select {
	case <-b.changes:
	default:
		t.Fatal("transition not notified")
	}
	b.observeActivity(ctx, at)
	select {
	case <-b.changes:
		t.Fatal("unchanged verdict notified")
	default:
	}
	b.observeActivity(ctx, at.Add(5*time.Minute))
	select {
	case <-b.changes:
	default:
		t.Fatal("expiry not notified")
	}
}

func TestActivityContextChangeDoesNotPublishOldBinding(t *testing.T) {
	b := &SharedBackend{activityStamp: Stamp{Epoch: "old", Generation: 1}, activity: []rows.ActivityInput{{SessionRef: "aaaaaaaaaaaaaaaa"}}}
	if got := b.activityFor(Stamp{Epoch: "new", Generation: 1}); len(got) != 0 {
		t.Fatal("cross-epoch activity")
	}
	if got := b.activityFor(Stamp{Epoch: "old", Generation: 2}); len(got) != 0 {
		t.Fatal("revoked-generation activity")
	}
}

// Quota history rides on the rows report: at most one write a minute, none while one is running.
func TestReportedAtMostOnceAMinute(t *testing.T) {
	calls := make(chan time.Time, 4)
	b := &SharedBackend{config: SharedConfig{Reported: func(_ quota.Report, now time.Time) { calls <- now }}}
	start := time.Unix(1_800_000_000, 0)
	b.reported(quota.Report{}, start)
	<-calls
	for b.reportBusy.Load() {
		time.Sleep(time.Millisecond)
	}
	b.reported(quota.Report{}, start.Add(59*time.Second))
	b.reported(quota.Report{}, start.Add(61*time.Second))
	if got := <-calls; !got.Equal(start.Add(61 * time.Second)) {
		t.Fatalf("second report at %s", got)
	}
	if len(calls) != 0 {
		t.Fatal("reported twice")
	}
}
