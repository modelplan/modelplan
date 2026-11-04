// SPDX-License-Identifier: MIT
package localusage

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestProjectionReducerAbortUsesFailureBackoff(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "projects/project/session.jsonl")
	one := projectionLine(1, testNow.Add(-time.Hour))
	fixtureFile(t, path, one)
	baseline := RefreshProjection(context.Background(), "claude", root, cache, a, testNow, projectionTestReducer)
	if projectionN(t, baseline) != 1 {
		t.Fatal("missing baseline")
	}
	before, err := os.ReadFile(historyPath(cache, projectionTool, a))
	if err != nil {
		t.Fatal(err)
	}
	fixtureFile(t, path, one+projectionLine(2, testNow.Add(-time.Minute)))
	calls := 0
	fail := func(_ context.Context, s ProjectionState, _ ProjectionBatch) (ProjectionState, error) {
		calls++
		return s, errors.New("synthetic reducer failure")
	}
	at := testNow.Add(ProjectionInterval)
	got := RefreshProjection(context.Background(), "claude", root, cache, a, at, fail)
	after, err := os.ReadFile(historyPath(cache, projectionTool, a))
	if err != nil {
		t.Fatal(err)
	}
	if string(before) != string(after) || got.Complete || got.Availability != "partial" || projectionN(t, got) != 1 {
		t.Fatal("abort changed last-good snapshot", got)
	}
	if want := at.Add(10 * time.Second); !got.NextAttemptAt.Equal(want) {
		t.Fatalf("failure retry at %v; want %v", got.NextAttemptAt, want)
	}
	beforeCalls := calls
	RefreshProjection(context.Background(), "claude", root, cache, a, at.Add(5*time.Second), fail)
	if calls != beforeCalls {
		t.Fatal("retried before failure backoff")
	}
	at = got.NextAttemptAt
	for _, delay := range []time.Duration{20 * time.Second, 40 * time.Second, time.Minute, time.Minute} {
		got = RefreshProjection(context.Background(), "claude", root, cache, a, at, fail)
		if want := at.Add(delay); !got.NextAttemptAt.Equal(want) {
			t.Fatalf("retry at %v; want %v", got.NextAttemptAt, want)
		}
		if projectionN(t, got) != 1 {
			t.Fatal("failure changed last good snapshot")
		}
		at = got.NextAttemptAt
	}
	got = RefreshProjection(context.Background(), "claude", root, cache, a, at, projectionTestReducer)
	if !got.Complete || projectionN(t, got) != 3 || !got.NextAttemptAt.Equal(at.Add(ProjectionInterval)) {
		t.Fatalf("recovery did not reset gate: %+v", got)
	}
	gatePath, _ := historyGatePaths(cache, projectionTool)
	var gate historyGate
	if !historyLoad(gatePath, &gate, 4096) || gate.Failures != 0 {
		t.Fatalf("failure counter not reset: %+v", gate)
	}
}

func TestProjectionAbortBackoffHonorsPublishFence(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	fixtureFile(t, filepath.Join(root, "projects/project/session.jsonl"), projectionLine(1, testNow.Add(-time.Hour)))
	RefreshProjection(context.Background(), "claude", root, cache, a, testNow, projectionTestReducer)
	calls := 0
	a.Publish = func(func() error) error { calls++; return errors.New("synthetic fence changed") }
	fail := func(_ context.Context, s ProjectionState, _ ProjectionBatch) (ProjectionState, error) {
		return s, errors.New("synthetic reducer failure")
	}
	at := testNow.Add(ProjectionInterval)
	RefreshProjection(context.Background(), "claude", root, cache, a, at, fail)
	gatePath, _ := historyGatePaths(cache, projectionTool)
	var gate historyGate
	if !historyLoad(gatePath, &gate, 4096) || calls != 1 || gate.Failures != 0 || !gate.Next.Equal(at.Add(ProjectionInterval)) {
		t.Fatalf("fenced retry update was published: calls=%d gate=%+v", calls, gate)
	}
}
