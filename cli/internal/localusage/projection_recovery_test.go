package localusage

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// Inject source I/O failures without changing source metadata or checkpoint reads.
type projectionReadFailure struct {
	historySource
	remaining int
}

func (f *projectionReadFailure) Read(b []byte) (int, error) {
	if f.remaining == 0 {
		return 0, errors.New("synthetic transient read failure")
	}
	n, err := f.historySource.Read(b[:min(len(b), f.remaining)])
	f.remaining -= n
	return n, err
}

type projectionSeekFailure struct{ historySource }

func (f projectionSeekFailure) Seek(int64, int) (int64, error) {
	return 0, errors.New("synthetic transient seek failure")
}

func TestProjectionReadFailureRecoversUnchangedAfterRestart(t *testing.T) {
	for _, afterLine := range []bool{false, true} {
		name := "before-first-line"
		if afterLine {
			name = "after-complete-line-and-fragment"
		}
		t.Run(name, func(t *testing.T) {
			a := historyTestAccess(t)
			root, cache := t.TempDir(), t.TempDir()
			path := filepath.Join(root, "projects/project/session.jsonl")
			one := projectionLine(1, testNow.Add(-time.Hour))
			two := projectionLine(2, testNow.Add(-time.Minute))
			three := projectionLine(3, testNow.Add(-time.Second))
			body := one + two + three
			fixtureFile(t, path, body)
			info, err := os.Stat(path)
			if err != nil {
				t.Fatal(err)
			}
			identity, generation := historyMetadata(info, a.Key)
			old := historyOpenSource
			t.Cleanup(func() { historyOpenSource = old })
			historyOpenSource = func(path string) (historySource, os.FileInfo, error) {
				f, info, err := historyOpen(path)
				if err != nil {
					return nil, nil, err
				}
				remaining := 0
				if afterLine {
					remaining = len(one) + len(two)/2
				}
				return &projectionReadFailure{historySource: f, remaining: remaining}, info, nil
			}
			delivered := 0
			reduce := func(ctx context.Context, s ProjectionState, b ProjectionBatch) (ProjectionState, error) {
				delivered += len(b.Lines)
				return projectionTestReducer(ctx, s, b)
			}
			r := RefreshProjection(context.Background(), "claude", root, cache, a, testNow, reduce)
			if r.Availability != "partial" || r.Complete || len(r.Snapshot) != 0 {
				t.Fatal(r)
			}
			s := historyReadState(cache, projectionTool, a)
			expectedOffset, expectedN := int64(0), 0
			if afterLine {
				expectedOffset, expectedN = int64(len(one)), 1
			}
			if len(s.Files) != 1 || s.Projection == nil {
				t.Fatal("partial cursor/frontier missing")
			}
			for _, cursor := range s.Files {
				if cursor.Offset != expectedOffset || !cursor.Retry {
					t.Fatal("transient error lost retry eligibility", cursor)
				}
			}
			var values map[string]projectionTestValue
			if err := json.Unmarshal(s.Projection.Decoder, &values); err != nil {
				t.Fatal(err)
			}
			total := 0
			for _, value := range values {
				total += value.N
			}
			if total != expectedN {
				t.Fatal("decoder and committed cursor disagree", total, expectedN)
			}

			opens := 0
			historyOpenSource = func(path string) (historySource, os.FileInfo, error) {
				opens++
				return historyOpen(path)
			}
			historyAttempts.Delete(cache + "/" + projectionTool)
			// A restart and restored readability must not bypass failure backoff.
			RefreshProjection(context.Background(), "claude", root, cache, a, r.NextAttemptAt.Add(-time.Second), reduce)
			if opens != 0 {
				t.Fatal("backoff bypassed")
			}
			r = RefreshProjection(context.Background(), "claude", root, cache, a, r.NextAttemptAt, reduce)
			if !r.Complete || r.Availability != "ok" || projectionN(t, r) != 6 || delivered != 3 || r.BytesRead != int64(len(body))-expectedOffset {
				t.Fatal("unchanged source did not recover exactly once", r, delivered)
			}
			s = historyReadState(cache, projectionTool, a)
			for _, cursor := range s.Files {
				if cursor.Offset != int64(len(body)) || cursor.Catchup || cursor.Retry {
					t.Fatal("recovery cursor inconsistent", cursor)
				}
			}
			capture := r.CapturedAt
			r = RefreshProjection(context.Background(), "claude", root, cache, a, r.NextAttemptAt, reduce)
			if r.BytesRead != 0 || delivered != 3 || projectionN(t, r) != 6 || !r.CapturedAt.Equal(capture) {
				t.Fatal("recovered lines replayed", r, delivered)
			}
			info, err = os.Stat(path)
			if err != nil {
				t.Fatal(err)
			}
			afterIdentity, afterGeneration := historyMetadata(info, a.Key)
			if identity != afterIdentity || generation != afterGeneration {
				t.Fatal("test source changed")
			}
		})
	}
}

func TestProjectionSeekFailureRetainsAgeAndRetries(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "projects/project/session.jsonl")
	one := projectionLine(1, testNow.Add(-time.Hour))
	two := projectionLine(2, testNow.Add(-time.Minute))
	fixtureFile(t, path, one)
	good := RefreshProjection(context.Background(), "claude", root, cache, a, testNow, projectionTestReducer)
	fixtureFile(t, path, one+two)
	old := historyOpenSource
	t.Cleanup(func() { historyOpenSource = old })
	historyOpenSource = func(path string) (historySource, os.FileInfo, error) {
		f, info, err := historyOpen(path)
		if err != nil {
			return nil, nil, err
		}
		return projectionSeekFailure{f}, info, nil
	}
	r := RefreshProjection(context.Background(), "claude", root, cache, a, good.NextAttemptAt, projectionTestReducer)
	if r.Complete || r.Availability != "partial" || projectionN(t, r) != 1 || !r.CapturedAt.Equal(good.CapturedAt) || !r.ObservedAt.Equal(good.ObservedAt) || r.BytesRead != 0 {
		t.Fatal("seek failure changed observation", r)
	}
	s := historyReadState(cache, projectionTool, a)
	for _, cursor := range s.Files {
		if cursor.Offset != int64(len(one)) || !cursor.Retry {
			t.Fatal("seek failure advanced cursor", cursor)
		}
	}
	historyOpenSource = old
	historyAttempts.Delete(cache + "/" + projectionTool)
	r = RefreshProjection(context.Background(), "claude", root, cache, a, r.NextAttemptAt, projectionTestReducer)
	if !r.Complete || projectionN(t, r) != 3 || r.BytesRead != int64(len(two)) {
		t.Fatal("seek retry replayed committed data", r)
	}
}

func TestProjectionConclusiveEmptyClearsButInaccessibleRootRetains(t *testing.T) {
	for _, failure := range []string{"empty", "missing", "unreadable"} {
		t.Run(failure, func(t *testing.T) {
			a := historyTestAccess(t)
			root, cache := t.TempDir(), t.TempDir()
			path := filepath.Join(root, "projects/project/session.jsonl")
			fixtureFile(t, path, projectionLine(1, testNow.Add(-time.Hour)))
			var final ProjectionBatch
			reduce := func(ctx context.Context, s ProjectionState, b ProjectionBatch) (ProjectionState, error) {
				s, err := projectionTestReducer(ctx, s, b)
				if b.Final {
					final = b
					// A conclusive empty manifest explicitly clears the selection.
					if b.DiscoveryComplete && len(b.LiveFileRefs) == 0 {
						s.Snapshot, s.ObservedAt = nil, time.Time{}
					}
				}
				return s, err
			}
			good := RefreshProjection(context.Background(), "claude", root, cache, a, testNow, reduce)
			if projectionN(t, good) != 1 {
				t.Fatal(good)
			}
			prior := historyReadState(cache, projectionTool, a)
			switch failure {
			case "empty":
				if err := os.Remove(path); err != nil {
					t.Fatal(err)
				}
			case "missing":
				if err := os.RemoveAll(root); err != nil {
					t.Fatal(err)
				}
			case "unreadable":
				if err := os.Chmod(root, 0); err != nil {
					t.Fatal(err)
				}
				t.Cleanup(func() { _ = os.Chmod(root, 0700) })
				if f, err := os.Open(root); err == nil {
					f.Close()
					t.Skip("directory permissions are not enforced for this user")
				}
			}
			r := RefreshProjection(context.Background(), "claude", root, cache, a, good.NextAttemptAt, reduce)
			s := historyReadState(cache, projectionTool, a)
			if failure == "empty" {
				if !final.DiscoveryComplete || !final.RecoveryComplete || len(final.LiveFileRefs) != 0 || !r.Complete || r.Availability != "not_detected" || len(r.Snapshot) != 0 || !r.ObservedAt.IsZero() {
					t.Fatal("conclusive empty discovery retained selection", r, final)
				}
				if len(s.Files) != 0 || s.Projection == nil || len(s.Projection.Snapshot) != 0 || string(s.Projection.Decoder) != "{}" {
					t.Fatal("clear did not commit frontier and cursor together", s)
				}
				cached := ReadProjectionCache(cache, "claude", a, r.NextAttemptAt)
				if len(cached.Snapshot) != 0 || !cached.Complete {
					t.Fatal("cache resurrected cleared selection", cached)
				}
			} else {
				if final.DiscoveryComplete || final.RecoveryComplete || r.Complete || !bytes.Equal(r.Snapshot, good.Snapshot) || !r.CapturedAt.Equal(good.CapturedAt) || !r.ObservedAt.Equal(good.ObservedAt) {
					t.Fatal("inaccessible root erased or freshened last good", r, final)
				}
				if len(s.Files) != len(prior.Files) || !bytes.Equal(s.Projection.Decoder, prior.Projection.Decoder) {
					t.Fatal("inaccessible root pruned cursor/frontier")
				}
			}
		})
	}
}

func TestProjectionIncompleteEOFWaitsForSourceChange(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "projects/project/session.jsonl")
	one := projectionLine(1, testNow.Add(-time.Hour))
	two := projectionLine(2, testNow.Add(-time.Minute))
	fixtureFile(t, path, one+two[:len(two)-1])
	count, _ := projectionCountIO(t)
	r := RefreshProjection(context.Background(), "claude", root, cache, a, testNow, projectionTestReducer)
	if r.Complete || r.Availability != "partial" {
		t.Fatal(r)
	}
	s := historyReadState(cache, projectionTool, a)
	for _, cursor := range s.Files {
		if cursor.Retry || cursor.Catchup || cursor.Offset != int64(len(one)) {
			t.Fatal("incomplete EOF scheduled content retry", cursor)
		}
	}
	historyAttempts.Delete(cache + "/" + projectionTool)
	*count = 0
	r = RefreshProjection(context.Background(), "claude", root, cache, a, r.NextAttemptAt, projectionTestReducer)
	if *count != 0 || r.BytesRead != 0 || r.Availability != "partial" {
		t.Fatal("unchanged trailing fragment reread", r, *count)
	}
	fixtureFile(t, path, one+two)
	r = RefreshProjection(context.Background(), "claude", root, cache, a, r.NextAttemptAt, projectionTestReducer)
	if !r.Complete || projectionN(t, r) != 3 || r.BytesRead != int64(len(two)) {
		t.Fatal("completed tail did not recover", r)
	}
}

func TestHistorySnapshotTransientReadRetriesUnchanged(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	body := `{"messages":[{"role":"assistant","messageId":1,"usage":{"model":"amp-test","timestamp":"2026-10-23T10:00:00Z","inputTokens":10}}]}`
	fixtureFile(t, filepath.Join(root, "T-synthetic.json"), body)
	old := historyOpenSource
	t.Cleanup(func() { historyOpenSource = old })
	historyOpenSource = func(path string) (historySource, os.FileInfo, error) {
		f, info, err := historyOpen(path)
		if err != nil {
			return nil, nil, err
		}
		return &projectionReadFailure{historySource: f}, info, nil
	}
	r := RefreshHistory(context.Background(), "amp", root, cache, a, testNow)
	if r.Availability != "partial" || len(r.Rows) != 0 {
		t.Fatal(r)
	}
	historyOpenSource = old
	historyAttempts.Delete(cache + "/amp")
	r = RefreshHistory(context.Background(), "amp", root, cache, a, r.NextAttemptAt)
	if r.Availability != "ok" || len(r.Rows) != 1 || r.Rows[0].Input == nil || *r.Rows[0].Input != 10 {
		t.Fatal("snapshot read remained stuck", r)
	}
	r = RefreshHistory(context.Background(), "amp", root, cache, a, r.NextAttemptAt)
	if r.BytesRead != 0 || *r.Rows[0].Input != 10 {
		t.Fatal("snapshot recovery reread unchanged source", r)
	}
}
