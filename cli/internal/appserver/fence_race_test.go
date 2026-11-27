// SPDX-License-Identifier: MIT
package appserver

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

// flipAfterAdmission moves the consent fence right after the outbound admission check of a
// private frame (mayEmit) and before the frame's commit, as a consent commit by another
// process or by the user's own Settings grant can (sampling 11-25, #1217 P2).
type flipAfterAdmission struct {
	*memoryBackend
	mu      sync.Mutex
	armed   bool
	publish int
	flipped bool
}

func (b *flipAfterAdmission) Publish(ctx context.Context, stamp Stamp, write func() error) error {
	err := b.memoryBackend.Publish(ctx, stamp, write)
	b.mu.Lock()
	defer b.mu.Unlock()
	if !b.armed || err != nil {
		return err
	}
	// Publication 1 enqueues the rows/subscribe reply under the fence, 2 is the outbound
	// admission check; the fence moves before publication 3, the frame's commit.
	b.publish++
	if b.publish == 2 {
		b.armed, b.flipped = false, true
		b.memoryBackend.mu.Lock()
		b.memoryBackend.view.Stamp.Generation++
		b.memoryBackend.view.Projection.ConsentGeneration = b.memoryBackend.view.Stamp.Generation
		b.memoryBackend.mu.Unlock()
	}
	return err
}

// rawLines reads the server's stdout as the host does: only newline-terminated frames are
// delivered, and any unterminated tail at end of stream is reported.
type rawLines struct {
	lines chan []byte
	tail  chan []byte
}

func readRawLines(r io.Reader) *rawLines {
	out := &rawLines{lines: make(chan []byte, 64), tail: make(chan []byte, 1)}
	go func() {
		defer close(out.lines)
		reader := bufio.NewReaderSize(r, 64<<10)
		for {
			line, err := reader.ReadBytes('\n')
			if err != nil {
				out.tail <- line
				return
			}
			out.lines <- line[:len(line)-1]
		}
	}()
	return out
}

func (l *rawLines) response(t *testing.T, id int) map[string]json.RawMessage {
	t.Helper()
	timeout := time.After(3 * time.Second)
	for {
		select {
		case line, ok := <-l.lines:
			if !ok {
				t.Fatalf("session ended before response %d; unterminated tail %q", id, <-l.tail)
			}
			var m map[string]json.RawMessage
			if err := json.Unmarshal(line, &m); err != nil {
				t.Fatalf("malformed frame %q: %v", line, err)
			}
			if string(m["id"]) == fmt.Sprint(id) {
				return m
			}
		case <-timeout:
			t.Fatalf("timed out waiting for response %d", id)
		}
	}
}

// Invariant: a user's own consent change never produces a partial frame or a crash-counted
// restart. The fence flips between admission and write of a private frame: the server must
// write no byte of it, answer the request with consent_changed, and keep the session open.
func TestFenceFlipBetweenAdmissionAndWriteKeepsSessionAndWritesNoPartialFrame(t *testing.T) {
	backend := &flipAfterAdmission{memoryBackend: newMemoryBackend()}
	inR, inW, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	outR, outW, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	served := make(chan error, 1)
	go func() { served <- New(Config{Backend: backend}).Serve(context.Background(), inR, outW) }()
	defer func() {
		_ = inW.Close()
		_ = outR.Close()
		<-served
	}()
	lines := readRawLines(outR)
	send := func(id int, method string, p any) {
		t.Helper()
		raw, _ := json.Marshal(p)
		b, _ := json.Marshal(wire.Request{JSONRPC: wire.JSONRPC, ID: json.RawMessage(fmt.Sprint(id)), Method: method, Params: raw})
		if _, err := inW.Write(append(b, '\n')); err != nil {
			t.Fatal(err)
		}
	}
	send(1, "initialize", wire.InitializeParams{SessionID: "s-test", ProtocolVersion: wire.ProtocolVersion, AppVersion: "test", Capabilities: []string{"rows", "consent"}})
	if m := lines.response(t, 1); m["error"] != nil {
		t.Fatalf("initialize: %s", m["error"])
	}

	backend.mu.Lock()
	backend.armed = true
	backend.mu.Unlock()
	send(2, "rows/subscribe", wire.Empty{})
	m := lines.response(t, 2)
	backend.mu.Lock()
	flipped := backend.flipped
	backend.mu.Unlock()
	if !flipped {
		t.Fatal("the fence did not move between admission and commit; the race was not exercised")
	}
	if m["error"] == nil || errorOf(t, m).Code != wire.CodeConsentChanged {
		t.Fatalf("a frame whose fence moved was not answered with consent_changed: %s", m["result"])
	}

	// The session is still open: a later request is answered on the same stream.
	send(3, "consent/get", wire.Empty{})
	if m := lines.response(t, 3); m["error"] != nil {
		t.Fatalf("consent/get after the race: %s", m["error"])
	}
	select {
	case err := <-served:
		served <- err
		t.Fatalf("the consent change ended the session: %v", err)
	default:
	}

	// At end of stream nothing unterminated is left behind.
	_ = inW.Close()
	select {
	case err := <-served:
		served <- err
		if err != nil && !errors.Is(err, io.EOF) {
			t.Fatalf("serve: %v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("server did not end on EOF")
	}
	for range lines.lines {
	}
	if tail := <-lines.tail; len(tail) != 0 {
		t.Fatalf("partial frame on the wire: %q", tail)
	}
}
