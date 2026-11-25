// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

type recordingWriter struct {
	mu       sync.Mutex
	messages []string
	done     chan struct{}
}

func (w *recordingWriter) Write(p []byte) (int, error) {
	w.mu.Lock()
	w.messages = append(w.messages, string(p))
	count := len(w.messages)
	w.mu.Unlock()
	if count == 3 {
		close(w.done)
	}
	return len(p), nil
}
func (w *recordingWriter) Close() error { return nil }

func TestOutboundControlBeforeDataAndRowsCoalesce(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	w := &recordingWriter{done: make(chan struct{})}
	o := newOutbound(ctx, cancel, w, time.Second, func(Stamp) error { return nil })
	if !o.reserve() {
		t.Fatal("first slot unavailable")
	}
	o.dataMessage("query", Stamp{}, false, nil)
	o.rowsMessage("old row", Stamp{}, nil)
	o.rowsMessage("latest row", Stamp{}, nil)
	o.controlMessage("revoke receipt")
	done := make(chan struct{})
	go o.run(done)
	select {
	case <-w.done:
	case <-time.After(time.Second):
		t.Fatal("writer did not drain")
	}
	cancel()
	<-done
	w.mu.Lock()
	defer w.mu.Unlock()
	if len(w.messages) != 3 || w.messages[0] != "\"revoke receipt\"\n" || w.messages[1] != "\"query\"\n" || w.messages[2] != "\"latest row\"\n" {
		t.Fatal("wrong priority or rows did not coalesce", w.messages)
	}
}

func TestOutboundDataReservationAndControlCaps(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	o := newOutbound(ctx, cancel, &recordingWriter{}, time.Second, func(Stamp) error { return nil })
	for i := 0; i < wire.MaxDataMessages-1; i++ {
		if !o.reserve() {
			t.Fatalf("result slot %d missing", i)
		}
	}
	if o.reserve() {
		t.Fatal("data reservation overflow admitted")
	}
	for i := 0; i < wire.MaxDataMessages-1; i++ {
		if !o.dataMessage(i, Stamp{}, false, nil) {
			t.Fatal("reserved result lost")
		}
	}
	if o.reserve() {
		t.Fatal("full data queue admitted another result")
	}
	for i := 0; i < wire.MaxControlMessages; i++ {
		if !o.controlMessage(i) {
			t.Fatal("control slot lost")
		}
	}
	if o.controlMessage("overflow") {
		t.Fatal("control cap ignored")
	}
	select {
	case <-ctx.Done():
	case <-time.After(time.Second):
		t.Fatal("control overflow did not end session")
	}
}

func TestStaleQueryTurnsIntoErrorAndStaleRowsDrop(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	r, w := io.Pipe()
	o := newOutbound(ctx, cancel, w, time.Second, func(Stamp) error { return ProtocolError{wire.CodeConsentChanged} })
	o.reserve()
	o.dataMessage("private stale query", Stamp{}, true, func(_ error) {
		o.controlMessage(wire.Failure{JSONRPC: wire.JSONRPC, ID: json.RawMessage(`7`), Error: wire.RPCError{Code: wire.CodeConsentChanged, Message: "consent_changed"}})
	})
	o.rowsMessage("private stale row", Stamp{}, nil)
	done := make(chan struct{})
	go o.run(done)
	var response wire.Failure
	if err := json.NewDecoder(r).Decode(&response); err != nil {
		t.Fatal(err)
	}
	if response.Error.Code != wire.CodeConsentChanged {
		t.Fatal("stale query lost its terminal response")
	}
	cancel()
	_ = w.Close()
	_ = r.Close()
	<-done
}

func TestRowsSlotIsIncludedInDataCap(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	o := newOutbound(ctx, cancel, &recordingWriter{}, time.Second, func(Stamp) error { return nil })
	for o.reserve() {
		o.dataMessage("result", Stamp{}, false, nil)
	}
	o.rowsMessage("latest", Stamp{}, nil)
	o.mu.Lock()
	count := len(o.data) + o.reserved
	if o.latest != nil {
		count++
	}
	o.mu.Unlock()
	if count > wire.MaxDataMessages {
		t.Fatalf("queued %d data messages, cap %d", count, wire.MaxDataMessages)
	}
}

func TestBusyAtFinalFenceReturnsBusyWithoutPrivateData(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	r, w := io.Pipe()
	o := newOutbound(ctx, cancel, w, time.Second, func(Stamp) error { return ProtocolError{wire.CodeBusy} })
	o.reserve()
	o.dataMessage("private value", Stamp{}, true, func(err error) {
		code := errorCode(err)
		o.controlMessage(wire.Failure{JSONRPC: wire.JSONRPC, ID: json.RawMessage(`7`), Error: wire.RPCError{Code: code, Message: wire.ErrorName(code)}})
	})
	done := make(chan struct{})
	go o.run(done)
	var response wire.Failure
	if err := json.NewDecoder(r).Decode(&response); err != nil {
		t.Fatal(err)
	}
	if response.Error.Code != wire.CodeBusy {
		t.Fatalf("got %d, want busy", response.Error.Code)
	}
	cancel()
	_ = w.Close()
	_ = r.Close()
	<-done
}

// fenceWriter records what the consumer received and whether each byte arrived while the
// consent fence was held (sampling 11-25, #1217 P2).
type fenceWriter struct {
	mu      sync.Mutex
	written []byte
	outside int // bytes of private frames written while the fence was not held
	inside  bool
	closed  bool
	fail    bool // fail the next write after accepting part of it
}

func (w *fenceWriter) Write(p []byte) (int, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.closed {
		return 0, io.ErrClosedPipe
	}
	if w.fail {
		w.written = append(w.written, p[:1]...)
		return 1, io.ErrClosedPipe
	}
	if !w.inside && strings.Contains(string(p), "private") {
		w.outside += len(p)
	}
	w.written = append(w.written, p...)
	return len(p), nil
}
func (w *fenceWriter) Close() error     { w.mu.Lock(); w.closed = true; w.mu.Unlock(); return nil }
func (w *fenceWriter) setInside(v bool) { w.mu.Lock(); w.inside = v; w.mu.Unlock() }
func (w *fenceWriter) snapshot() (string, int, bool) {
	w.mu.Lock()
	defer w.mu.Unlock()
	return string(w.written), w.outside, w.closed
}

// waitFor polls until the consumer has received want or the deadline passes.
func (w *fenceWriter) waitFor(t *testing.T, want string) string {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	for {
		got, _, _ := w.snapshot()
		if strings.Contains(got, want) || time.Now().After(deadline) {
			return got
		}
		time.Sleep(5 * time.Millisecond)
	}
}

// Invariant: a fenced frame is written completely under the fence it was admitted with, or
// not at all. The fence flips after the admission check (o.current) and before the commit:
// the frame is dropped through stale before its first byte and the session continues, so
// the host sees no partial frame and records no restart.
func TestPrivateFrameFenceFlipAfterAdmissionWritesNothingAndKeepsSession(t *testing.T) {
	for _, kind := range []string{"rows", "data"} {
		t.Run(kind, func(t *testing.T) {
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			w := &fenceWriter{}
			admitted := 0
			o := newOutbound(ctx, cancel, w, time.Second, func(Stamp) error { admitted++; return nil })
			o.commit = func(Stamp, func() error) error {
				// Another process (or the user's own Settings grant) committed after admission.
				return ProtocolError{wire.CodeConsentChanged}
			}
			var staleErr error
			stale := func(err error) { staleErr = err; o.controlMessage("stale reply") }
			if kind == "rows" {
				o.rowsMessage("private row", Stamp{}, stale)
			} else {
				o.reserve()
				o.dataMessage("private result", Stamp{}, true, stale)
			}
			done := make(chan struct{})
			go o.run(done)
			got := w.waitFor(t, "\"stale reply\"\n")
			o.controlMessage("after")
			got = w.waitFor(t, "\"after\"\n")
			if strings.Contains(got, "private") {
				t.Fatalf("a private frame reached the consumer after its fence moved: %q", got)
			}
			if got != "\"stale reply\"\n\"after\"\n" {
				t.Fatalf("consumer received %q, want only the stale reply and the next frame", got)
			}
			if errorCode(staleErr) != wire.CodeConsentChanged || admitted != 1 {
				t.Fatalf("stale = %v, admitted = %d", staleErr, admitted)
			}
			if _, _, closed := w.snapshot(); closed || ctx.Err() != nil {
				t.Fatal("a consent change ended the session")
			}
			cancel()
			<-done
		})
	}
}

// Invariant: every byte of a private frame, the body as well as its newline, is written while
// the fence is held.
func TestPrivateFrameIsWrittenWholeUnderFence(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	w := &fenceWriter{}
	o := newOutbound(ctx, cancel, w, time.Second, func(Stamp) error { return nil })
	commits := 0
	o.commit = func(_ Stamp, write func() error) error {
		commits++
		w.setInside(true)
		defer w.setInside(false)
		return write()
	}
	o.rowsMessage("private row", Stamp{}, nil)
	o.controlMessage("after")
	done := make(chan struct{})
	go o.run(done)
	got := w.waitFor(t, "\"private row\"\n")
	cancel()
	<-done
	_, outside, closed := w.snapshot()
	if got != "\"after\"\n\"private row\"\n" || outside != 0 || commits != 1 || closed {
		t.Fatalf("written %q, %d private bytes outside the fence, %d commits, closed %v", got, outside, commits, closed)
	}
}

// Stop-on-failure is kept: a private frame whose write fails after its first byte ends the
// session and closes the pipe, so the incomplete line is discarded and never completed.
func TestPrivateFrameWriteFailureUnderFenceEndsSession(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	w := &fenceWriter{fail: true}
	o := newOutbound(ctx, cancel, w, time.Second, func(Stamp) error { return nil })
	staled := false
	o.commit = func(_ Stamp, write func() error) error { return write() }
	o.rowsMessage("private row", Stamp{}, func(error) { staled = true })
	done := make(chan struct{})
	go o.run(done)
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("session did not end after a failed private write")
	}
	got, _, closed := w.snapshot()
	if strings.Contains(got, "\n") || !closed || ctx.Err() == nil || staled {
		t.Fatalf("written %q, closed %v, stale %v", got, closed, staled)
	}
}

// blockingWriter never accepts a byte until it is closed.
type blockingWriter struct{ closed chan struct{} }

func (w *blockingWriter) Write([]byte) (int, error) { <-w.closed; return 0, io.ErrClosedPipe }
func (w *blockingWriter) Close() error {
	select {
	case <-w.closed:
	default:
		close(w.closed)
	}
	return nil
}

// A stalled consumer never holds the consent lock past commitTimeout, so a consent change is
// never stuck behind a frame write (#1262 macrevb-1262-1); the session itself still ends only
// at the normal write timeout.
func TestPrivateFrameStallReleasesFenceAndEndsAtWriteTimeout(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	w := &blockingWriter{closed: make(chan struct{})}
	const writeTimeout = 1500 * time.Millisecond
	o := newOutbound(ctx, cancel, w, writeTimeout, func(Stamp) error { return nil })
	var mu sync.Mutex
	var holds []time.Duration
	o.commit = func(_ Stamp, write func() error) error {
		start := time.Now()
		err := write()
		mu.Lock()
		holds = append(holds, time.Since(start))
		mu.Unlock()
		return err
	}
	o.rowsMessage("private row", Stamp{}, nil)
	started := time.Now()
	done := make(chan struct{})
	go o.run(done)
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("a stalled consumer kept the session past the write timeout")
	}
	elapsed := time.Since(started)
	mu.Lock()
	defer mu.Unlock()
	if len(holds) != 1 || holds[0] < commitTimeout || holds[0] > commitTimeout+300*time.Millisecond {
		t.Fatalf("consent lock holds %v, want one of about %v", holds, commitTimeout)
	}
	if elapsed < writeTimeout || elapsed > writeTimeout+time.Second || ctx.Err() == nil {
		t.Fatalf("session ended after %v, want about the write timeout %v", elapsed, writeTimeout)
	}
}

// gateWriter blocks its first write until the consumer resumes (release is closed).
type gateWriter struct {
	release chan struct{}
	closed  chan struct{}
	mu      sync.Mutex
	written []byte
	once    sync.Once
}

func (w *gateWriter) Write(p []byte) (int, error) {
	select {
	case <-w.release:
	case <-w.closed:
		return 0, io.ErrClosedPipe
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	w.written = append(w.written, p...)
	return len(p), nil
}
func (w *gateWriter) Close() error { w.once.Do(func() { close(w.closed) }); return nil }
func (w *gateWriter) snapshot() string {
	w.mu.Lock()
	defer w.mu.Unlock()
	return string(w.written)
}

// A consumer stalls mid-frame past commitTimeout; the lock is released and the body finishes
// outside it. A revoke committed meanwhile means the frame's newline is never written: the
// session ends and the partial line is discarded (review 11-24 #1). Without a revoke the frame
// completes under a second commit and the session continues.
func TestPrivateFrameStalledPastBoundTerminatesOnlyUnderFence(t *testing.T) {
	for _, revoke := range []bool{true, false} {
		t.Run(fmt.Sprintf("revoke=%v", revoke), func(t *testing.T) {
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			w := &gateWriter{release: make(chan struct{}), closed: make(chan struct{})}
			o := newOutbound(ctx, cancel, w, 5*time.Second, func(Stamp) error { return nil })
			var mu sync.Mutex
			commits, newlineInside := 0, false
			o.commit = func(_ Stamp, write func() error) error {
				mu.Lock()
				commits++
				n := commits
				mu.Unlock()
				if n == 2 && revoke {
					return ProtocolError{wire.CodeConsentChanged}
				}
				err := write()
				if n == 1 {
					// The lock is released: a consent change can commit now; then the consumer resumes.
					close(w.release)
				} else if strings.HasSuffix(w.snapshot(), "\n") {
					newlineInside = true
				}
				return err
			}
			o.rowsMessage("private row", Stamp{}, nil)
			done := make(chan struct{})
			go o.run(done)
			if revoke {
				select {
				case <-done:
				case <-time.After(3 * time.Second):
					t.Fatal("session did not end after the frame lost its fence")
				}
				if got := w.snapshot(); got != "\"private row\"" || ctx.Err() == nil {
					t.Fatalf("written %q after a revoke, session ended %v", got, ctx.Err() != nil)
				}
				return
			}
			// Queue the next frame only once the private frame is being written.
			<-w.release
			o.controlMessage("after")
			deadline := time.Now().Add(3 * time.Second)
			for w.snapshot() != "\"private row\"\n\"after\"\n" {
				if time.Now().After(deadline) {
					t.Fatalf("written %q", w.snapshot())
				}
				time.Sleep(5 * time.Millisecond)
			}
			mu.Lock()
			defer mu.Unlock()
			if commits != 2 || !newlineInside || ctx.Err() != nil {
				t.Fatalf("commits %d, newline under fence %v, session ended %v", commits, newlineInside, ctx.Err() != nil)
			}
			cancel()
			<-done
		})
	}
}

// newlineStall takes everything but a lone newline, which blocks until the pipe is closed.
type newlineStall struct {
	gateWriter
	delay time.Duration
}

func (w *newlineStall) Write(p []byte) (int, error) {
	if string(p) == "\n" {
		<-w.closed
		return 0, io.ErrClosedPipe
	}
	if w.delay > 0 {
		time.Sleep(w.delay)
	}
	return w.gateWriter.Write(p)
}

// #1262 macrevb-1262-1: the session is never stopped while the consent lock is held. A stalled
// newline is cut inside the commit (so the frame cannot complete) and the session ends only
// after the lock is released; covers the initial commit and the second commit after a slow body.
func TestStalledNewlineEndsSessionOnlyAfterReleasingFence(t *testing.T) {
	for _, slowBody := range []bool{false, true} {
		t.Run(fmt.Sprintf("slowBody=%v", slowBody), func(t *testing.T) {
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			w := &newlineStall{gateWriter: gateWriter{release: make(chan struct{}), closed: make(chan struct{})}}
			close(w.release)
			if slowBody {
				w.delay = commitTimeout + 200*time.Millisecond
			}
			var mu sync.Mutex
			inside, stoppedInside := false, false
			stop := func() {
				mu.Lock()
				stoppedInside = stoppedInside || inside
				mu.Unlock()
				cancel()
			}
			o := newOutbound(ctx, stop, w, 5*time.Second, func(Stamp) error { return nil })
			o.commit = func(_ Stamp, write func() error) error {
				mu.Lock()
				inside = true
				mu.Unlock()
				defer func() { mu.Lock(); inside = false; mu.Unlock() }()
				return write()
			}
			o.rowsMessage("private row", Stamp{}, nil)
			done := make(chan struct{})
			go o.run(done)
			select {
			case <-done:
			case <-time.After(5 * time.Second):
				t.Fatal("session did not end after its newline stalled")
			}
			mu.Lock()
			defer mu.Unlock()
			if stoppedInside || ctx.Err() == nil || strings.Contains(w.snapshot(), "\n") {
				t.Fatalf("stopped under the fence %v, ended %v, written %q", stoppedInside, ctx.Err() != nil, w.snapshot())
			}
		})
	}
}
