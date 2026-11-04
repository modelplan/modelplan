// SPDX-License-Identifier: MIT
package localusage

import (
	"context"
	"errors"
	"path/filepath"
	"testing"
	"time"
)

func TestProjectionReducerAbortBacksOffAndRetainsLastGood(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "projects/project/session.jsonl")
	first := projectionLine(1, testNow.Add(-time.Hour))
	fixtureFile(t, path, first)
	good := RefreshProjection(context.Background(), "claude", root, cache, a, testNow, projectionTestReducer)
	if !good.Complete || projectionN(t, good) != 1 {
		t.Fatalf("initial projection: %+v", good)
	}
	fixtureFile(t, path, first+projectionLine(2, testNow.Add(-time.Minute)))
	fail := func(context.Context, ProjectionState, ProjectionBatch) (ProjectionState, error) {
		return ProjectionState{}, errors.New("synthetic reducer failure")
	}
	_, opens := projectionCountIO(t)
	at := good.NextAttemptAt
	for _, wait := range []time.Duration{10 * time.Second, 20 * time.Second, 40 * time.Second, time.Minute, time.Minute} {
		r := RefreshProjection(context.Background(), "claude", root, cache, a, at, fail)
		if r.Availability != "partial" || r.Complete || !r.CapturedAt.Equal(good.CapturedAt) || projectionN(t, r) != 1 {
			t.Fatalf("failed projection lost prior facts: %+v", r)
		}
		if want := at.Add(wait); !r.NextAttemptAt.Equal(want) {
			t.Fatalf("reducer abort next attempt = %s, want %s", r.NextAttemptAt, want)
		}
		// A restarted process must still honor the persisted deadline.
		historyAttempts.Delete(cache + "/" + projectionTool)
		before := *opens
		RefreshProjection(context.Background(), "claude", root, cache, a, at.Add(wait-time.Second), fail)
		if *opens != before {
			t.Fatal("source reopened during backoff")
		}
		at = at.Add(wait)
	}
	recovered := RefreshProjection(context.Background(), "claude", root, cache, a, at, projectionTestReducer)
	if !recovered.Complete || projectionN(t, recovered) != 3 || !recovered.NextAttemptAt.Equal(at.Add(ProjectionInterval)) {
		t.Fatalf("recovery: %+v", recovered)
	}
}

func TestProjectionInvalidReducerOutputBacksOff(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	fixtureFile(t, filepath.Join(root, "projects/project/session.jsonl"), projectionLine(1, testNow.Add(-time.Minute)))
	invalid := func(_ context.Context, s ProjectionState, b ProjectionBatch) (ProjectionState, error) {
		if b.Final {
			s.Decoder = []byte("not-json")
		}
		return s, nil
	}
	r := RefreshProjection(context.Background(), "claude", root, cache, a, testNow, invalid)
	if r.Availability != "partial" || !r.NextAttemptAt.Equal(testNow.Add(10*time.Second)) {
		t.Fatalf("invalid output did not back off: %+v", r)
	}
}
