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

// revokeOnFirstWrite stands in for a consumer that reads the start of a private frame,
// pauses while another process commits a revoke, then resumes (review 11-24 #1).
type revokeOnFirstWrite struct {
	mu      sync.Mutex
	written []byte
	revoked bool
	closed  bool
}

func (w *revokeOnFirstWrite) Write(p []byte) (int, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.closed {
		return 0, io.ErrClosedPipe
	}
	w.written = append(w.written, p...)
	w.revoked = true
	return len(p), nil
}
func (w *revokeOnFirstWrite) Close() error { w.mu.Lock(); w.closed = true; w.mu.Unlock(); return nil }
func (w *revokeOnFirstWrite) isRevoked() bool {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.revoked
}

func TestPrivateFrameStartedBeforeRevokeNeverCompletes(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	w := &revokeOnFirstWrite{}
	// The enqueue-time check passes; the revoke lands while the body is being written.
	o := newOutbound(ctx, cancel, w, time.Second, func(Stamp) error { return nil })
	commits := 0
	o.commit = func(_ Stamp, write func() error) error {
		commits++
		if w.isRevoked() {
			return ProtocolError{wire.CodeConsentChanged}
		}
		return write()
	}
	o.rowsMessage("private row", Stamp{}, nil)
	done := make(chan struct{})
	go o.run(done)
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("session did not end after the frame lost its fence")
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	if commits != 1 {
		t.Fatalf("commit checks = %d, want 1", commits)
	}
	if strings.Contains(string(w.written), "\n") {
		t.Fatalf("private frame completed after revoke: %q", w.written)
	}
	if !w.closed || ctx.Err() == nil {
		t.Fatal("session stayed open with a partial private frame")
	}
}

func TestPrivateFrameCommitsNewlineUnderFence(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	w := &recordingWriter{done: make(chan struct{})}
	o := newOutbound(ctx, cancel, w, time.Second, func(Stamp) error { return nil })
	inside := false
	o.commit = func(_ Stamp, write func() error) error {
		inside = true
		defer func() { inside = false }()
		return write()
	}
	o.rowsMessage("row", Stamp{}, nil)
	o.controlMessage("after")
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
	if strings.Join(w.messages, "") != "\"after\"\n\"row\"\n" || w.messages[2] != "\n" || inside {
		t.Fatalf("private frame was not terminated under the fence: %q", w.messages)
	}
}
