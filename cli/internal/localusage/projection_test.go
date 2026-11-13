package localusage

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// A deliberately generic reducer, unrelated to Claude semantics. It persists
// only numeric values, source timestamps and the engine's keyed file reference.
type projectionTestValue struct {
	N  int       `json:"n"`
	At time.Time `json:"at"`
}

func projectionTestReducer(_ context.Context, s ProjectionState, b ProjectionBatch) (ProjectionState, error) {
	values := map[string]projectionTestValue{}
	if len(s.Decoder) > 0 {
		if err := json.Unmarshal(s.Decoder, &values); err != nil {
			return s, err
		}
	}
	if b.Reset != "" {
		delete(values, b.FileRef)
	}
	for _, line := range b.Lines {
		var v projectionTestValue
		if err := json.Unmarshal(line, &v); err != nil {
			return s, err
		}
		v.N += values[b.FileRef].N
		values[b.FileRef] = v
	}
	if b.Final {
		s.Incomplete = !b.RecoveryComplete
		if b.DiscoveryComplete {
			live := map[string]bool{}
			for _, ref := range b.LiveFileRefs {
				live[ref] = true
			}
			for ref := range values {
				if !live[ref] {
					delete(values, ref)
				}
			}
		}
		v := projectionTestValue{}
		for _, entry := range values {
			v.N += entry.N
			if entry.At.After(v.At) {
				v.At = entry.At
			}
		}
		s.Snapshot, _ = json.Marshal(struct {
			N int `json:"n"`
		}{v.N})
		s.ObservedAt = v.At
	}
	s.Decoder, _ = json.Marshal(values)
	return s, nil
}
func projectionLine(n int, at time.Time) string {
	return fmt.Sprintf("{\"n\":%d,\"at\":%q,\"content\":\"private-message-canary\",\"uuid\":\"private-id-canary\"}\n", n, at.Format(time.RFC3339Nano))
}
func projectionN(t *testing.T, r ProjectionResult) int {
	t.Helper()
	var v struct{ N int }
	if err := json.Unmarshal(r.Snapshot, &v); err != nil {
		t.Fatal(err, r)
	}
	return v.N
}
func projectionCountIO(t *testing.T) (*int64, *int) {
	t.Helper()
	old := historyOpenSource
	t.Cleanup(func() { historyOpenSource = old })
	var count int64
	var opens int
	historyOpenSource = func(path string) (historySource, os.FileInfo, error) {
		opens++
		f, info, err := historyOpen(path)
		if err != nil {
			return nil, nil, err
		}
		return historyCountedSource{historySource: f, bytes: &count}, info, nil
	}
	return &count, &opens
}
func TestProjectionIncrementalCacheRestartPrivacy(t *testing.T) {
	a := historyTestAccess(t)
	t.Setenv("MODELPLAN_READERS", "passive")
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "projects/private-project-canary/private-session-canary.jsonl")
	line := projectionLine(1, testNow.Add(-time.Hour))
	fixtureFile(t, path, line)
	ioBytes, opens := projectionCountIO(t)
	r := RefreshProjection(context.Background(), "claude", root, cache, a, testNow, projectionTestReducer)
	if !r.Complete || !r.Beta || r.Availability != "ok" || projectionN(t, r) != 1 || r.BytesRead != int64(len(line)) || *ioBytes != r.BytesRead+r.ValidationBytes || !r.CapturedAt.Equal(testNow) {
		t.Fatal(r, *ioBytes)
	}
	persisted, _ := os.ReadFile(historyPath(cache, projectionTool, a))
	out, _ := json.Marshal(r)
	for _, secret := range []string{root, "private-project-canary", "private-session-canary", "private-message-canary", "private-id-canary"} {
		if bytes.Contains(append(persisted, out...), []byte(secret)) {
			t.Fatal("privacy leak", secret)
		}
	}
	*ioBytes, *opens = 0, 0
	cached := ReadProjectionCache(cache, "claude", a, testNow.Add(time.Hour))
	if *ioBytes != 0 || *opens != 0 || cached.Freshness != "stale" || !cached.CapturedAt.Equal(testNow) {
		t.Fatal(cached)
	}
	// Persisted scheduling and cursors survive an in-process restart simulation.
	historyAttempts.Delete(cache + "/" + projectionTool)
	r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(ProjectionInterval), projectionTestReducer)
	if *ioBytes != 0 || r.BytesRead != 0 || r.ValidationBytes != 0 || projectionN(t, r) != 1 || !r.CapturedAt.Equal(testNow) {
		t.Fatal("unchanged content read/freshened", r, *ioBytes)
	}
	two := projectionLine(2, testNow.Add(-time.Minute))
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		t.Fatal(err)
	}
	_, err = f.WriteString(two)
	f.Close()
	if err != nil {
		t.Fatal(err)
	}
	*ioBytes = 0
	r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(2*ProjectionInterval), projectionTestReducer)
	if projectionN(t, r) != 3 || r.BytesRead != int64(len(two)) || *ioBytes != r.BytesRead+r.ValidationBytes || !r.ObservedAt.Equal(testNow.Add(-time.Minute)) {
		t.Fatal(r, *ioBytes)
	}
	// Neither profile nor installation keys share derived data.
	other := a
	other.ProfileRef = strings.Repeat("b", 64)
	if len(ReadProjectionCache(cache, "claude", other, testNow).Snapshot) != 0 {
		t.Fatal("profile crossed")
	}
	other = a
	other.Key = bytes.Repeat([]byte{9}, 32)
	if len(ReadProjectionCache(cache, "claude", other, testNow).Snapshot) != 0 {
		t.Fatal("key crossed")
	}
	batchJSON, _ := json.Marshal(ProjectionBatch{SessionID: "secret", Lines: [][]byte{[]byte("secret")}})
	if string(batchJSON) != "{}" {
		t.Fatal("batch can be serialized", string(batchJSON))
	}
}
func TestProjectionIncompleteTailRecoveryAndResetEvents(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "projects/project/session.jsonl")
	line := projectionLine(1, testNow.Add(-time.Hour))
	fixtureFile(t, path, line)
	var resets []string
	var finals []ProjectionBatch
	reduce := func(ctx context.Context, s ProjectionState, b ProjectionBatch) (ProjectionState, error) {
		if b.Reset != "" {
			resets = append(resets, b.Reset)
		}
		if b.Final {
			finals = append(finals, b)
		}
		return projectionTestReducer(ctx, s, b)
	}
	r := RefreshProjection(context.Background(), "claude", root, cache, a, testNow, reduce)
	originalCapture := r.CapturedAt
	two := projectionLine(2, testNow.Add(-time.Minute))
	fixtureFile(t, path, line+strings.TrimSuffix(two, "\n"))
	r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(5*time.Second), reduce)
	if r.Complete || r.Availability != "partial" || projectionN(t, r) != 1 || !r.CapturedAt.Equal(originalCapture) || finals[len(finals)-1].RecoveryComplete {
		t.Fatal(r)
	}
	fixtureFile(t, path, line+two)
	r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(15*time.Second), reduce)
	if !r.Complete || projectionN(t, r) != 3 || r.BytesRead != int64(len(two)) {
		t.Fatal(r)
	}
	fixtureFile(t, path, projectionLine(7, testNow.Add(-time.Second)))
	r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(20*time.Second), reduce)
	if projectionN(t, r) != 7 || resets[len(resets)-1] != "truncation" {
		t.Fatal(r, resets)
	}
	if err := os.Rename(path, path+".old"); err != nil {
		t.Fatal(err)
	}
	fixtureFile(t, path, line)
	r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(25*time.Second), reduce)
	if projectionN(t, r) != 1 || resets[len(resets)-1] != "replacement" {
		t.Fatal(r, resets)
	}
	fixtureFile(t, path, projectionLine(9, testNow.Add(-time.Hour)))
	if err := os.Chtimes(path, testNow.Add(time.Second), testNow.Add(time.Second)); err != nil {
		t.Fatal(err)
	}
	r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(30*time.Second), reduce)
	if projectionN(t, r) != 9 || resets[len(resets)-1] != "rewrite" {
		t.Fatal(r, resets)
	}
	if err := os.RemoveAll(root); err != nil {
		t.Fatal(err)
	}
	r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(35*time.Second), reduce)
	if r.Availability != "not_detected" || r.Complete || projectionN(t, r) != 9 || !r.CapturedAt.Equal(testNow.Add(30*time.Second)) || finals[len(finals)-1].DiscoveryComplete {
		t.Fatal(r)
	}
}
func TestProjectionReducerFailureAtomicityCancellationAndRevocation(t *testing.T) {
	for _, failure := range []string{"error", "invalid", "oversized", "cancel", "off", "incomplete"} {
		t.Run(failure, func(t *testing.T) {
			a := historyTestAccess(t)
			root, cache := t.TempDir(), t.TempDir()
			path := filepath.Join(root, "projects/project/session.jsonl")
			one := projectionLine(1, testNow.Add(-time.Hour))
			fixtureFile(t, path, one)
			RefreshProjection(context.Background(), "claude", root, cache, a, testNow, projectionTestReducer)
			before, _ := os.ReadFile(historyPath(cache, projectionTool, a))
			two := projectionLine(2, testNow.Add(-time.Minute))
			fixtureFile(t, path, one+two)
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			reduce := func(ctx context.Context, s ProjectionState, b ProjectionBatch) (ProjectionState, error) {
				s, err := projectionTestReducer(ctx, s, b)
				if b.Final {
					switch failure {
					case "error":
						return s, errors.New("private-error-canary")
					case "invalid":
						s.Decoder = json.RawMessage(`{`)
					case "oversized":
						s.Snapshot = json.RawMessage(`"` + strings.Repeat("x", 64<<10) + `"`)
					case "cancel":
						cancel()
					case "off":
						t.Setenv("MODELPLAN_READERS", "off")
					case "incomplete":
						s.Incomplete = true
					}
				}
				return s, err
			}
			r := RefreshProjection(ctx, "claude", root, cache, a, testNow.Add(5*time.Second), reduce)
			after, _ := os.ReadFile(historyPath(cache, projectionTool, a))
			if failure == "incomplete" {
				if r.Complete || r.Availability != "partial" || projectionN(t, r) != 1 || bytes.Equal(before, after) {
					t.Fatal(r)
				}
			} else if !bytes.Equal(before, after) {
				t.Fatal("snapshot/cursor partially committed", failure)
			}
			if bytes.Contains(after, []byte("private-error-canary")) {
				t.Fatal("error persisted")
			}
			t.Setenv("MODELPLAN_READERS", "passive")
			r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(time.Minute), projectionTestReducer)
			if projectionN(t, r) != 3 {
				t.Fatal("cursor advanced without decoder or recovery failed", r)
			}
		})
	}
}
func TestProjectionPathsConsentAndForgetReservation(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	good := "projects/project/session.jsonl"
	for _, rel := range []string{good, "history.jsonl", "debug/log.jsonl", "projects/project/subagents/agent.jsonl", "projects/project/deeper/session.jsonl", "projects/project/session.jsonl.old", "projects/.hidden/session.jsonl", "projects/subagents/session.jsonl", "memory/project/session.jsonl"} {
		fixtureFile(t, filepath.Join(root, rel), projectionLine(1, testNow.Add(-time.Hour)))
	}
	if err := os.Symlink(filepath.Join(root, good), filepath.Join(root, "projects/project/link.jsonl")); err != nil {
		t.Fatal(err)
	}
	_, opens := projectionCountIO(t)
	for _, tc := range []struct {
		mode, privacy, state string
		allowed, denied      bool
	}{
		{"off", "", "off", true, false}, {"passive", "", "denied", true, true}, {"passive", "", "consent_required", false, false}, {"invalid", "", "privacy_blocked", true, false}, {"passive", "invalid", "privacy_blocked", true, false},
	} {
		t.Setenv("MODELPLAN_READERS", tc.mode)
		denied := a
		denied.Privacy, denied.Allowed, denied.Denied = tc.privacy, tc.allowed, tc.denied
		r := RefreshProjection(context.Background(), "claude", root, cache, denied, testNow, projectionTestReducer)
		if r.Availability != tc.state || *opens != 0 {
			t.Fatal(r, *opens)
		}
	}
	t.Setenv("MODELPLAN_READERS", "passive")
	r := RefreshProjection(context.Background(), "claude", root, cache, a, testNow, projectionTestReducer)
	if *opens != 1 || projectionN(t, r) != 1 {
		t.Fatal("path boundary", r, *opens)
	}
	gatePath, _ := historyGatePaths(cache, projectionTool)
	before, _ := os.ReadFile(gatePath)
	revoked := a
	revoked.Allowed = false
	if err := ForgetProjectionProfile(cache, "claude", revoked); err != nil {
		t.Fatal(err)
	}
	after, _ := os.ReadFile(gatePath)
	if !bytes.Equal(before, after) {
		t.Fatal("forget removed reservation")
	}
	historyAttempts.Delete(cache + "/" + projectionTool)
	*opens = 0
	r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(time.Second), projectionTestReducer)
	if *opens != 0 || len(r.Snapshot) != 0 {
		t.Fatal("forget/restart bypassed floor", r)
	}
	// Projection does not reserve the five-minute quota/history schedule.
	if _, err := os.Stat(filepath.Join(cache, "observed", "history-claude-gate-v1.json")); !os.IsNotExist(err) {
		t.Fatal("network namespace reused")
	}
	r = RefreshProjection(context.Background(), "other", root, cache, a, testNow.Add(time.Hour), projectionTestReducer)
	if r.Availability != "not_supported_yet" || *opens != 0 {
		t.Fatal(r)
	}
}
func TestProjectionDiscoveryAndByteBounds(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	// An overlarge line is never delivered or checkpointed as consumed.
	fixtureFile(t, filepath.Join(root, "projects/project/session.jsonl"), strings.Repeat("x", (1<<20)+1)+"\n")
	lines := 0
	reduce := func(ctx context.Context, s ProjectionState, b ProjectionBatch) (ProjectionState, error) {
		lines += len(b.Lines)
		return projectionTestReducer(ctx, s, b)
	}
	r := RefreshProjection(context.Background(), "claude", root, cache, a, testNow, reduce)
	if lines != 0 || r.Complete || r.Availability != "not_supported_yet" || r.BytesRead > 8<<20 {
		t.Fatal(r, lines)
	}
	root, cache = t.TempDir(), t.TempDir()
	for i := 0; i < 257; i++ {
		fixtureFile(t, filepath.Join(root, fmt.Sprintf("projects/p-%03d/s.jsonl", i)), projectionLine(1, testNow.Add(-time.Hour)))
	}
	var final ProjectionBatch
	reduce = func(ctx context.Context, s ProjectionState, b ProjectionBatch) (ProjectionState, error) {
		if b.Final {
			final = b
		}
		return projectionTestReducer(ctx, s, b)
	}
	r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow, reduce)
	if r.Complete || r.Availability != "partial" || final.DiscoveryComplete || len(final.LiveFileRefs) > 256 {
		t.Fatal(r, len(final.LiveFileRefs))
	}
}

func TestProjectionTailBootstrapAndIncrementalContinuation(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	path := filepath.Join(root, "projects/project/session.jsonl")
	padding := fmt.Sprintf("{\"n\":0,\"at\":%q,\"content\":%q}\n", testNow.Add(-time.Hour).Format(time.RFC3339), strings.Repeat("s", 512<<10))
	body := strings.Repeat(padding, 9) + projectionLine(3, testNow.Add(-time.Minute))
	fixtureFile(t, path, body)
	count, _ := projectionCountIO(t)
	var omitted, finalOmitted bool
	reduce := func(ctx context.Context, s ProjectionState, b ProjectionBatch) (ProjectionState, error) {
		if len(b.Lines) > 0 {
			omitted = omitted || b.PrefixOmitted
			if b.Offset < int64(len(body))-projectionBootstrapBytes {
				t.Fatal("full bootstrap scan", b.Offset)
			}
		}
		if b.Final {
			finalOmitted = b.PrefixOmitted
		}
		return projectionTestReducer(ctx, s, b)
	}
	r := RefreshProjection(context.Background(), "claude", root, cache, a, testNow, reduce)
	if !r.Complete || projectionN(t, r) != 3 || !omitted || !finalOmitted || r.BytesRead != projectionBootstrapBytes || *count != r.BytesRead+r.ValidationBytes {
		t.Fatal(r, omitted, finalOmitted, *count)
	}
	historyAttempts.Delete(cache + "/" + projectionTool)
	*count = 0
	finalOmitted = false
	r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(5*time.Second), reduce)
	if *count != 0 || !finalOmitted || projectionN(t, r) != 3 {
		t.Fatal(r, *count, finalOmitted)
	}
	line := projectionLine(2, testNow.Add(-time.Second))
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		t.Fatal(err)
	}
	_, err = f.WriteString(line)
	f.Close()
	if err != nil {
		t.Fatal(err)
	}
	r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(10*time.Second), reduce)
	if projectionN(t, r) != 5 || r.BytesRead != int64(len(line)) {
		t.Fatal(r)
	}
	// A provider can fail closed when the bounded suffix cannot establish ancestry.
	reduceUncertain := func(ctx context.Context, s ProjectionState, b ProjectionBatch) (ProjectionState, error) {
		s, err := projectionTestReducer(ctx, s, b)
		if b.Final {
			s.Incomplete = b.PrefixOmitted
		}
		return s, err
	}
	r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(15*time.Second), reduceUncertain)
	if r.Complete || r.Availability != "partial" || projectionN(t, r) != 5 || !r.CapturedAt.Equal(testNow.Add(10*time.Second)) {
		t.Fatal(r)
	}
}

type projectionChangedSource struct{ historySource }
type projectionChangedInfo struct{ os.FileInfo }

func (i projectionChangedInfo) ModTime() time.Time { return i.FileInfo.ModTime().Add(time.Second) }
func (f projectionChangedSource) Stat() (os.FileInfo, error) {
	i, err := f.historySource.Stat()
	if err != nil {
		return nil, err
	}
	return projectionChangedInfo{i}, nil
}
func TestProjectionSourceFailuresRetainCapture(t *testing.T) {
	for _, failure := range []string{"open", "changed"} {
		t.Run(failure, func(t *testing.T) {
			a := historyTestAccess(t)
			root, cache := t.TempDir(), t.TempDir()
			path := filepath.Join(root, "projects/project/session.jsonl")
			one := projectionLine(1, testNow.Add(-time.Hour))
			fixtureFile(t, path, one)
			RefreshProjection(context.Background(), "claude", root, cache, a, testNow, projectionTestReducer)
			fixtureFile(t, path, one+projectionLine(2, testNow.Add(-time.Minute)))
			old := historyOpenSource
			t.Cleanup(func() { historyOpenSource = old })
			historyOpenSource = func(path string) (historySource, os.FileInfo, error) {
				if failure == "open" {
					return nil, nil, errors.New("private-path-error-canary")
				}
				f, info, err := historyOpen(path)
				if err != nil {
					return nil, nil, err
				}
				return projectionChangedSource{f}, info, nil
			}
			r := RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(5*time.Second), projectionTestReducer)
			if r.Complete || r.Availability != "partial" || projectionN(t, r) != 1 || !r.CapturedAt.Equal(testNow) {
				t.Fatal(r)
			}
			historyOpenSource = old
			r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(15*time.Second), projectionTestReducer)
			if !r.Complete || projectionN(t, r) != 3 {
				t.Fatal("recovery lost committed decoder", r)
			}
		})
	}
}

func TestProjectionRecordBudgetCommitsFrontierWithCursor(t *testing.T) {
	a := historyTestAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	line := projectionLine(1, testNow.Add(-time.Hour))
	fixtureFile(t, filepath.Join(root, "projects/project/session.jsonl"), strings.Repeat(line, projectionRecordLimit+1))
	count, _ := projectionCountIO(t)
	dataBatches := 0
	reduce := func(ctx context.Context, s ProjectionState, b ProjectionBatch) (ProjectionState, error) {
		if len(b.Lines) > 0 {
			dataBatches++
			batchBytes := 0
			for _, line := range b.Lines {
				batchBytes += len(line)
			}
			if len(b.Lines) > 256 || batchBytes > 1<<20 {
				t.Fatal("unbounded batch", len(b.Lines), batchBytes)
			}
		}
		return projectionTestReducer(ctx, s, b)
	}
	r := RefreshProjection(context.Background(), "claude", root, cache, a, testNow, reduce)
	if r.Complete || r.Availability != "partial" || len(r.Snapshot) != 0 || *count != r.BytesRead+r.ValidationBytes {
		t.Fatal(r, *count)
	}
	if dataBatches != projectionRecordLimit/256 {
		t.Fatal("records were not batched", dataBatches)
	}
	*count = 0
	r = RefreshProjection(context.Background(), "claude", root, cache, a, testNow.Add(10*time.Second), projectionTestReducer)
	if !r.Complete || projectionN(t, r) != projectionRecordLimit+1 || r.BytesRead != int64(len(line)) || *count != r.BytesRead+r.ValidationBytes {
		t.Fatal(r, *count)
	}
}
