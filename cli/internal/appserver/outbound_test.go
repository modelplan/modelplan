// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"io"
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
	o := newOutbound(ctx, cancel, w, time.Second, func(Stamp) bool { return true })
	if !o.reserve() {
		t.Fatal("first slot unavailable")
	}
	o.dataMessage("query", Stamp{}, false, nil)
	o.rowsMessage("old row", Stamp{})
	o.rowsMessage("latest row", Stamp{})
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
	o := newOutbound(ctx, cancel, &recordingWriter{}, time.Second, func(Stamp) bool { return true })
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
	o := newOutbound(ctx, cancel, w, time.Second, func(Stamp) bool { return false })
	o.reserve()
	o.dataMessage("private stale query", Stamp{}, true, func() {
		o.controlMessage(wire.Failure{JSONRPC: wire.JSONRPC, ID: json.RawMessage(`7`), Error: wire.RPCError{Code: wire.CodeConsentChanged, Message: "consent_changed"}})
	})
	o.rowsMessage("private stale row", Stamp{})
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
	o := newOutbound(ctx, cancel, &recordingWriter{}, time.Second, func(Stamp) bool { return true })
	for o.reserve() {
		o.dataMessage("result", Stamp{}, false, nil)
	}
	o.rowsMessage("latest", Stamp{})
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
