// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
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

// The write timeout is kept, and under the consent lock it is capped at commitTimeout: a
// stalled consumer cannot hold off a revoke past that bound.
func TestPrivateFrameStallUnderFenceIsBounded(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	w := &blockingWriter{closed: make(chan struct{})}
	o := newOutbound(ctx, cancel, w, time.Minute, func(Stamp) error { return nil })
	var held time.Duration
	o.commit = func(_ Stamp, write func() error) error {
		start := time.Now()
		defer func() { held = time.Since(start) }()
		return write()
	}
	o.rowsMessage("private row", Stamp{}, nil)
	done := make(chan struct{})
	go o.run(done)
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("a stalled consumer held the consent fence past the bound")
	}
	if held < commitTimeout || held > commitTimeout+time.Second || ctx.Err() == nil {
		t.Fatalf("fence held %v, want about %v, then the session closed", held, commitTimeout)
	}
}
